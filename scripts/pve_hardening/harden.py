"""Durcissement distant d'une instance Proxmox VE (point d'entree "chapeau").

Ce module permet de durcir une instance Proxmox **distante** sans passer
par le cycle de mesure du lab : on donne l'IP (ou l'hote), le niveau de
durcissement souhaite et soit une cle SSH, soit le mot de passe root.

    python3 scripts/pve.py harden --host 192.168.1.50 --level 2 --password secret
    python3 scripts/pve.py harden --host 10.0.0.5 --level 3 --key ~/.ssh/id_ed25519
    python3 scripts/pve.py harden --host 10.0.0.5 --level 2 --password secret --audit

Securite :

* la cible est verifiee : on refuse de durcir une machine qui n'est pas un
  noeud Proxmox (le script Suppose desSpecificites Proxmox : pveproxy,
  /etc/pve, pve-firewall) ;
* une confirmation est demandee avant toute modification, sauf si ``--yes``
  est fourni (usage en automatisation) ;
* les scripts de durcissement sauvegardent chaque fichier modifie dans
  ``/root/hardening-backups/<horodatage>/`` sur la cible, et generent un
  script de rollback.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from .config import GUEST_DIR
from .console import console
from .ssh import Ssh, SshError

#: Plans de durcissement disponibles : liste de (cible, niveau).
#: Le plan "stack" cumule CIS, ANSSI et Ceph.
PLANS: dict[str, list[tuple[str, int]]] = {
    "cis": [("core", 0)],
    "anssi": [("anssi", 0)],
    "ceph": [("ceph", 0)],
    "stack": [("core", 0), ("anssi", 0), ("ceph", 0)],
}

#: Scripts de durcissement associes aux cibles.
SCRIPTS = {
    "core": "apply-homesec-core.sh",
    "anssi": "apply-anssi.sh",
    "ceph": "apply-ceph.sh",
}

#: Detection d'un noeud Proxmox (le durcissement suppose ces elements).
PROXMOX_MARKERS = ("/etc/pve", "/usr/bin/pvesh", "/usr/sbin/pveproxy")


@dataclass
class HardenOptions:
    """Options de la commande de durcissement distant."""

    host: str
    level: int = 2
    port: int = 22
    user: str = "root"
    key: str = ""
    password: str = ""
    plan: str = "stack"
    dry_run: bool = False
    assume_yes: bool = False
    audit: bool = False
    audit_extra: list[str] = field(default_factory=list)
    report: str = ""
    pdf: str = ""
    guest_dir: Path = field(default_factory=lambda: GUEST_DIR)
    timeout: int = 3600


def _detect_proxmox(ssh: Ssh) -> tuple[bool, str]:
    """Verifie que la cible est bien un noeud Proxmox."""
    res = ssh.exec(
        "cat /etc/pve/version 2>/dev/null | head -1; "
        "for m in {}; do [ -e \"$m\" ] && echo \"OK:$m\"; done".format(
            " ".join(PROXMOX_MARKERS)
        )
    )
    out = res.out or ""
    if not out.strip():
        return False, "la cible ne repond pas"
    version = out.splitlines()[0].strip() if out.splitlines() else ""
    markers = [ln for ln in out.splitlines() if ln.startswith("OK:")]
    if len(markers) < 2:
        return False, "aucune installation Proxmox detectee ({})".format(
            ", ".join(markers) or "rien"
        )
    return True, version or "Proxmox (version inconnue)"


def _plan_targets(plan: str, level: int) -> list[tuple[str, int]]:
    """Retourne la liste (cible, niveau) d'un plan de durcissement."""
    if plan not in PLANS:
        raise ValueError("plan inconnu : {}".format(plan))
    targets: list[tuple[str, int]] = []
    for target, _ in PLANS[plan]:
        if target == "core":
            targets.append((target, level))
        elif target == "anssi":
            # l'ANSSI suit sa propre echelle M/I/R/E : niveau 3 = renforce
            targets.append((target, min(max(level, 1), 4)))
        else:
            targets.append((target, 1))
    return targets


def _confirm(prompt: str) -> bool:
    """Demande une confirmation a l'utilisateur."""
    try:
        answer = input("{} [o/N] ".format(prompt))
    except (EOFError, KeyboardInterrupt):
        console.write("")
        return False
    return answer.strip().lower() in ("o", "y", "yes", "oui")


def harden(options: HardenOptions) -> int:
    """Durcit une instance Proxmox distante."""
    console.step("Durcissement de l'instance Proxmox")

    key = options.key or None
    password = options.password or None
    if not key and not password:
        console.error("Aucun moyen d'authentification : indiquez --key ou --password.")
        console.dim(
            "  (le mot de passe peut aussi venir de la variable "
            "PVE_ROOT_PASSWORD)"
        )
        return 2

    ssh = Ssh(
        host=options.host,
        port=options.port,
        user=options.user,
        key_path=key,
        password=password,
        timeout=options.timeout,
    )

    try:
        console.write("  cible     : {}@{}:{}".format(options.user, options.host, options.port))
        console.write("  niveau   : {}".format(options.level))
        console.write("  plan     : {}".format(options.plan))

        # ---------------------------------------------------------- controle
        console.step("1. controle de la cible")
        try:
            ssh.connect()
        except SshError as exc:
            console.error("  connexion impossible : {}".format(exc))
            return 1
        ok, detail = _detect_proxmox(ssh)
        if not ok:
            console.error("  la cible n'est pas un noeud Proxmox : {}".format(detail))
            console.dim("  ce durcissement est specifique a Proxmox VE (pveproxy, /etc/pve, pve-firewall).")
            return 1
        console.write("  Proxmox detecte : {}".format(detail))
        console.write("  authentification : {}".format(ssh.auth_mode))

        targets = _plan_targets(options.plan, options.level)
        console.write("  etapes   : {}".format(
            ", ".join("{}(niv.{})".format(t, n) for t, n in targets)
        ))

        if options.dry_run:
            console.step("2. simulation (dry-run)")
            for target, level in targets:
                script = SCRIPTS[target]
                local = options.guest_dir / script
                if not local.exists():
                    console.error("  script absent : {}".format(local))
                    return 1
                ssh.put(local, "/root/{}".format(script))
                console.write("  --- {} niveau {} (DRY-RUN) ---".format(script, level))
                res = ssh.exec("LEVEL={} DRY_RUN=1 bash /root/{}".format(level, script))
                for line in (res.out or "").splitlines():
                    if re.match(r"^\s*(===|\[|    )", line):
                        console.dim(line)
            console.write("")
            console.ok("Simulation terminee : aucune modification appliquee.")
            return 0

        # ------------------------------------------------------- confirmation
        console.step("2. confirmation")
        console.warn("  Les modifications suivantes seront appliquees :")
        for target, level in targets:
            console.write("    - {} niveau {}".format(SCRIPTS[target], level))
        console.dim(
            "  Les fichiers modifies sont sauvegardes sur la cible et un script"
        )
        console.dim(
            "  de rollback est genere (/root/rollback-hardening.sh)."
        )
        if not options.assume_yes and not _confirm("  Appliquer le durcissement ?"):
            console.write("  annule.")
            return 0

        # ------------------------------------------------------------ application
        console.step("3. application")
        for target, level in targets:
            script = SCRIPTS[target]
            local = options.guest_dir / script
            if not local.exists():
                console.error("  script absent : {}".format(local))
                return 1
            console.write("  --- {} (niveau {}) ---".format(script, level))
            ssh.put(local, "/root/{}".format(script))
            res = ssh.exec("LEVEL={} bash /root/{}".format(level, script))
            for line in (res.out or "").splitlines():
                if re.match(r"^\s*(===|\[|    )", line):
                    console.dim(line)
            if not res.ok:
                console.error("  {} a echoue (code {})".format(script, res.code))
                if res.err:
                    console.error(res.err.strip()[:500])
                return 1
            console.ok("  {} applique".format(script))

        # ------------------------------------------------------------- controle
        console.step("4. verification")
        res = ssh.exec(
            "systemctl is-active ssh pveproxy 2>&1 | tr '\\n' ' '; echo; "
            "test -f /root/rollback-hardening.sh && echo 'rollback: present' || echo 'rollback: absent'"
        )
        for line in (res.out or "").splitlines():
            if line.strip():
                console.write("  {}".format(line.strip()))
        if "inactive" in (res.out or "") or "failed" in (res.out or ""):
            console.error("  un service critique n'est plus actif : verifiez immediatement !")
            console.error("  rollback : bash /root/rollback-hardening.sh <repertoire>")
            return 1
        console.ok("  services critiques actifs")

        # --------------------------------------------------------------- audit
        if options.audit:
            console.step("5. audit de conformite")
            ssh.put(options.guest_dir / "audit-pve.sh", "/root/audit-pve.sh")
            for extra in options.audit_extra:
                local = options.guest_dir / "audit-{}.sh".format(extra)
                if local.exists():
                    ssh.put(local, "/root/audit-{}.sh".format(extra))
            ssh.exec("chmod +x /root/audit-*.sh")
            env_prefix = (
                "AUDIT_EXTRA={} ".format(",".join(options.audit_extra))
                if options.audit_extra
                else ""
            )
            res = ssh.exec("{}bash /root/audit-pve.sh /tmp/audit-final".format(env_prefix))
            match = re.search(
                r"PASS=(\d+)\s+FAIL=(\d+)\s+NA=(\d+)\s+INFO=(\d+)\s+TOTAL=(\d+)", res.out or ""
            )
            if match:
                pb, fb, na, info, total = (int(g) for g in match.groups())
                evaluated = pb + fb
                pct = round(100 * pb / evaluated, 1) if evaluated else 0
                console.write("  PASS={} FAIL={} NA={} INFO={} TOTAL={}".format(
                    pb, fb, na, info, total))
                console.write("  conformite : {} %".format(pct))
            else:
                console.warn("  synthese de l'audit illisible")

            if options.report:
                from .report import write_report

                console.step("6. rapport")
                write_report(
                    "/tmp/audit-final",
                    "/tmp/audit-final",
                    report_path=options.report,
                    pdf_path=options.pdf or None,
                    title="Durcissement Proxmox VE 9 - {}".format(options.host),
                )

        console.write("")
        console.ok("=== DURCISSEMENT TERMINE ===")
        console.dim(
            "  rollback (si necessaire) : bash /root/rollback-hardening.sh "
            "/root/hardening-backups/<horodatage>"
        )
        return 0
    finally:
        ssh.close()
