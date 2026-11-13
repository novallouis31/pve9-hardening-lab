"""Acces SSH/SFTP au noeud Proxmox (paramiko).

Ce module remplace ``scripts/ssh-tool.py`` en version reutilisable et
multiplateforme. Il conserve les garanties acquises au fil des cycles :

* **repli par mot de passe** : si l'authentification par cle echoue (la
  restauration d'un snapshot reinitialise ``/etc/pve/priv/authorized_keys``
  sur Proxmox), on se connecte avec le mot de passe pour pouvoir reinjecter
  la cle ;
* **verification du transfert** : chaque copie est controlee par taille et
  empreinte SHA256. Un transfert tronque produisait un fichier **vide**
  sur le noeud, execute sans rien faire, et bloquait le cycle indefiniment ;
* **messages de succes sur stdout** : sur stderr, PowerShell 5.1 les
  transformerait en erreurs bloquantes.
"""

from __future__ import annotations

import hashlib
import io
import shlex
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import paramiko

from .console import console


@dataclass
class CommandResult:
    """Resultat d'une commande distante."""

    out: str
    err: str
    code: int

    @property
    def ok(self) -> bool:
        return self.code == 0

    def lines(self) -> list[str]:
        return self.out.splitlines()


class SshError(RuntimeError):
    """Erreur d'acces au noeud."""


class Ssh:
    """Client SSH vers un noeud Proxmox."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 2222,
        user: str = "root",
        key_path: str | Path | None = None,
        password: str | None = None,
        timeout: int = 3600,
    ) -> None:
        self.host = host
        self.port = int(port)
        self.user = user
        self.key_path = str(key_path) if key_path else None
        self.password = password or None
        self.timeout = int(timeout)
        self._client: paramiko.SSHClient | None = None
        self.auth_mode: str | None = None

    # ------------------------------------------------------------ cycle de vie
    def connect(self) -> "Ssh":
        """Ouvre la connexion (repli par mot de passe si la cle echoue)."""
        if self._client is not None:
            return self
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                self.host,
                port=self.port,
                username=self.user,
                key_filename=self.key_path,
                look_for_keys=False,
                allow_agent=False,
                timeout=30,
            )
            self.auth_mode = "key"
        except Exception as key_error:
            if not self.password:
                raise SshError(
                    "connexion par cle impossible sur {}@{}:{} ({})".format(
                        self.user, self.host, self.port, key_error
                    )
                ) from key_error
            console.write(
                "  connexion par cle impossible ({}), repli sur le mot de passe".format(key_error)
            )
            client.connect(
                self.host,
                port=self.port,
                username=self.user,
                password=self.password,
                look_for_keys=False,
                allow_agent=False,
                timeout=30,
            )
            self.auth_mode = "password"
        self._client = client
        return self

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            finally:
                self._client = None

    def __enter__(self) -> "Ssh":
        return self.connect()

    def __exit__(self, *exc) -> None:
        self.close()

    @property
    def client(self) -> paramiko.SSHClient:
        if self._client is None:
            raise SshError("non connecte")
        return self._client

    # -------------------------------------------------------------- operations
    def test(self) -> bool:
        """Vrai si une commande triviale s'execute."""
        try:
            with self.connect():
                _, stdout, _ = self.client.exec_command("true", timeout=30)
                code = stdout.channel.recv_exit_status()
            return code == 0
        except Exception:
            return False

    def exec(self, command: str, stdin_data: str | None = None) -> CommandResult:
        """Execute une commande distante et renvoie sortie / erreur / code."""
        with self.connect():
            if stdin_data is not None:
                stdin, stdout, stderr = self.client.exec_command(command, timeout=self.timeout)
                stdin.write(stdin_data)
                stdin.channel.shutdown_write()
            else:
                stdin, stdout, stderr = self.client.exec_command(command, timeout=self.timeout)
            out = stdout.read().decode("utf-8", "replace")
            err = stderr.read().decode("utf-8", "replace")
            code = stdout.channel.recv_exit_status()
        return CommandResult(out=out, err=err, code=code)

    def run(self, command: str, check: bool = True) -> CommandResult:
        """Execute une commande et leve une exception en cas d'echec."""
        res = self.exec(command)
        if check and not res.ok:
            raise SshError(
                "commande distante en echec (code {}) : {}\n{}".format(
                    res.code, command, res.err.strip()
                )
            )
        return res

    def put(self, local: str | Path, remote: str) -> None:
        """Copie un fichier vers le noeud, avec verification d'integrite."""
        local_path = Path(local)
        data = local_path.read_bytes()
        expected_size = len(data)
        expected_sha = hashlib.sha256(data).hexdigest()

        with self.connect():
            try:
                sftp = self.client.open_sftp()
                sftp.put(str(local_path), remote)
                sftp.close()
            except Exception:
                # Repli : transfert en base64 (le sous-systeme sftp peut etre absent)
                payload = _b64(data)
                cmd = "echo '{}' | base64 -d > {}".format(payload, shlex.quote(remote))
                _, stdout, stderr = self.client.exec_command(cmd, timeout=self.timeout)
                stdout.read()
                err = stderr.read().decode("utf-8", "replace")
                code = stdout.channel.recv_exit_status()
                if code != 0:
                    raise SshError("copie vers {} impossible : {}".format(remote, err.strip()))

            size, sha = self._remote_digest(remote)
            if size != expected_size or sha != expected_sha:
                raise SshError(
                    "copie verifiee KO vers {} : attendu {} octets sha {} ; obtenu {} octets sha {}".format(
                        remote, expected_size, expected_sha[:16], size, (sha or "")[:16]
                    )
                )
        console.dim(
            "    copie verifiee : {} ({} octets, sha {})".format(
                remote, expected_size, expected_sha[:16]
            )
        )

    def get(self, remote: str, local: str | Path) -> Path:
        """Recupere un fichier depuis le noeud."""
        local_path = Path(local)
        local_path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect():
            try:
                sftp = self.client.open_sftp()
                sftp.get(remote, str(local_path))
                sftp.close()
            except Exception:
                cmd = "base64 {}".format(shlex.quote(remote))
                _, stdout, _ = self.client.exec_command(cmd, timeout=self.timeout)
                payload = stdout.read().decode("utf-8", "replace").strip()
                local_path.write_bytes(_b64decode(payload))
        return local_path

    def _remote_digest(self, remote: str) -> tuple[int, str]:
        """Retourne (taille, sha256) d'un fichier distant."""
        cmd = "stat -c %s {} 2>/dev/null; sha256sum {} 2>/dev/null | cut -d' ' -f1".format(
            shlex.quote(remote), shlex.quote(remote)
        )
        _, stdout, stderr = self.client.exec_command(cmd, timeout=60)
        out = stdout.read().decode("utf-8", "replace").split()
        stderr.read()
        stdout.channel.recv_exit_status()
        if len(out) < 2:
            return (0, "")
        try:
            return (int(out[0]), out[1])
        except ValueError:
            return (0, "")


def _b64(data: bytes) -> str:
    import base64

    return base64.b64encode(data).decode()


def _b64decode(payload: str) -> bytes:
    import base64

    return base64.b64decode(payload)


# --------------------------------------------------------------------- CLI
def main(argv: Sequence[str] | None = None) -> int:
    """Point d'entree en ligne de commande (equivalent de ssh-tool.py)."""
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) < 5:
        print(
            "usage : ssh-tool.py <action> <host> <port> <user> <key> [args...] [password]",
            file=sys.stderr,
        )
        return 2

    action, host, port, user, key = argv[0], argv[1], int(argv[2]), argv[3], argv[4]
    rest = argv[5:]
    # Le mot de passe est toujours le DERNIER argument.
    password = None
    if rest and rest[-1] not in ("", "-") and len(rest) >= 1:
        # On ne retire le dernier argument que s'il ressemble a un mot de passe
        # et que l'action n'a pas besoin de ce nombre d'arguments.
        needed = {"test": 0, "exec": 2, "put": 2, "get": 2}.get(action, 0)
        if len(rest) > needed:
            password = rest.pop()
    ssh = Ssh(host=host, port=port, user=user, key_path=key, password=password)

    try:
        if action == "test":
            with ssh.connect():
                _, stdout, _ = ssh.client.exec_command("true", timeout=30)
                return stdout.channel.recv_exit_status()
        if action == "exec":
            command = rest[0]
            stdin_data = rest[1] if len(rest) > 1 and rest[1] != "" else None
            res = ssh.exec(command, stdin_data)
            if res.out:
                print(res.out, end="")
            if res.err:
                print(res.err, end="", file=sys.stderr)
            return res.code
        if action == "put":
            ssh.put(rest[0], rest[1])
            return 0
        if action == "get":
            ssh.get(rest[0], rest[1])
            return 0
    except SshError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - garde-fou CLI
        print(str(exc), file=sys.stderr)
        return 1

    print("action inconnue : {}".format(action), file=sys.stderr)
    return 2


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
