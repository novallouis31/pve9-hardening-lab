"""De-hardening d'une instance Proxmox VE (equivalent de scripts/deharden.sh).

Cette implementation partage la logique avec le client bash : elle copie le
script distant ``guest/deharden-pve.sh`` sur la cible, l'execute et recupere
le rapport Markdown produit.

Le client bash reste la reference pour les environnements sans Python ; les
deux implementations exploitent le MEME script distant, donc le comportement
est identique.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from .config import GUEST_DIR
from .console import console
from .ssh import Ssh, SshError

#: Script distant execute sur la cible.
REMOTE_SCRIPT_NAME = "deharden-pve.sh"


@dataclass
class DehardenOptions:
    """Options de la commande de de-hardening."""

    host: str
    port: int = 22
    user: str = "root"
    key: str = ""
    password: str = ""
    dry_run: bool = False
    keep_packages: bool = False
    report: str = ""
    script: str = ""
    timeout: int = 3600
    guest_dir: Path = field(default_factory=lambda: GUEST_DIR)


def _local_script(options: DehardenOptions) -> Path:
    """Localise le script distant a copier."""
    if options.script:
        return Path(options.script)
    return options.guest_dir / REMOTE_SCRIPT_NAME


def deharden(options: DehardenOptions) -> int:
    """Execute le de-hardening sur la cible."""
    console.step("De-hardening de l'instance Proxmox")
    console.write("  cible  : {}@{}:{}".format(options.user, options.host, options.port))
    console.write("  mode   : {}".format("simulation" if options.dry_run else "application"))

    script = _local_script(options)
    if not script.exists():
        console.error("Script distant introuvable : {}".format(script))
        return 1

    key = options.key or None
    password = options.password or None
    if not key and not password:
        console.error("Aucun moyen d'authentification : indiquez --key ou --password.")
        return 2

    ssh = Ssh(
        host=options.host,
        port=options.port,
        user=options.user,
        key_path=key,
        password=password,
        timeout=options.timeout,
    )
    remote_script = "/tmp/{}-$$.sh".format(REMOTE_SCRIPT_NAME)
    remote_report = "/tmp/deharden-report-$$.md"

    try:
        # ------------------------------------------------------ connectivite
        console.step("1. connectivite")
        try:
            ssh.connect()
        except SshError as exc:
            console.error("  connexion impossible : {}".format(exc))
            return 1
        console.write("  authentification : {}".format(ssh.auth_mode))

        # --------------------------------------------- verification de la cible
        console.step("2. verification de la cible")
        res = ssh.exec("hostname; cat /etc/pve/version 2>/dev/null || echo '(pas de /etc/pve/version)'")
        for line in (res.out or "").splitlines():
            if line.strip():
                console.write("  " + line.strip())
        if "/etc/pve" not in (ssh.exec("test -d /etc/pve && echo PROXMOX_OK").out or ""):
            console.error("  la cible ne semble pas etre un noeud Proxmox (/etc/pve absent).")
            console.dim("  le de-hardening est specifique a Proxmox VE : abandon.")
            return 1
        console.write("  noeud Proxmox confirme", "green")

        # ------------------------------------------------------- transfert
        console.step("3. transfert du script distant")
        ssh.put(script, remote_script)
        console.write("  copie : {}".format(remote_script))

        # ------------------------------------------------------ execution
        console.step("4. de-hardening")
        args = []
        if options.dry_run:
            args.append("--dry-run")
        if options.keep_packages:
            args.append("--keep-packages")
        args.append("--report {}".format(remote_report))
        cmd = "chmod 700 '{s}' && bash '{s}' {a}; rc=$?; rm -f '{s}'; exit $rc".format(
            s=remote_script, a=" ".join(args)
        )
        res = ssh.exec(cmd)
        for line in (res.out or "").splitlines():
            if line.strip():
                console.dim("  " + line)
        rc = res.code

        # ------------------------------------------------------- rapport
        console.step("5. rapport")
        local_report = options.report or "deharden-{}.md".format(
            re.sub(r"[^A-Za-z0-9_.-]", "_", options.host)
        )
        try:
            Path(local_report).parent.mkdir(parents=True, exist_ok=True)
            ssh.get(remote_report, local_report)
            console.ok("  rapport local : {}".format(local_report))
        except SshError:
            console.warn("  rapport non recupere (voir la sortie ci-dessus)")
        ssh.exec("rm -f '{}'".format(remote_report))

        console.write("")
        if rc == 0:
            console.ok("=== DE-HARDENDING TERMINE ===")
            return 0
        console.error("=== DE-HARDENDING ECHOUE (code {}) ===".format(rc))
        return rc
    finally:
        ssh.close()
