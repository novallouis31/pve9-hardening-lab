"""Phases du protocole de test (equivalent de ``scripts/run-phase.ps1``).

Phases :

* ``bootstrap`` : affiche la commande a coller dans le shell de la web UI PVE
  pour installer la cle publique du lab (acces SSH automatise) ;
* ``baseline``  : collecte l'etat de securite **AVANT** hardening ;
* ``apply``     : applique un durcisseur sur le noeud ;
* ``verify``    : collecte l'etat **APRES** hardening et produit le rapport ;
* ``all``       : baseline -> apply -> verify.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Callable

from .config import (
    ARTIFACTS_DIR,
    DEFAULT_KEY,
    DEFAULT_SSH_HOST,
    DEFAULT_SSH_PASSWORD,
    DEFAULT_SSH_PORT,
    DEFAULT_SSH_USER,
    GUEST_DIR,
    ensure_dir,
)
from .console import console
from .report import write_report
from .ssh import Ssh, SshError

#: Cibles de durcissement appliquees sur le noeud.
TARGETS = {
    "core": ("apply-homesec-core.sh", "guide PVE 9 + CIS Debian 13"),
    "anssi": ("apply-anssi.sh", "ANSSI BP-028 (niveaux M/I/R/E)"),
    "ceph": ("apply-ceph.sh", "Ceph (cephx, msgr2, permissions)"),
}

#: Suites de tests fonctionnels : (fichier invite, motif du rapport distant).
FUNC_SUITES = (
    ("func-test-pve.sh", "fonctionnel-", "PVE"),
    ("func-test-os.sh", "fonctionnel-os-", "OS"),
)

#: Modules d'audit supplementaires charges via AUDIT_EXTRA.
AUDIT_EXTRA_MODULES = ("anssi", "ceph", "cis13", "communautaire")


@dataclass
class Options:
    """Options du cycle de test."""

    phase: str = "all"
    target: str = "core"
    level: int = 1
    ssh_host: str = DEFAULT_SSH_HOST
    ssh_port: int = DEFAULT_SSH_PORT
    ssh_user: str = DEFAULT_SSH_USER
    key_path: Path = field(default_factory=lambda: DEFAULT_KEY)
    ssh_password: str = DEFAULT_SSH_PASSWORD
    ssh_timeout: int = 3600
    audit_extra: list[str] = field(default_factory=list)
    run_func: bool = False
    skip_vendor_verify: bool = False
    artifacts: Path = field(default_factory=lambda: ARTIFACTS_DIR)
    report_title: str | None = None
    report_path: Path | None = None
    pdf_path: Path | None = None
    no_pdf: bool = False


def _stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def _check_patterns() -> list[str]:
    """Motifs des lignes ``@@CHECK`` du collecteur."""
    return [r"^@@CHECK\s+(\S+)\s+(\S+)\s*(.*)$"]


class Runner:
    """Execute les phases du protocole."""

    def __init__(self, options: Options) -> None:
        self.opt = options
        self.ssh = Ssh(
            host=options.ssh_host,
            port=options.ssh_port,
            user=options.ssh_user,
            key_path=options.key_path,
            password=options.ssh_password,
            timeout=options.ssh_timeout,
        )
        self.before_dir: Path | None = None
        self.after_dir: Path | None = None
        self.before_func: Path | None = None
        self.after_func: Path | None = None

    # ------------------------------------------------------------- utilitaires
    def _assert_ssh(self) -> None:
        if not self.ssh.test():
            console.error("Connexion SSH impossible vers {}@{}:{}".format(
                self.opt.ssh_user, self.opt.ssh_host, self.opt.ssh_port))
            console.error("Verifiez :")
            console.error("  1. la VM est demarree et l'installation de PVE est terminee")
            console.error("  2. la redirection NAT est active (port {} -> 22)".format(self.opt.ssh_port))
            console.error("  3. la cle publique du lab est installee (phase bootstrap)")
            raise SshError("SSH indisponible")

    def _install_ssh_pubkey(self) -> None:
        """Reinjecte la cle publique du lab dans le fichier partage Proxmox.

        Indispensable : la restauration d'un snapshot reinitialise
        ``/etc/pve/priv/authorized_keys`` et l'acces par cle est perdu.
        """
        pub_file = Path(self.opt.key_path).with_suffix(".pub")
        if not pub_file.exists():
            return
        pub = pub_file.read_text(encoding="utf-8").strip()
        if not pub:
            return
        cmd = (
            "grep -qF '{pub}' /etc/pve/priv/authorized_keys 2>/dev/null || "
            "printf '%s\\n' '{pub}' >> /etc/pve/priv/authorized_keys; "
            "chmod 0600 /etc/pve/priv/authorized_keys 2>/dev/null || true; "
            "systemctl reload pvedaemon 2>/dev/null || true; "
            "grep -c 'ssh-' /etc/pve/priv/authorized_keys 2>/dev/null || echo 0"
        ).format(pub=pub)
        try:
            res = self.ssh.exec(cmd)
            count = 0
            m = re.search(r"(\d+)", res.out or "")
            if m:
                count = int(m.group(1))
            console.dim(
                "  cle publique du lab installee dans /etc/pve/priv/authorized_keys ({} cle(s))".format(
                    count
                )
            )
        except SshError:
            pass

    def _copy_to_guest(self, local: Path, remote: str) -> None:
        self.ssh.put(local, remote)
        size = local.stat().st_size
        check = self.ssh.exec("stat -c %s {} 2>/dev/null || echo 0".format(remote))
        m = re.search(r"(\d+)", check.out or "")
        remote_size = int(m.group(1)) if m else 0
        if remote_size != size:
            raise SshError(
                "Transfert incomplet : {} fait {} octets au lieu de {}".format(
                    remote, remote_size, size
                )
            )
        console.dim("  transfere : {} -> {} ({} octets)".format(local.name, remote, remote_size))

    # --------------------------------------------------------------- audit
    def _audit(self, label: str) -> Path:
        """Copie les collecteurs, les execute et recupere les resultats."""
        self._assert_ssh()
        self._install_ssh_pubkey()

        self._copy_to_guest(GUEST_DIR / "audit-pve.sh", "/root/audit-pve.sh")
        self.ssh.exec("chmod +x /root/audit-pve.sh")
        for extra in self.opt.audit_extra:
            local = GUEST_DIR / "audit-{}.sh".format(extra)
            if not local.exists():
                console.warn("  module d'audit absent : {}".format(local.name))
                continue
            self._copy_to_guest(local, "/root/audit-{}.sh".format(extra))
            self.ssh.exec("chmod +x /root/audit-{}.sh".format(extra))

        remote = "/tmp/audit-{}".format(label)
        env_prefix = "AUDIT_EXTRA={} ".format(",".join(self.opt.audit_extra)) if self.opt.audit_extra else ""
        res = self.ssh.exec("{}bash /root/audit-pve.sh {}".format(env_prefix, remote))

        out = res.out or ""
        m = re.search(r"PASS=(\d+)\s+FAIL=(\d+)\s+NA=(\d+)\s+INFO=(\d+)\s+TOTAL=(\d+)", out)
        if m:
            console.write(
                "  synthese : PASS={} FAIL={} NA={} INFO={} TOTAL={}".format(
                    m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
                )
            )

        stamp = _stamp()
        local_dir = ensure_dir(self.opt.artifacts / "{}-{}".format(label, stamp))
        self.ssh.get("{}/audit.txt".format(remote), local_dir / "audit.txt")
        try:
            self.ssh.get("{}/checks.tsv".format(remote), local_dir / "checks.tsv")
        except SshError:
            pass
        console.dim("  audit     : {}".format(local_dir))
        return local_dir

    # ------------------------------------------------------- tests fonctionnels
    def _func_tests(self, label: str) -> Path:
        """Execute les suites de tests fonctionnels et archive le rapport unifie."""
        self._assert_ssh()
        self._install_ssh_pubkey()

        remote = "/tmp/func-{}".format(label)
        stamp = _stamp()
        local_dir = ensure_dir(self.opt.artifacts / "func-{}-{}".format(label, stamp))
        local_report = local_dir / "fonctionnel.txt"

        total_fail = 0
        combined: list[str] = []

        for guest_file, pattern, tag in FUNC_SUITES:
            local = GUEST_DIR / guest_file
            if not local.exists():
                console.warn("  suite de tests absente : {}".format(guest_file))
                continue
            remote_script = "/root/{}".format(guest_file)
            self._copy_to_guest(local, remote_script)
            self.ssh.exec("chmod +x {}".format(remote_script))

            console.dim("  tests fonctionnels {} ({})...".format(tag, label))
            res = self.ssh.exec("bash {} {}".format(remote_script, remote))
            failures = len(
                [ln for ln in (res.out or "").splitlines() if re.match(r"^@@TEST\s+\S+\s+FAIL", ln)]
            )
            total_fail += failures

            # archivage du rapport brut
            listing = self.ssh.exec(
                "ls -1 {} 2>/dev/null | grep '{}.*\\.txt' | head -1".format(remote, pattern)
            )
            match = re.search(r"(\S+\.txt)", listing.out or "")
            if match:
                try:
                    self.ssh.get(
                        "{}/{}".format(remote, match.group(1)),
                        local_dir / "{}-{}".format(tag, match.group(1)),
                    )
                except SshError:
                    pass

            combined.append("===== SUITE {} =====".format(tag))
            combined.extend(
                ln for ln in (res.out or "").splitlines() if re.match(r"^@@TEST\s+", ln)
            )
            combined.append("")
            colour = "yellow" if failures else "green"
            console.write("    {} : {} echec(s)".format(tag, failures), colour)

        local_report.write_text("\n".join(combined) + "\n", encoding="utf-8")
        colour = "yellow" if total_fail else "green"
        console.write(
            "  rapport fonctionnel : {} ({} echec(s))".format(local_report, total_fail), colour
        )
        return local_report

    # --------------------------------------------------------------- apply
    def apply(self) -> None:
        """Applique le durcisseur demande sur le noeud."""
        self._assert_ssh()
        self._install_ssh_pubkey()
        console.step("apply - cible : {}".format(self.opt.target))

        if self.opt.target in ("abua", "mrmasterbay"):
            self._apply_assistant()
            return

        script, description = TARGETS[self.opt.target]
        console.dim("  {} : {}".format(script, description))
        self._copy_to_guest(GUEST_DIR / script, "/root/{}".format(script))
        res = self.ssh.exec("LEVEL={} bash /root/{}".format(self.opt.level, script))
        for line in (res.out or "").splitlines():
            if re.match(r"^\s*(===|\[|    )", line):
                console.dim(line)
        if not res.ok:
            console.error("apply-{} a echoue (code {}).".format(script, res.code))
            if res.err:
                console.error(res.err.strip())
            raise SshError("echec du durcissement")

    def _apply_assistant(self) -> None:
        """Applique un assistant interactif (abua / mrmasterbay) via PTY."""
        if self.opt.target == "abua":
            script = "PVE9-Harden-FinalVersion-v1.sh"
            answers = self.opt.artifacts.parent / "answers" / "mrmasterbay.txt"
        else:
            script = "seuwurity.sh"
            answers = self.opt.artifacts.parent / "answers" / "mrmasterbay.txt"

        if not (GUEST_DIR / script).exists():
            console.error("script de l'assistant absent : {}".format(script))
            raise SshError("assistant introuvable")
        self._copy_to_guest(GUEST_DIR / script, "/root/{}".format(script))
        payload = ""
        if answers.exists():
            payload = answers.read_text(encoding="utf-8", errors="replace")
        cmd = 'TERM=xterm script -q -e -c "bash /root/{}" /dev/null'.format(script)
        res = self.ssh.exec(cmd, stdin_data=payload or None)
        console.dim(res.out or "")
        if not res.ok:
            raise SshError("l'assistant interactif a echoue")

    # -------------------------------------------------------------- bootstrap
    def bootstrap(self) -> None:
        """Affiche la commande d'installation de la cle publique."""
        console.step("bootstrap - injection de la cle publique du lab")
        if not Path(self.opt.key_path).exists():
            raise SshError("cle absente : {}".format(self.opt.key_path))
        pub = Path(self.opt.key_path).with_suffix(".pub")
        key = pub.read_text(encoding="utf-8").strip() if pub.exists() else ""
        console.write("Cle publique du lab :")
        console.ok("  {}".format(key))
        console.write("")
        console.write(
            "Collez cette commande dans Web UI -> Noeud -> Shell :", "yellow"
        )
        console.write("")
        console.write(
            "  bash -c 'mkdir -p /root/.ssh && chmod 700 /root/.ssh && "
            'echo "{}" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"'.format(
                key
            ),
            "white",
        )
        console.write("")
        console.dim(
            "Sur Proxmox, /root/.ssh/authorized_keys est un lien vers "
            "/etc/pve/priv/authorized_keys (partage entre les noeuds du cluster)."
        )

    # ----------------------------------------------------------------- cycle
    def run(self) -> int:
        """Execute la phase demandee."""
        phase = self.opt.phase
        if phase == "bootstrap":
            self.bootstrap()
            return 0

        if phase in ("baseline", "all"):
            console.step("baseline - audit AVANT hardening")
            self.before_dir = self._audit("baseline")
            if self.opt.run_func:
                self.before_func = self._func_tests("before")

        if phase in ("apply", "all"):
            self.apply()

        if phase in ("verify", "all"):
            console.step("verify - audit APRES hardening")
            self.after_dir = self._audit("after")
            if self.opt.run_func:
                self.after_func = self._func_tests("after")

        if phase in ("verify", "all") and self.before_dir and self.after_dir:
            console.step("rapport de comparaison")
            write_report(
                self.before_dir,
                self.after_dir,
                report_path=self.opt.report_path,
                pdf_path=self.opt.pdf_path,
                title=self.opt.report_title or "Comparatif de hardening - Proxmox VE 9",
                before_func=self.before_func,
                after_func=self.after_func,
                no_pdf=self.opt.no_pdf,
            )
        return 0


def run_phase(options: Options) -> int:
    """Point d'entree du module."""
    runner = Runner(options)
    try:
        return runner.run()
    finally:
        runner.ssh.close()
