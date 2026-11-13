"""CLI unifie du lab de hardening Proxmox VE 9.

Remplace les scripts PowerShell pour un usage multiplateforme (Ubuntu, SLES,
RHEL, macOS, Windows).

    python3 scripts/pve.py --help
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from . import __version__
from .config import (
    ARTIFACTS_DIR,
    DEFAULT_KEY,
    DEFAULT_SSH_HOST,
    DEFAULT_SSH_PASSWORD,
    DEFAULT_SSH_PORT,
    DEFAULT_SSH_USER,
    LAB_ROOT,
    REPORTS_DIR,
    VENDOR_DIR,
    ensure_dir,
)
from .console import console


def _add_ssh_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--ssh-host", default=DEFAULT_SSH_HOST, help="hote du noeud")
    parser.add_argument("--ssh-port", type=int, default=DEFAULT_SSH_PORT, help="port SSH")
    parser.add_argument("--ssh-user", default=DEFAULT_SSH_USER, help="utilisateur SSH")
    parser.add_argument("--key", default=str(DEFAULT_KEY), help="cle privee du lab")
    parser.add_argument(
        "--ssh-password",
        default=DEFAULT_SSH_PASSWORD,
        help="mot de passe root (repli si l'acces par cle echoue)",
    )
    parser.add_argument(
        "--ssh-timeout", type=int, default=3600, help="timeout SSH (secondes)"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="pve.py",
        description="Lab de test de hardening Proxmox VE 9 (multiplateforme).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemples :\n"
            "  pve.py fetch-vendor\n"
            "  pve.py run --phase baseline --audit-extra anssi,ceph,cis13,communautaire\n"
            "  pve.py run --phase all --target core --level 2 --run-func\n"
            "  pve.py report --before artifacts/baseline-x --after artifacts/after-y\n"
            "  pve.py snapshot --action create --name pristine\n"
        ),
    )
    parser.add_argument("--version", action="version", version="pve-hardening {}".format(__version__))
    sub = parser.add_subparsers(dest="command", metavar="commande")

    # ------------------------------------------------------------------ run
    p_run = sub.add_parser("run", help="execute une phase du protocole de test")
    p_run.add_argument(
        "--phase",
        required=True,
        choices=("bootstrap", "baseline", "apply", "verify", "all"),
        help="phase a executer",
    )
    p_run.add_argument(
        "--target",
        default="core",
        choices=("core", "anssi", "ceph", "abua", "mrmasterbay"),
        help="durcisseur a appliquer",
    )
    p_run.add_argument("--level", type=int, default=1, choices=(1, 2, 3, 4), help="niveau de durcissement")
    p_run.add_argument(
        "--audit-extra",
        default="",
        help="modules d'audit supplementaires (anssi,ceph,cis13,communautaire)",
    )
    p_run.add_argument("--run-func", action="store_true", help="executer les tests fonctionnels")
    p_run.add_argument("--skip-vendor-verify", action="store_true", help="ne pas verifier les artefacts")
    p_run.add_argument("--artifacts", default=str(ARTIFACTS_DIR), help="repertoire des artefacts")
    p_run.add_argument("--report", default="", help="chemin du rapport Markdown")
    p_run.add_argument("--pdf", default="", help="chemin du rapport PDF")
    p_run.add_argument("--title", default="", help="titre du rapport")
    p_run.add_argument("--no-pdf", action="store_true", help="ne pas produire de PDF")
    _add_ssh_options(p_run)

    # --------------------------------------------------------------- report
    p_rep = sub.add_parser("report", help="genere le rapport avant/apres")
    p_rep.add_argument("--before", required=True, help="repertoire d'audit AVANT")
    p_rep.add_argument("--after", required=True, help="repertoire d'audit APRES")
    p_rep.add_argument("--before-func", default="", help="rapport fonctionnel avant")
    p_rep.add_argument("--after-func", default="", help="rapport fonctionnel apres")
    p_rep.add_argument("--report", default="", help="chemin du rapport Markdown")
    p_rep.add_argument("--pdf", default="", help="chemin du rapport PDF")
    p_rep.add_argument("--title", default="Comparatif de hardening - Proxmox VE 9")
    p_rep.add_argument("--no-pdf", action="store_true")

    # --------------------------------------------------------------- vendor
    p_fetch = sub.add_parser("fetch-vendor", help="telecharge les artefacts de reference")
    p_fetch.add_argument("--vendor-dir", default=str(VENDOR_DIR))
    p_fetch.add_argument("--force", action="store_true")

    p_verify = sub.add_parser("verify-vendor", help="verifie l'integrite des artefacts")
    p_verify.add_argument("--vendor-dir", default=str(VENDOR_DIR))

    # ------------------------------------------------------------- snapshot
    p_snap = sub.add_parser("snapshot", help="gere les snapshots VirtualBox")
    p_snap.add_argument(
        "--action", required=True, choices=("create", "list", "restore", "delete")
    )
    p_snap.add_argument("--vm", default="proxmox", help="nom de la VM")
    p_snap.add_argument("--name", default="pristine", help="nom du snapshot")
    p_snap.add_argument("--description", default="PVE9 hardening lab")

    # ---------------------------------------------------------------- image
    p_img = sub.add_parser("image", help="sauvegarde/restaure l'image de reference")
    p_img.add_argument("--action", required=True, choices=("save", "restore"))
    p_img.add_argument("--vm", default="proxmox")
    p_img.add_argument("--disk", required=True, help="disque de travail de la VM")
    p_img.add_argument("--image", required=True, help="image de reference")

    # -------------------------------------------------------------- publish
    p_pub = sub.add_parser("publish", help="publie le depot sur GitHub")
    p_pub.add_argument("--repo", required=True, help="nom du depot GitHub")
    p_pub.add_argument("--path", default=str(LAB_ROOT), help="depot local")
    p_pub.add_argument("--token", default="", help="Personal Access Token GitHub")
    p_pub.add_argument("--use-gitkraken", action="store_true")
    p_pub.add_argument("--owner", default="")
    p_pub.add_argument("--visibility", default="public", choices=("public", "private"))
    p_pub.add_argument("--tags", action="store_true", help="pousser aussi les tags")

    # --------------------------------------------------------------- harden
    p_hard = sub.add_parser(
        "harden",
        help="durcit une instance Proxmox distante (niveau, IP, cle ou mot de passe)",
        description=(
            "Durcit une instance Proxmox VE distante.\n\n"
            "Exemples :\n"
            "  pve.py harden --host 192.168.1.50 --level 2 --password secret\n"
            "  pve.py harden --host 10.0.0.5 --level 3 --key ~/.ssh/id_ed25519\n"
            "  pve.py harden --host 10.0.0.5 --level 2 --password secret --audit\n"
            "  pve.py harden --host 10.0.0.5 --level 2 --password secret --dry-run\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p_hard.add_argument("--host", required=True, help="adresse IP ou nom d'hote de l'instance")
    p_hard.add_argument("--port", type=int, default=22, help="port SSH (22 par defaut)")
    p_hard.add_argument("--user", default="root", help="utilisateur SSH (root)")
    p_hard.add_argument("--key", default="", help="cle privee SSH")
    p_hard.add_argument(
        "--password",
        default=os.environ.get("PVE_ROOT_PASSWORD", ""),
        help="mot de passe root (ou variable d'environnement PVE_ROOT_PASSWORD)",
    )
    p_hard.add_argument(
        "--level", type=int, default=2, choices=(1, 2, 3, 4),
        help="niveau de durcissement (1=minimal ... 4=eleve)",
    )
    p_hard.add_argument(
        "--plan",
        default="stack",
        choices=("cis", "anssi", "ceph", "stack"),
        help="plan applique : CIS seul, ANSSI seul, Ceph seul, ou la pile complete",
    )
    p_hard.add_argument("--dry-run", action="store_true", help="simule sans modifier")
    p_hard.add_argument("--yes", action="store_true", help="ne demande pas de confirmation")
    p_hard.add_argument("--audit", action="store_true", help="execute l'audit apres durcissement")
    p_hard.add_argument(
        "--audit-extra",
        default="anssi,ceph,cis13,communautaire",
        help="modules d'audit supplementaires",
    )
    p_hard.add_argument("--report", default="", help="chemin du rapport Markdown")
    p_hard.add_argument("--pdf", default="", help="chemin du rapport PDF")
    p_hard.add_argument("--ssh-timeout", type=int, default=3600, help="timeout SSH (secondes)")

    # ------------------------------------------------------------------ pdf
    p_pdf = sub.add_parser("pdf", help="rend un HTML en PDF")
    p_pdf.add_argument("--html", required=True)
    p_pdf.add_argument("--pdf", required=True)
    p_pdf.add_argument("--browser", default="")

    # ------------------------------------------------------------------ info
    sub.add_parser("info", help="affiche la configuration du lab")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        return 0

    if args.command == "run":
        from .phases import Options, run_phase

        options = Options(
            phase=args.phase,
            target=args.target,
            level=args.level,
            ssh_host=args.ssh_host,
            ssh_port=args.ssh_port,
            ssh_user=args.ssh_user,
            key_path=Path(args.key),
            ssh_password=args.ssh_password,
            ssh_timeout=args.ssh_timeout,
            audit_extra=[a.strip() for a in args.audit_extra.split(",") if a.strip()],
            run_func=args.run_func,
            skip_vendor_verify=args.skip_vendor_verify,
            artifacts=ensure_dir(Path(args.artifacts)),
            report_title=args.title or None,
            report_path=Path(args.report) if args.report else None,
            pdf_path=Path(args.pdf) if args.pdf else None,
            no_pdf=args.no_pdf,
        )
        try:
            return run_phase(options)
        except Exception as exc:
            console.error("echec : {}".format(exc))
            return 1

    if args.command == "report":
        from .report import write_report

        write_report(
            args.before,
            args.after,
            report_path=Path(args.report) if args.report else None,
            pdf_path=Path(args.pdf) if args.pdf else None,
            title=args.title,
            before_func=args.before_func or None,
            after_func=args.after_func or None,
            no_pdf=args.no_pdf,
        )
        return 0

    if args.command == "fetch-vendor":
        from .vendor import fetch

        return fetch(Path(args.vendor_dir), force=args.force)

    if args.command == "verify-vendor":
        from .vendor import verify

        return verify(Path(args.vendor_dir))

    if args.command == "snapshot":
        from . import vbox

        try:
            if args.action == "create":
                vbox.snapshot_create(args.vm, args.name, args.description)
            elif args.action == "list":
                vbox.snapshot_list(args.vm)
            elif args.action == "restore":
                vbox.snapshot_restore(args.vm, args.name)
            else:
                vbox.snapshot_delete(args.vm, args.name)
        except Exception as exc:
            console.error(str(exc))
            return 1
        return 0

    if args.command == "image":
        from . import vbox

        try:
            if args.action == "save":
                vbox.image_save(args.vm, args.disk, args.image)
            else:
                vbox.image_restore(args.vm, args.disk, args.image)
        except Exception as exc:
            console.error(str(exc))
            return 1
        return 0

    if args.command == "publish":
        from .publish import publish

        try:
            return publish(
                Path(args.path),
                args.repo,
                token=args.token,
                use_gitkraken=args.use_gitkraken,
                owner=args.owner,
                visibility=args.visibility,
                push_tags=args.tags,
            )
        except Exception as exc:
            console.error(str(exc))
            return 1

    if args.command == "harden":
        from .harden import HardenOptions, harden

        options = HardenOptions(
            host=args.host,
            level=args.level,
            port=args.port,
            user=args.user,
            key=args.key,
            password=args.password,
            plan=args.plan,
            dry_run=args.dry_run,
            assume_yes=args.yes,
            audit=args.audit,
            audit_extra=[a.strip() for a in args.audit_extra.split(",") if a.strip()],
            report=args.report,
            pdf=args.pdf,
            timeout=args.ssh_timeout,
        )
        try:
            return harden(options)
        except Exception as exc:
            console.error("echec : {}".format(exc))
            return 1

    if args.command == "pdf":
        from .pdf import PdfError, render_html_to_pdf

        try:
            render_html_to_pdf(args.html, args.pdf, args.browser or None)
        except PdfError as exc:
            console.error(str(exc))
            return 1
        return 0

    if args.command == "info":
        console.step("Configuration du lab")
        console.write("  racine        : {}".format(LAB_ROOT))
        console.write("  scripts       : {}".format(LAB_ROOT / "scripts"))
        console.write("  guest         : {}".format(LAB_ROOT / "guest"))
        console.write("  artifacts     : {}".format(ARTIFACTS_DIR))
        console.write("  reports       : {}".format(REPORTS_DIR))
        console.write("  vendor        : {}".format(VENDOR_DIR))
        console.write("  cle           : {}".format(DEFAULT_KEY))
        console.write("  ssh           : {}@{}:{}".format(DEFAULT_SSH_USER, DEFAULT_SSH_HOST, DEFAULT_SSH_PORT))
        console.write("  version       : {}".format(__version__))
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
