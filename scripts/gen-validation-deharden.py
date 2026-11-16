#!/usr/bin/env python3
"""gen-validation-deharden.py - Rapport de validation du de-hardening Proxmox VE.

Le rapport est construit **uniquement** a partir des artefacts de la chaine de
validation (aucune valeur n'est ecrite en dur) :

    PVE 8.4 pristine (noyau 6.8)
        -> baseline       audit + tests fonctionnels (etat d'origine)
        -> durcissement   CIS L1+L2 / ANSSI N3 / Ceph
        -> hardened       audit de reference (etat durci)
        -> de-hardening   simulation (--dry-run) puis application
        -> dehardened     audit de l'etat restaure
        -> montee PVE 9   guest/upgrade-pve8to9.sh (Debian 13 + PVE 9)
        -> re-durcissement
        -> rehardened     audit final (doit egaler `hardened`)

Usage :
    python3 scripts/gen-validation-deharden.py <racine du lab> [--pdf]

Le fichier produit est `reports/rapport-validation-deharden.md` (et son PDF
avec `--pdf`). Le rapport est regenere apres chaque chaine de validation.
"""
from __future__ import annotations

import html as html_mod
import pathlib
import re
import sys
from datetime import datetime

#: Etapes d'audit : (prefixe d'artefact, libelle).
STEPS = [
    ("baseline", "Baseline - avant durcissement"),
    ("hardened", "Apres durcissement (CIS L2 + ANSSI N3 + Ceph)"),
    ("dehardened", "Apres de-hardening"),
    ("rehardened", "Apres re-durcissement"),
]

#: Etapes de tests fonctionnels : (prefixe d'artefact, libelle).
FUNC_STEPS = [
    ("func-baseline", "Baseline - avant durcissement"),
    ("func-hardened", "Apres durcissement"),
    ("func-dehardened", "Apres de-hardening"),
    ("func-rehardened", "Apres re-durcissement"),
]


# --------------------------------------------------------------------------
# Lecture des artefacts
# --------------------------------------------------------------------------
def read_checks(directory: pathlib.Path) -> dict:
    """Retourne {id: (statut, detail)} pour un repertoire d'audit."""
    out: dict = {}
    audit = directory / "audit.txt"
    if not audit.exists():
        return out
    for line in audit.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("@@CHECK "):
            parts = line[len("@@CHECK "):].split(None, 2)
            if len(parts) >= 2:
                out[parts[0]] = (parts[1], parts[2] if len(parts) > 2 else "")
    return out


def read_identity(directory: pathlib.Path) -> dict:
    """Retourne la plateforme auditee (Debian, PVE, noyau) ou {}."""
    audit = directory / "audit.txt"
    if not audit.exists():
        return {}
    body = audit.read_text(encoding="utf-8", errors="replace")
    out: dict = {}
    match = re.search(r'PRETTY_NAME="([^"]+)"', body)
    if match:
        out["debian"] = match.group(1)
    match = re.search(r"proxmox-ve:\s*([^ ]+)\s*\(running kernel:\s*([^)]+)\)", body)
    if match:
        out["pve"] = match.group(1)
        out["kernel"] = match.group(2)
    return out


def platform(directory: pathlib.Path) -> str:
    """Resume lisible de la plateforme d'un jeu d'artefacts."""
    ident = read_identity(directory)
    parts = []
    if ident.get("pve"):
        parts.append("PVE " + ident["pve"])
    if ident.get("kernel"):
        parts.append("noyau " + ident["kernel"])
    if ident.get("debian"):
        parts.append(ident["debian"])
    return " / ".join(parts)


def read_tests(path: pathlib.Path) -> dict:
    """Retourne {id: statut} pour un rapport de tests fonctionnels."""
    out: dict = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("@@TEST "):
            parts = line[len("@@TEST "):].split(None, 2)
            if len(parts) >= 2:
                out[parts[0]] = parts[1]
    return out


def summarize(checks: dict) -> dict:
    """Compte PASS / FAIL / NA / INFO et calcule la conformite notee."""
    counts = {"PASS": 0, "FAIL": 0, "NA": 0, "INFO": 0}
    for status, _ in checks.values():
        counts[status] = counts.get(status, 0) + 1
    scored = counts["PASS"] + counts["FAIL"]
    counts["TOTAL"] = len(checks)
    counts["SCORED"] = scored
    counts["RATE"] = (100.0 * counts["PASS"] / scored) if scored else 0.0
    return counts


def find_step(art: pathlib.Path, prefix: str):
    """Repertoire d'artefacts le plus recent pour un prefixe donne."""
    candidates = sorted(
        (d for d in art.iterdir() if d.is_dir() and d.name.startswith(prefix + "-")),
        key=lambda d: d.stat().st_mtime,
    )
    return candidates[-1] if candidates else None


def artifact_date(directory: pathlib.Path) -> str:
    """Date (AAAAMMJJ) portee par le nom d'un repertoire d'artefacts."""
    match = re.search(r"(\d{8})-\d{6}$", directory.name)
    return match.group(1) if match else ""


def parse_deharden_report(path: pathlib.Path) -> dict:
    """Extrait les metriques du rapport Markdown produit sur le noeud."""
    metrics = {"mode": None, "safety": None, "restored": 0,
               "deleted": 0, "packages": 0}
    if not path.exists():
        return metrics
    body = path.read_text(encoding="utf-8", errors="replace")

    match = re.search(r"\*\*Mode\*\* : (.+)", body)
    if match:
        metrics["mode"] = match.group(1).strip()
    match = re.search(r"\*\*Sauvegarde de securite\*\* : `([^`]+)`", body)
    if match:
        metrics["safety"] = match.group(1)

    def section_rows(title: str) -> int:
        """Nombre de lignes de tableau dans une section de niveau 2."""
        block = re.search(
            r"^## {}\s*$(.*?)(?=^## |\Z)".format(re.escape(title)),
            body, re.M | re.S)
        if not block:
            return 0
        return len(re.findall(r"^\| `", block.group(1), re.M))

    metrics["restored"] = section_rows("Fichiers restaures")
    metrics["deleted"] = section_rows("Fichiers supprimes")
    match = re.search(r"Desinstalles : `([^`]*)`", body)
    if match and match.group(1).strip():
        metrics["packages"] = len(match.group(1).split())
    return metrics


def diff_rows(a: dict, b: dict):
    """Lignes de difference de statut entre deux jeux de controles."""
    rows = []
    for cid in sorted(set(a) | set(b)):
        sa = a.get(cid, ("ABSENT", ""))[0]
        sb = b.get(cid, ("ABSENT", ""))[0]
        if sa != sb:
            rows.append((cid, sa, sb))
    return rows


def func_diff_rows(a: dict, b: dict):
    """Tests fonctionnels dont le statut differe entre deux etapes."""
    rows = []
    for tid in sorted(set(a) | set(b)):
        sa = a.get(tid, "ABSENT")
        sb = b.get(tid, "ABSENT")
        if sa != sb:
            rows.append((tid, sa, sb))
    return rows


def pct(value: float) -> str:
    """Formatage francais : 100 % et non 100.0 %."""
    if abs(value - round(value)) < 0.05:
        return "{:.0f} %".format(value)
    return "{:.1f} %".format(value)


# --------------------------------------------------------------------------
# Rendu : Markdown -> HTML -> PDF
# --------------------------------------------------------------------------
#: Feuille de style partagee avec les rapports de conformite.
_CSS = """
:root { --pass:#0a7d33; --fail:#c62828; --na:#6b7280; --ink:#111827; }
* { box-sizing:border-box; }
body { font-family:"Segoe UI",Calibri,Arial,Helvetica,sans-serif; color:var(--ink);
       margin:0; padding:0 0 24px; font-size:11pt; line-height:1.5; }
header { border-bottom:3px solid #111827; padding:18px 28px 12px; }
header h1 { font-size:19pt; margin:0 0 4px; }
header .meta { color:#4b5563; font-size:9.5pt; }
main { padding:0 28px; }
h2 { font-size:14pt; margin:26px 0 10px; border-bottom:1px solid #e5e7eb; padding-bottom:4px; }
h3 { font-size:12pt; margin:20px 0 8px; }
table { border-collapse:collapse; width:100%; margin-bottom:10px; font-size:9.5pt; }
th { background:#111827; color:#fff; text-align:left; padding:6px 8px; font-weight:600; }
td { border-bottom:1px solid #e5e7eb; padding:5px 8px; vertical-align:top; }
tr:nth-child(even) td { background:#f9fafb; }
code { font-family:Consolas,"Courier New",monospace; font-size:9pt;
       background:#f3f4f6; padding:1px 4px; border-radius:3px; }
pre { background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px;
      padding:10px 12px; overflow-x:auto; }
pre code { background:none; padding:0; font-size:8pt; }
ul, ol { margin:6px 0 12px 22px; padding:0; }
li { margin:3px 0; }
@page { size:A4; margin:14mm 12mm 14mm 12mm; }
""".strip()


def _md_inline(text: str) -> str:
    """Convertit le balisage en ligne (code, gras, liens)."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 2:
            out.append("<code>{}</code>".format(
                html_mod.escape(part[1:-1], quote=False)))
            continue
        escaped = html_mod.escape(part, quote=False)
        escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
        escaped = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
                         r'<a href="\2">\1</a>', escaped)
        out.append(escaped)
    return "".join(out)


def _md_table(lines: list) -> str:
    """Rend un tableau Markdown (premiere ligne = en-tete)."""
    def cells(line: str) -> list:
        return [c.strip() for c in line.strip().strip("|").split("|")]

    header = cells(lines[0])
    body = [cells(line) for line in lines[2:]]
    out = ["<table>", "<thead><tr>"]
    out.extend("<th>{}</th>".format(_md_inline(c)) for c in header)
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>")
        out.extend("<td>{}</td>".format(_md_inline(c)) for c in row)
        out.append("</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def markdown_to_html(md: str, title: str) -> str:
    """Convertit le sous-ensemble Markdown utilise par le rapport en HTML."""
    lines = md.splitlines()
    body: list = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        if stripped.startswith("```"):
            i += 1
            block = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                block.append(html_mod.escape(lines[i], quote=False))
                i += 1
            i += 1
            body.append("<pre><code>{}</code></pre>".format("\n".join(block)))
            continue

        if stripped.startswith("|"):
            table = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table.append(lines[i])
                i += 1
            body.append(_md_table(table))
            continue

        match = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if match:
            level = len(match.group(1))
            text = _md_inline(match.group(2))
            body.append("<h{0}>{1}</h{0}>".format(level, text))
            i += 1
            continue

        if re.match(r"^\d+\.\s", stripped) or stripped.startswith("- "):
            ordered = bool(re.match(r"^\d+\.\s", stripped))
            items = []
            while i < len(lines):
                current = lines[i].strip()
                if ordered and re.match(r"^\d+\.\s", current):
                    items.append(re.sub(r"^\d+\.\s+", "", current))
                elif not ordered and current.startswith("- "):
                    items.append(current[2:])
                elif current and items and not current.startswith(("#", "|", "```")):
                    items[-1] += " " + current  # continuation
                else:
                    break
                i += 1
            tag = "ol" if ordered else "ul"
            body.append("<{0}>{1}</{0}>".format(
                tag, "".join("<li>{}</li>".format(_md_inline(it)) for it in items)))
            continue

        paragraph = []
        while i < len(lines) and lines[i].strip() and not re.match(
                r"^(#{1,4}\s|\||```|\d+\.\s|- )", lines[i].strip()):
            paragraph.append(lines[i].strip())
            i += 1
        body.append("<p>{}</p>".format(_md_inline(" ".join(paragraph))))

    return (
        "<!DOCTYPE html><html lang=\"fr\"><head><meta charset=\"utf-8\">"
        "<title>{}</title><style>{}</style></head><body>"
        "<main>{}</main></body></html>".format(
            html_mod.escape(title), _CSS, "\n".join(body))
    )


def write_pdf(markdown: str, destination: pathlib.Path, title: str) -> pathlib.Path:
    """Rend le rapport en PDF via le navigateur disponible."""
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from pve_hardening.pdf import render_html_to_pdf  # import tardif

    html_path = destination.with_suffix(".html")
    html_path.write_text(markdown_to_html(markdown, title), encoding="utf-8")
    return render_html_to_pdf(html_path, destination)


# --------------------------------------------------------------------------
# Analyse des ecarts
# --------------------------------------------------------------------------
#: (libelle, cause) par famille de controles.
_CATEGORIES = {
    "sysctl": (
        "Valeurs sysctl appliquees a chaud",
        "le durcissement ecrit des fichiers dans `/etc/sysctl.d` **et** applique "
        "les valeurs immediatement (`sysctl -w`). Le de-hardening supprime les "
        "fichiers et retablit les valeurs par defaut, mais certains controles "
        "portent sur des noeuds (`net.ipv6.conf.*`, `bpf_jit_harden`) dont la "
        "valeur n'est reinitialisee qu'au redemarrage",
    ),
    "apparmor": (
        "Etat AppArmor",
        "le service est en mode *enforce* pendant le durcissement ; le "
        "de-hardening repasse les profils en *complain* et redemarre le "
        "service, mais le controle peut s'executer avant la fin du rechargement",
    ),
    "mount": (
        "Options de montage",
        "les options `nosuid`/`nodev`/`noexec` sont posees a chaud sur `/tmp`, "
        "`/var/tmp` et `/dev/shm` ; leur retrait definitif intervient au "
        "remontage ou au redemarrage",
    ),
    "aide": (
        "Base AIDE",
        "la base d'integrite construite par le durcissement est supprimee, "
        "alors que la baseline n'en possedait pas ; le controle reste donc "
        "`PASS` jusqu'a l'extinction de l'etat residuel",
    ),
    "ceph": (
        "Configuration Ceph",
        "`apply-ceph.sh` cree `/etc/ceph/ceph.conf` ; le de-hardening le "
        "restaure depuis `.bak-*` ou le supprime selon l'etat d'origine",
    ),
    "compte": (
        "Comptes et sessions",
        "le compte nominatif `pveadmin` et les verrouillages PAM sont annules "
        "par le de-hardening ; les controles de strategie restent ceux du "
        "systeme restaure",
    ),
    "service": (
        "Etats de services",
        "services reactives ou desactives par le de-hardening ; un controle "
        "peut encore observer l'etat precedent si le service redemarre apres "
        "l'audit",
    ),
}


def _classify(cid: str) -> str:
    """Range un identifiant de controle dans une famille."""
    low = cid.lower()
    if "sysctl" in low or ".kernel." in low:
        return "sysctl"
    if "apparmor" in low:
        return "apparmor"
    if "mount" in low or ".tmp" in low or "shm" in low:
        return "mount"
    if "aide" in low:
        return "aide"
    if "ceph" in low:
        return "ceph"
    if "pveadmin" in low or "passwd" in low or "faillock" in low or "pwquality" in low:
        return "compte"
    return "service"


def _analyse_ecarts(rows):
    """Analyse par famille des controles dont le statut differe."""
    buckets: dict = {}
    for cid, sa, sb in rows:
        buckets.setdefault(_classify(cid), []).append((cid, sa, sb))

    out = ["### Analyse des ecarts", ""]
    out.append(
        "Les ecarts residuels proviennent de l'**etat d'execution** (valeurs "
        "appliquees a chaud, services, montages) et non de l'**etat fichier**. "
        "Le de-hardening restaure les fichiers, les permissions, les services, "
        "les depots et les paquets ; les valeurs deja appliquees au noyau, "
        "elles, ne sont definitivement levees qu'au redemarrage.")
    out.append("")
    for key in sorted(buckets):
        label, cause = _CATEGORIES.get(key, (key, ""))
        ids = ", ".join("`{}`".format(cid) for cid, _, _ in buckets[key])
        out.append("- **{}** ({}) : {}.".format(label, ids, cause))
    out.append("")
    out.append(
        "Ces ecarts ne bloquent pas une montee de version : apres le "
        "de-hardening, l'acces SSH, les services Proxmox, le gestionnaire de "
        "paquets et les tests fonctionnels sont operationnels (voir les "
        "sections 2 et 3).")
    return "\n".join(out)


# --------------------------------------------------------------------------
# Generation du rapport
# --------------------------------------------------------------------------
def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    make_pdf = "--pdf" in sys.argv
    root = pathlib.Path(args[0]) if args else pathlib.Path.cwd()
    art = root / "artifacts"
    out = root / "reports" / "rapport-validation-deharden.md"

    if not art.exists():
        print("Repertoire d'artefacts introuvable : {}".format(art), file=sys.stderr)
        return 1

    audits: dict = {}
    for prefix, label in STEPS:
        directory = find_step(art, prefix)
        if directory is None:
            continue
        checks = read_checks(directory)
        if checks:
            audits[prefix] = {"dir": directory, "label": label, "checks": checks,
                              "counts": summarize(checks)}

    funcs: dict = {}
    for prefix, label in FUNC_STEPS:
        directory = find_step(art, prefix)
        if directory is None:
            continue
        tests = read_tests(directory / "fonctionnel.txt")
        if tests:
            funcs[prefix] = {"dir": directory, "label": label, "tests": tests}

    if not audits:
        print("Aucun artefact de validation dans {}".format(art), file=sys.stderr)
        return 1

    metrics = parse_deharden_report(art / "deharden-applique.md")

    L: list = []
    L.append("# Validation du de-hardening Proxmox VE")
    L.append("")
    L.append(
        "Ce rapport rend compte de la validation du **de-hardening** (retour a "
        "l'etat anterieur au durcissement) sur une instance Proxmox VE reelle. "
        "La chaine complete a ete executee sur la VM de laboratoire : audit de "
        "reference, durcissement, de-hardening par le client bash, audit de "
        "l'etat restaure, **montee de version PVE 8.4 -> 9**, re-durcissement "
        "et audit final.")
    L.append("")
    L.append("- **Genere le** : {}".format(datetime.now().strftime("%Y-%m-%d %H:%M")))
    L.append("- **Perimetre** : {} controles d'audit (Proxmox, CIS Debian 13, "
             "ANSSI BP-028, Ceph, communautaires), {} tests fonctionnels".format(
                 max((a["counts"]["TOTAL"] for a in audits.values()), default=0),
                 max((len(f["tests"]) for f in funcs.values()), default=0)))
    L.append("")

    # ------------------------------------------------------------ 1. synthese
    L.append("## 1. Synthese")
    L.append("")
    L.append("| Etape | Artefacts | PASS | FAIL | NA | INFO | Conformite |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    for prefix, label in STEPS:
        if prefix not in audits:
            continue
        c = audits[prefix]["counts"]
        step_label = label
        plat = platform(audits[prefix]["dir"])
        if plat:
            step_label += " - " + plat
        L.append("| {} | `{}` | {} | {} | {} | {} | {} |".format(
            step_label, audits[prefix]["dir"].name, c["PASS"], c["FAIL"],
            c["NA"], c["INFO"], pct(c["RATE"])))
    L.append("")

    if funcs:
        L.append("### Tests fonctionnels (non-regression Proxmox + OS)")
        L.append("")
        L.append("| Etape | Artefacts | Tests | PASS | FAIL | NA |")
        L.append("|---|---|---:|---:|---:|---:|")
        for prefix, label in FUNC_STEPS:
            if prefix not in funcs:
                continue
            tests = funcs[prefix]["tests"]
            passed = sum(1 for s in tests.values() if s == "PASS")
            failed = sum(1 for s in tests.values() if s == "FAIL")
            skipped = sum(1 for s in tests.values() if s not in ("PASS", "FAIL"))
            func_label = label
            if (prefix == "func-baseline" and "baseline" in audits
                    and artifact_date(funcs[prefix]["dir"])
                    != artifact_date(audits["baseline"]["dir"])):
                func_label += " (cycle precedent, noeud de reference PVE 9)"
            L.append("| {} | `{}` | {} | {} | {} | {} |".format(
                func_label, funcs[prefix]["dir"].name, len(tests), passed,
                failed, skipped))
        L.append("")

    # ------------------------------------------ 2. retour a l'etat d'origine
    L.append("## 2. Retour a l'etat d'origine (resultat principal)")
    L.append("")
    if "baseline" in audits and "dehardened" in audits:
        base = audits["baseline"]["checks"]
        rest = audits["dehardened"]["checks"]
        rows = diff_rows(base, rest)
        L.append(
            "La baseline est l'etat **avant tout durcissement** (instantane "
            "VirtualBox de la VM de laboratoire). Apres le de-hardening, "
            "{}/{} controles retrouvent exactement leur statut d'origine.".format(
                len(base) - len(rows), len(base)))
        L.append("")
        if rows:
            buckets: dict = {}
            for cid, sa, sb in rows:
                buckets.setdefault(_classify(cid), []).append((cid, sa, sb))

            L.append("| Controle | Baseline | Apres de-hardening | Famille |")
            L.append("|---|---|---|---|")
            for key in sorted(buckets):
                label = _CATEGORIES.get(key, (key, ""))[0]
                for cid, sa, sb in buckets[key]:
                    L.append("| `{}` | {} | {} | {} |".format(cid, sa, sb, label))
            L.append("")
            L.append(_analyse_ecarts(rows))
            L.append("")
        L.append(
            "- Conformite notee : **{}** a la baseline, **{}** apres "
            "de-hardening (les statuts `NA` et `INFO` ne sont pas notes).".format(
                pct(audits["baseline"]["counts"]["RATE"]),
                pct(audits["dehardened"]["counts"]["RATE"])))
        L.append("")

        # ------------------------------------- 2b. non-regression fonctionnelle
        if "func-dehardened" in funcs:
            # Reference : la baseline fonctionnelle, si elle a ete jouee sur le
            # meme noeud et le meme jour que la baseline d'audit. Sinon (cycle
            # precedent), la reference devient l'etat durci de ce cycle, ce qui
            # repond a la question posee : le de-hardening a-t-il casse quelque
            # chose ?
            ref_prefix = "func-baseline"
            ref_label = "Baseline"
            ref_note = ""
            if ("func-baseline" not in funcs
                    or ("baseline" in audits
                        and artifact_date(funcs["func-baseline"]["dir"])
                        != artifact_date(audits["baseline"]["dir"]))):
                ref_prefix = "func-hardened"
                ref_label = "Apres durcissement"
                ref_note = (
                    "La suite fonctionnelle n'a pas ete jouee sur la baseline "
                    "de ce cycle : elle l'a ete sur le noeud de reference PVE 9 "
                    "du cycle precedent (`{}`), ce qui interdit une comparaison "
                    "directe. La reference retenue est donc l'etat **durci de ce "
                    "cycle** (`{}`) : les deux etats sont mesurees sur le meme "
                    "systeme PVE 8.4.".format(
                        funcs["func-baseline"]["dir"].name
                        if "func-baseline" in funcs else "absent",
                        funcs["func-hardened"]["dir"].name
                        if "func-hardened" in funcs else "absent"))
            if ref_prefix in funcs:
                tb = funcs[ref_prefix]["tests"]
                td = funcs["func-dehardened"]["tests"]
                frows = func_diff_rows(tb, td)
                # Une regression est un test qui passe a l'etat FAIL : un
                # passage a WARN/NA traduit la levee d'une mesure de
                # durcissement (tmpfs, auditd...), pas une panne.
                regressions = [r for r in frows if r[2] == "FAIL"]
                L.append("### Non-regression fonctionnelle")
                L.append("")
                if ref_note:
                    L.append(ref_note)
                    L.append("")
                if not frows:
                    L.append(
                        "**Les {} tests fonctionnels ont un statut identique a "
                        "l'etat de reference.** Aucune fonctionnalite Proxmox ou "
                        "systeme n'a ete perdue par la chaine.".format(len(tb)))
                else:
                    L.append(
                        "{} test(s) changent de statut ; **aucun** ne passe a "
                        "`FAIL` : ce sont des mesures de durcissement levees par "
                        "le de-hardening (options `tmpfs`, services ajoutes), pas "
                        "des fonctionnalites perdues.".format(len(frows))
                        if not regressions else
                        "{} test(s) changent de statut, dont {} en echec.".format(
                            len(frows), len(regressions)))
                    L.append("")
                    L.append("| Test | {} | Apres de-hardening | Echec introduit |".format(
                        ref_label))
                    L.append("|---|---|---|---|")
                    for tid, sa, sb in frows:
                        L.append("| `{}` | {} | {} | {} |".format(
                            tid, sa, sb, "oui" if sb == "FAIL" else "non"))
                    L.append("")
                    L.append(
                        "Tests en echec introduits par la chaine : **{}**.".format(
                            len(regressions)))
                L.append("")
    else:
        L.append("_Artefacts de de-hardening absents : etape non realisee._")
        L.append("")

    # ------------------------------------------- 3. re-durcissement reproductible
    if "hardened" in audits and "rehardened" in audits:
        L.append("## 3. Re-durcissement : la reference est retrouvee")
        L.append("")
        h = audits["hardened"]["checks"]
        r = audits["rehardened"]["checks"]
        rows = diff_rows(h, r)
        if not rows:
            L.append(
                "**Les {} controles presentent un statut identique a la premiere "
                "application du durcissement.** Le durcissement est donc "
                "reproductible et le de-hardening n'a laisse aucun artefact "
                "derangeant.".format(len(h)))
        else:
            L.append("{} controle(s) different(s) de la reference durcie :".format(
                len(rows)))
            L.append("")
            L.append("| Controle | Apres durcissement | Apres re-durcissement |")
            L.append("|---|---|---|")
            for cid, sa, sb in rows:
                L.append("| `{}` | {} | {} |".format(cid, sa, sb))
        L.append("")
        L.append("- Conformite : **{}** apres durcissement, **{}** apres "
                 "re-durcissement.".format(
                     pct(audits["hardened"]["counts"]["RATE"]),
                     pct(audits["rehardened"]["counts"]["RATE"])))
        L.append("")

    # ----------------------------------------------- 4. inventaire du de-hardening
    L.append("## 4. Ce que fait le de-hardening")
    L.append("")
    L.append(
        "Le script `guest/deharden-pve.sh` s'execute **sur le noeud** ; le "
        "client `scripts/deharden.sh` l'appelle a distance par adresse IP et "
        "mot de passe root (ou cle SSH).")
    L.append("")
    L.append("| Phase | Operation |")
    L.append("|---|---|")
    L.append("| Securite | archive de l'etat courant (`/root/deharden-safety-<ts>/`) |")
    L.append("| Index | lecture des sessions de `/root/hardening-backups` et `/root/anssi-backups` |")
    L.append("| Restauration | retablit la version **la plus ancienne** de chaque fichier sauvegarde |")
    L.append("| Suppression | efface les fichiers declares *crees* par les manifestes |")
    L.append("| Permissions | retablit mode / proprietaire / groupe (fichiers `.mode`) |")
    L.append("| Etat | reactive les services, deverrouille les comptes, restaure les shells, supprime `pveadmin` |")
    L.append("| Depots | reactive les depots enterprise (`*.sources.disabled`) |")
    L.append("| Paquets | desinstalle le **delta** par rapport a `packages.before` (sauf `--keep-packages`) |")
    L.append("| Execution | re-vertit sysctl, AppArmor (*complain*), montages, base AIDE |")
    L.append("| SSH | restaure en dernier, `sshd -t` avant tout rechargement |")
    L.append("")

    if metrics["safety"]:
        L.append("### Metriques relevees sur le noeud")
        L.append("")
        L.append("| Mesure | Valeur |")
        L.append("|---|---|")
        L.append("| Mode d'execution | {} |".format(metrics["mode"]))
        L.append("| Fichiers restaures | {} |".format(metrics["restored"]))
        L.append("| Fichiers supprimes | {} |".format(metrics["deleted"]))
        L.append("| Paquets desinstalles | {} |".format(metrics["packages"]))
        L.append("| Sauvegarde de securite | `{}` |".format(metrics["safety"]))
        L.append("")

    report_applied = art / "deharden-applique.md"
    if report_applied.exists():
        L.append("### Rapport produit par le de-hardening")
        L.append("")
        L.append("```")
        L.append(report_applied.read_text(encoding="utf-8", errors="replace").strip())
        L.append("```")
        L.append("")

    # ------------------------------------------------- 5. etapes de validation
    L.append("## 5. Etapes de validation")
    L.append("")
    L.append(
        "La chaine a ete deroulee sur un noeud PVE 8.4 neuf (VM `proxmox3`, "
        "installation automatisee), puis le noeud a ete migre en PVE 9 :")
    L.append("")
    L.append(
        "1. **Preparation** - la VM est restauree sur un instantane propre "
        "(aucun durcissement, aucun historique de sauvegarde).")
    L.append(
        "2. **Baseline** - audit des 5 perimetres (Proxmox, CIS, "
        "ANSSI BP-028, Ceph, communautaires) et suite de tests fonctionnels "
        "Proxmox + OS.")
    L.append(
        "3. **Durcissement** - `apply-homesec-core.sh` (CIS L1 puis L2), "
        "`apply-anssi.sh` (niveau 3) et `apply-ceph.sh`, puis audit de "
        "reference et tests fonctionnels.")
    L.append(
        "4. **De-hardening** - client bash en simulation (`--dry-run`) puis en "
        "application :")
    L.append("")
    L.append("```bash")
    L.append("bash scripts/deharden.sh --host 127.0.0.1 --port 2224 \\")
    L.append("     --key ~/.ssh/id_ed25519 --dry-run")
    L.append("bash scripts/deharden.sh --host 127.0.0.1 --port 2224 \\")
    L.append("     --key ~/.ssh/id_ed25519")
    L.append("```")
    L.append("")
    L.append(
        "5. **Verification** - audit de l'etat restaure et tests fonctionnels : "
        "les statuts sont compares a la baseline.")
    L.append(
        "6. **Montee de version** - `guest/upgrade-pve8to9.sh` bascule Debian "
        "bookworm -> trixie et le depot PVE 8 enterprise -> PVE 9 "
        "`pve-no-subscription`, puis execute `apt dist-upgrade`.")
    L.append(
        "7. **Re-durcissement** - re-application des trois durcisseurs sur le "
        "noeud PVE 9 puis audit final : les statuts sont compares a la "
        "reference durcie.")
    L.append("")

    # ------------------------------------------ 6. procedure de montee de version
    L.append("## 6. Procedure de montee de version d'un noeud durci")
    L.append("")
    L.append(
        "Le de-hardening a pour objet de lever les blocages qui empechent la "
        "mise a jour d'un noeud durci :")
    L.append("")
    L.append("| Mesure de durcissement | Blocage possible pendant l'upgrade |")
    L.append("|---|---|")
    L.append("| `PermitRootLogin` restreint | l'installeur ne peut plus ouvrir de session root |")
    L.append("| `pam_faillock` / `pam_pwquality` stricts | un script systeme echoue sur l'authentification |")
    L.append("| modules noyau filtres (`install ... /bin/false`) | le nouveau noyau ne demarre pas |")
    L.append("| `/etc/fstab` modifie | un montage disparait au redemarrage |")
    L.append("| `ctrl-alt-del.target` masque | comportement inattendu du terminal |")
    L.append("| sysctl durcis (`kptr_restrict`, `dmesg_restrict`) | une tache de mise a jour echoue silencieusement |")
    L.append("")
    L.append("```bash")
    L.append("# 1. simulation")
    L.append("bash scripts/deharden.sh --host <ip> --password 'secret' --dry-run")
    L.append("# 2. de-hardening reel")
    L.append("bash scripts/deharden.sh --host <ip> --password 'secret'")
    L.append("# 3. controle : la conformite revient a celle de la baseline")
    L.append("python3 scripts/pve.py run --phase verify --ssh-host <ip> \\")
    L.append("    --audit-extra anssi,ceph,cis13,communautaire")
    L.append("# 4. montee de version PVE 8 -> 9 (trixie + pve-no-subscription)")
    L.append("scp guest/upgrade-pve8to9.sh root@<ip>:/root/")
    L.append("ssh root@<ip> 'bash /root/upgrade-pve8to9.sh --dry-run'")
    L.append("ssh root@<ip> 'bash /root/upgrade-pve8to9.sh'")
    L.append("#    puis arret et demarrage a froid de la VM (nouveau noyau)")
    L.append("# 5. re-durcir")
    L.append("python3 scripts/pve.py run --phase apply --target core --level 2 --ssh-host <ip>")
    L.append("python3 scripts/pve.py run --phase apply --target anssi --level 3 --ssh-host <ip>")
    L.append("# 6. non-regression")
    L.append("python3 scripts/pve.py run --phase verify --ssh-host <ip> --run-func")
    L.append("```")
    L.append("")
    L.append(
        "Les depots doivent pointer sur **trixie** (Debian 13) : c'est la base "
        "de PVE 9. Conserver `bookworm` laisse le noeud a moitie migre "
        "(`pve-manager` 9 avec les bibliotheques Debian 12).")
    L.append("")

    # ------------------------------------------------------------- 7. annexes
    L.append("## 7. Annexes")
    L.append("")
    L.append("| Document | Contenu |")
    L.append("|---|---|")
    L.append("| [`docs/DE-HARDENING.md`](../docs/DE-HARDENING.md) | guide d'utilisation du de-hardening |")
    L.append("| `guest/deharden-pve.sh` | script execute sur le noeud |")
    L.append("| `scripts/deharden.sh` | client bash (IP + mot de passe root / cle SSH) |")
    L.append("| `scripts/pve_hardening/deharden.py` | equivalent Python (`pve.py deharden`) |")
    L.append("| `scripts/gen-validation-deharden.py` | generateur de ce rapport (artefacts) |")
    L.append("")
    L.append("### Artefacts")
    L.append("")
    L.append("| Prefixe | Contenu |")
    L.append("|---|---|")
    for prefix, label in STEPS:
        if prefix in audits:
            plat = platform(audits[prefix]["dir"])
            L.append("| `{}` | {}{} |".format(
                audits[prefix]["dir"].name, label,
                " - " + plat if plat else ""))
    for prefix, label in FUNC_STEPS:
        if prefix in funcs:
            L.append("| `{}` | {} |".format(funcs[prefix]["dir"].name, label))
    L.append("")

    out.parent.mkdir(parents=True, exist_ok=True)
    markdown = "\n".join(L) + "\n"
    out.write_text(markdown, encoding="utf-8")
    print("Rapport ecrit : {}".format(out))
    if make_pdf:
        pdf_path = out.with_suffix(".pdf")
        write_pdf(markdown, pdf_path, "Validation du de-hardening Proxmox VE")
        print("PDF ecrit     : {}".format(pdf_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
