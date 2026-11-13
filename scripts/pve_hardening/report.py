"""Generation du rapport de comparaison avant / apres (Markdown, HTML, PDF).

Equivalent Python de ``scripts/compare.ps1`` : meme structure de rapport,
memes sections, memes tableaux. Le rapport est organise en :

1. Synthese (KPI PASS/FAIL, regressions, non-regression fonctionnelle)
2. Regressions / Ameliorations
3. Conformite par perimetre de guide
4. Controles en echec restants
5. Recapitulatif complet de tous les controles
6. Tests fonctionnels (detail + synthese par suite)

Deux garanties issues des cycles de validation :

* le tableau de synthese affiche **tous** les statuts (PASS / FAIL / WARN /
  NA) avec une colonne de controle qui verifie que leur somme egale le
  nombre total de tests : aucun test ne peut disparaitre du rapport ;
* les tests non conformes (WARN / NA) sont listes avec leur motif.
"""

from __future__ import annotations

import html as html_mod
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Iterable

from .config import relative
from .console import console
from .pdf import PdfError, render_html_to_pdf

CHECK_RE = re.compile(r"^@@CHECK\s+(\S+)\s+(\S+)\s*(.*)$")
TEST_RE = re.compile(r"^@@TEST\s+(\S+)\s+(\S+)\s*(.*)$")

#: Familles de referentiel, pour la ventilation de la conformite.
SCOPES = (
    (r"^CIS\.", "CIS Debian 13"),
    (r"^ANS\.", "ANSSI BP-028"),
    (r"^CEPH\.", "Ceph"),
    (r"^COMM\.", "Communautaire (harbian/BP-028)"),
    (r"^(OS|PVE|USR|SYS)\.", "PVE 9 / OS"),
)


@dataclass
class Check:
    """Un controle d'audit."""

    id: str
    status: str
    detail: str


@dataclass
class Row:
    """Une ligne de tableau (entete + valeurs)."""

    header: list[str]
    rows: list[list[str]] = field(default_factory=list)

    def add(self, *values) -> None:
        self.rows.append([str(v) for v in values])


def scope_of(check_id: str) -> str:
    """Retournent le perimetre de guide d'un controle."""
    for pattern, name in SCOPES:
        if re.match(pattern, check_id):
            return name
    return "Autres"


def sort_key(check_id: str) -> tuple[str, str]:
    """Cle de tri equivalente a ``Sort-Object`` de PowerShell.

    Le tri de PowerShell est **culturel** : insensible a la casse et il
    ignore les separateurs (``_``, ``-``, ``.``) au premier niveau de
    comparaison. Exemple : ``COMM.SYSCTL.NET_IPV4_CONF_all_RP_FILTER`` se
    classe avant ``..._ALL_SEND_REDIRECTS``.
    """
    normalized = re.sub(r"[^a-z0-9]", "", check_id.lower())
    return (normalized, check_id)


def fmt_pct(value: float) -> str:
    """Formate un pourcentage comme PowerShell : ``100`` et non ``100.0``."""
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    return str(round(value, 1))


def read_checks(directory: str | Path) -> dict[str, Check]:
    """Lit les controles d'un repertoire d'audit."""
    path = Path(directory) / "audit.txt"
    if not path.exists():
        raise FileNotFoundError("audit.txt introuvable dans {}".format(directory))
    checks: dict[str, Check] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = CHECK_RE.match(line)
        if m:
            checks[m.group(1)] = Check(m.group(1), m.group(2), m.group(3).strip())
    return checks


def read_tests(path: str | Path | None) -> dict[str, Check]:
    """Lit un rapport de tests fonctionnels (``@@TEST ...``)."""
    tests: dict[str, Check] = {}
    if not path:
        return tests
    p = Path(path)
    if not p.exists():
        return tests
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        m = TEST_RE.match(line)
        if m:
            tests[m.group(1)] = Check(m.group(1), m.group(2), m.group(3).strip())
    return tests


def _count(items: Iterable[Check], status: str) -> int:
    return sum(1 for c in items if c.status == status)


def _suite_ids(tests: dict[str, Check], suite: str) -> list[str]:
    if suite == "OS":
        return [k for k in tests if k.startswith("OS.")]
    return [k for k in tests if not k.startswith("OS.")]


def build_report(
    before_dir: str | Path,
    after_dir: str | Path,
    title: str = "Comparatif de hardening - Proxmox VE 9",
    before_func: str | Path | None = None,
    after_func: str | Path | None = None,
) -> dict:
    """Construit le modele du rapport (donnees + tableaux)."""
    before = read_checks(before_dir)
    after = read_checks(after_dir)
    tests_before = read_tests(before_func)
    tests_after = read_tests(after_func)

    regressions: list[tuple[Check, Check]] = []
    improvements: list[tuple[Check, Check]] = []
    unchanged: list[tuple[Check, Check]] = []
    lost: list[Check] = []
    new: list[Check] = []

    for cid, b in before.items():
        if cid not in after:
            lost.append(b)
            continue
        a = after[cid]
        if b.status == a.status:
            unchanged.append((b, a))
        elif b.status == "PASS" and a.status != "PASS":
            regressions.append((b, a))
        elif b.status != "PASS" and a.status == "PASS":
            improvements.append((b, a))
        else:
            unchanged.append((b, a))
    for cid, a in after.items():
        if cid not in before:
            new.append(a)

    pb, fb = _count(before.values(), "PASS"), _count(before.values(), "FAIL")
    pa, fa = _count(after.values(), "PASS"), _count(after.values(), "FAIL")
    delta = pa - pb

    func_regression = 0
    func_improvement = 0
    if tests_before and tests_after:
        for tid in tests_after:
            if tid not in tests_before:
                continue
            b_status, a_status = tests_before[tid].status, tests_after[tid].status
            if b_status == a_status:
                continue
            if b_status == "PASS" and a_status != "PASS":
                func_regression += 1
            else:
                func_improvement += 1

    tables: list[tuple[str, Row]] = []

    if regressions:
        row = Row(["Controle", "Avant", "Apres", "Detail"])
        for b, a in regressions:
            row.add("`{}`".format(b.id), b.status, a.status, a.detail)
        tables.append(("Regressions", row))

    if improvements:
        row = Row(["Controle", "Avant", "Apres", "Detail"])
        for b, a in improvements:
            row.add("`{}`".format(b.id), b.status, a.status, a.detail)
        tables.append(("Ameliorations", row))

    # Conformite par perimetre de guide
    scopes: dict[str, dict[str, int]] = {}
    for cid, a in after.items():
        if cid.startswith("__"):
            continue
        sc = scope_of(cid)
        entry = scopes.setdefault(sc, {"total": 0, "pb": 0, "pa": 0, "fa": 0})
        entry["total"] += 1
        if cid in before and before[cid].status == "PASS":
            entry["pb"] += 1
        if a.status == "PASS":
            entry["pa"] += 1
        if a.status == "FAIL":
            entry["fa"] += 1
    row = Row(
        [
            "Perimetre",
            "Controles",
            "PASS avant",
            "PASS apres",
            "Delta",
            "Echecs restants",
            "Conformite apres",
        ]
    )
    for sc in sorted(scopes, key=lambda k: sort_key(k)):
        s = scopes[sc]
        evaluated = s["pa"] + s["fa"]
        pct = round(100 * s["pa"] / evaluated, 1) if evaluated else 0
        row.add(
            sc,
            s["total"],
            s["pb"],
            s["pa"],
            s["pa"] - s["pb"],
            s["fa"],
            "{} %".format(fmt_pct(pct)),
        )
    tables.append(("Conformite par perimetre de guide", row))

    failed_after = [a for a in after.values() if a.status == "FAIL"]
    if failed_after:
        row = Row(["Controle", "Statut", "Detail"])
        for a in failed_after:
            row.add("`{}`".format(a.id), a.status, a.detail)
        tables.append(("Controles en echec restants (apres)", row))

    # Recapitulatif complet
    row = Row(["#", "Controle", "Avant", "Apres", "Evolution", "Detail (apres)"])
    recap_ids = sorted((c for c in after if not c.startswith("__")), key=sort_key)
    for index, cid in enumerate(recap_ids, start=1):
        a = after[cid]
        b_status = before[cid].status if cid in before else "-"
        if b_status == a.status:
            evolution = "inchange"
        elif b_status == "PASS" and a.status != "PASS":
            evolution = "regression"
        elif b_status != "PASS" and a.status == "PASS":
            evolution = "amelioration"
        else:
            evolution = "modifie"
        row.add(index, "`{}`".format(cid), b_status, a.status, evolution, a.detail)
    tables.append(("Recapitulatif complet - tous les controles", row))

    # Tests fonctionnels
    if tests_before and tests_after:
        row = Row(["#", "Suite", "Test", "Statut avant", "Statut apres", "Evolution", "Detail (apres)"])
        for index, tid in enumerate(sorted(tests_after, key=sort_key), start=1):
            a = tests_after[tid]
            b_status = tests_before[tid].status if tid in tests_before else "-"
            if b_status == a.status:
                evolution = "inchange"
            elif b_status == "PASS" and a.status != "PASS":
                evolution = "REGRESSION"
            elif b_status != "PASS" and a.status == "PASS":
                evolution = "amelioration"
            else:
                evolution = "modifie"
            suite = "OS" if tid.startswith("OS.") else "Proxmox"
            row.add(index, suite, "`{}`".format(tid), b_status, a.status, evolution, a.detail)
        tables.append(("Tests fonctionnels - avant / apres durcissement", row))

        # Synthese par suite, avec controle de somme
        row = Row(
            [
                "Suite",
                "Tests",
                "PASS av.",
                "PASS ap.",
                "FAIL av.",
                "FAIL ap.",
                "WARN av.",
                "WARN ap.",
                "NA av.",
                "NA ap.",
                "Regression",
                "Controle somme",
            ]
        )
        for suite in ("Proxmox", "OS"):
            ids = _suite_ids(tests_after, suite)
            if not ids:
                continue
            stats = {}
            for st in ("PASS", "FAIL", "WARN", "NA"):
                stats["b_" + st] = sum(
                    1 for i in ids if i in tests_before and tests_before[i].status == st
                )
                stats["a_" + st] = sum(1 for i in ids if tests_after[i].status == st)
            reg = sum(
                1
                for i in ids
                if i in tests_before
                and tests_before[i].status == "PASS"
                and tests_after[i].status != "PASS"
            )
            total = len(ids)
            somme = sum(stats["a_" + st] for st in ("PASS", "FAIL", "WARN", "NA"))
            control = (
                "OK ({}/{})".format(somme, total)
                if somme == total
                else "ECART ({}/{})".format(somme, total)
            )
            row.add(
                suite,
                total,
                stats["b_PASS"],
                stats["a_PASS"],
                stats["b_FAIL"],
                stats["a_FAIL"],
                stats["b_WARN"],
                stats["a_WARN"],
                stats["b_NA"],
                stats["a_NA"],
                reg,
                control,
            )
        # Ligne de controle globale
        total_a = len(tests_after)
        somme_a = sum(1 for c in tests_after.values() if c.status in ("PASS", "FAIL", "WARN", "NA"))
        total_b = len(tests_before)
        somme_b = sum(1 for c in tests_before.values() if c.status in ("PASS", "FAIL", "WARN", "NA"))
        control_global = (
            "OK" if (somme_b == total_b and somme_a == total_a) else "ECART"
        )
        row.add(
            "TOTAL",
            total_a,
            _count(tests_before.values(), "PASS"),
            _count(tests_after.values(), "PASS"),
            _count(tests_before.values(), "FAIL"),
            _count(tests_after.values(), "FAIL"),
            _count(tests_before.values(), "WARN"),
            _count(tests_after.values(), "WARN"),
            _count(tests_before.values(), "NA"),
            _count(tests_after.values(), "NA"),
            func_regression,
            "av.={}/{} ap.={}/{} {}".format(somme_b, total_b, somme_a, total_a, control_global),
        )
        tables.append(("Tests fonctionnels - synthese par suite (non-regression)", row))

        # Tests non conformes documentes
        row = Row(["#", "Suite", "Test", "Statut avant", "Statut apres", "Detail (apres)"])
        index = 0
        for tid in sorted(tests_after, key=sort_key):
            a = tests_after[tid]
            b_status = tests_before[tid].status if tid in tests_before else "-"
            if b_status == "PASS" and a.status == "PASS":
                continue
            index += 1
            suite = "OS" if tid.startswith("OS.") else "Proxmox"
            row.add(index, suite, "`{}`".format(tid), b_status, a.status, a.detail)
        if index:
            tables.append(
                ("Tests fonctionnels - tests non conformes (WARN / NA) documentes", row)
            )

    return {
        "title": title,
        "before_dir": before_dir,
        "after_dir": after_dir,
        "stamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "before": before,
        "after": after,
        "tests_before": tests_before,
        "tests_after": tests_after,
        "regressions": regressions,
        "improvements": improvements,
        "unchanged": unchanged,
        "lost": lost,
        "new": new,
        "pb": pb,
        "fb": fb,
        "pa": pa,
        "fa": fa,
        "delta": delta,
        "func_regression": func_regression,
        "func_improvement": func_improvement,
        "tables": tables,
    }


# ------------------------------------------------------------------ rendu MD
def render_markdown(model: dict) -> str:
    """Produit le rapport Markdown."""
    out: list[str] = []
    out.append("# {}".format(model["title"]))
    out.append("")
    out.append("- **Avant** : `{}`".format(relative(model["before_dir"])))
    out.append("- **Apres** : `{}`".format(relative(model["after_dir"])))
    out.append("- **Genere le** : {}".format(model["stamp"]))
    out.append("")
    out.append("## Synthese")
    out.append("")
    out.append("| Indicateur | Avant | Apres | Delta |")
    out.append("|---|---:|---:|---:|")
    delta = model["delta"]
    out.append(
        "| Controles conformes (PASS) | {} | {} | {}{} |".format(
            model["pb"], model["pa"], "+" if delta >= 0 else "", delta
        )
    )
    out.append(
        "| Controles en echec (FAIL) | {} | {} | {}({}) |".format(
            model["fb"], model["fa"], "+" if -delta >= 0 else "", -delta
        )
    )
    out.append("| Regressions | - | {} | |".format(len(model["regressions"])))
    out.append("| Ameliorations | - | {} | |".format(len(model["improvements"])))
    tb, ta = model["tests_before"], model["tests_after"]
    if tb and ta:
        fbp = _count(tb.values(), "PASS")
        fap = _count(ta.values(), "PASS")
        out.append(
            "| Tests fonctionnels PASS | {} | {} | {}{} |".format(
                fbp, fap, "+" if fap >= fbp else "", fap - fbp
            )
        )
        out.append("| Regressions fonctionnelles | - | {} | |".format(model["func_regression"]))
        for suite in ("Proxmox", "OS"):
            ids = _suite_ids(ta, suite)
            if not ids:
                continue
            pb2 = sum(1 for i in ids if i in tb and tb[i].status == "PASS")
            pa2 = sum(1 for i in ids if ta[i].status == "PASS")
            fa2 = sum(1 for i in ids if ta[i].status == "FAIL")
            out.append(
                "| Tests fonctionnels {} (PASS / total) | {} / {} | {} / {} | {}{} |".format(
                    suite, pb2, len(ids), pa2, len(ids),
                    "+" if pa2 >= pb2 else "", pa2 - pb2,
                )
            )
            out.append("| Tests fonctionnels {} (FAIL) | - | {} | |".format(suite, fa2))
    out.append("")
    for name, row in model["tables"]:
        out.append("## {}".format(name))
        out.append("")
        out.append("| " + " | ".join(row.header) + " |")
        out.append("|" + "|".join("---" for _ in row.header) + "|")
        for values in row.rows:
            out.append("| " + " | ".join(values) + " |")
        out.append("")
    return "\n".join(out)


# ----------------------------------------------------------------- rendu HTML
_CSS = """
:root { --pass:#0a7d33; --fail:#c62828; --na:#6b7280; --info:#2563eb; --ink:#111827; }
* { box-sizing:border-box; }
body { font-family:"Segoe UI",Calibri,Arial,Helvetica,sans-serif; color:var(--ink);
       margin:0; padding:0 0 24px; font-size:11pt; line-height:1.5; }
header { border-bottom:3px solid #111827; padding:18px 28px 12px; }
header h1 { font-size:19pt; margin:0 0 4px; }
header .meta { color:#4b5563; font-size:9.5pt; }
main { padding:0 28px; }
.kpi { display:flex; gap:12px; margin:18px 0 6px; flex-wrap:wrap; }
.kpi div { border:1px solid #d1d5db; border-radius:6px; padding:10px 14px;
           min-width:110px; background:#fafafa; }
.kpi .v { font-size:16pt; font-weight:600; }
.kpi .l { font-size:8.5pt; color:#4b5563; text-transform:uppercase; letter-spacing:.4px; }
.good { color:var(--pass); } .bad { color:var(--fail); }
h3 { font-size:12pt; border-bottom:1px solid #e5e7eb; padding-bottom:4px; margin:26px 0 10px; }
table { border-collapse:collapse; width:100%; margin-bottom:8px; font-size:9.5pt; }
th { background:#111827; color:#fff; text-align:left; padding:6px 8px; font-weight:600; }
td { border-bottom:1px solid #e5e7eb; padding:5px 8px; vertical-align:top; }
tr:nth-child(even) td { background:#f9fafb; }
td.pass, td.fail, td.na, td.info { text-align:center; font-weight:600; width:74px; }
td.pass { color:var(--pass); } td.fail { color:var(--fail); }
td.na { color:var(--na); } td.info { color:var(--info); }
td.amelioration { color:var(--pass); font-weight:600; }
td.regression { color:var(--fail); font-weight:600; }
td.inchange { color:var(--na); } td.modifie { color:var(--info); }
code { font-family:Consolas,"Courier New",monospace; font-size:9pt;
       background:#f3f4f6; padding:1px 4px; border-radius:3px; }
footer { padding:14px 28px 0; color:#6b7280; font-size:8.5pt;
         border-top:1px solid #e5e7eb; margin-top:24px; }
@page { size:A4; margin:14mm 12mm 14mm 12mm; }
""".strip()

_BADGE = {"PASS": "pass", "FAIL": "fail", "NA": "na"}
_EVOLUTIONS = {"amelioration", "regression", "inchange", "modifie"}


def _esc(value) -> str:
    return html_mod.escape(str(value), quote=False)


def _html_table(name: str, row: Row) -> str:
    if not row.rows:
        return ""
    parts = ["<h3>{}</h3>".format(_esc(name)), "<table>", "<thead><tr>"]
    for header in row.header:
        parts.append("<th>{}</th>".format(_esc(header)))
    parts.append("</tr></thead><tbody>")
    for values in row.rows:
        parts.append("<tr>")
        for col, value in enumerate(values):
            cls = ""
            if col in (2, 3) and value:
                cls = ' class="{}"'.format(_BADGE.get(value, "info"))
            if col == 4 and value and str(value).lower() in _EVOLUTIONS:
                cls = ' class="{}"'.format(str(value).lower())
            parts.append("<td{}>{}</td>".format(cls, _esc(value)))
        parts.append("</tr>")
    parts.append("</tbody></table>")
    return "".join(parts)


def render_html(model: dict) -> str:
    """Produit le rapport HTML."""
    kpis = [
        '<div><div class="v">{}</div><div class="l">PASS avant</div></div>'.format(model["pb"]),
        '<div><div class="v">{}</div><div class="l">PASS apres</div></div>'.format(model["pa"]),
        '<div><div class="v {}">{}</div><div class="l">Delta conformes</div></div>'.format(
            "good" if model["delta"] >= 0 else "bad", model["delta"]
        ),
        '<div><div class="v">{}</div><div class="l">Regressions</div></div>'.format(
            len(model["regressions"])
        ),
        '<div><div class="v">{}</div><div class="l">Ameliorations</div></div>'.format(
            len(model["improvements"])
        ),
    ]
    tb, ta = model["tests_before"], model["tests_after"]
    if tb and ta:
        fbp = _count(tb.values(), "PASS")
        fap = _count(ta.values(), "PASS")
        fd = fap - fbp
        kpis.append(
            '<div><div class="v {}">{} &rarr; {}</div><div class="l">Tests fonctionnels PASS</div></div>'.format(
                "good" if fd >= 0 else "bad", fbp, fap
            )
        )
        kpis.append(
            '<div><div class="v {}">{}</div><div class="l">Regr. fonctionnelles</div></div>'.format(
                "bad" if model["func_regression"] else "good", model["func_regression"]
            )
        )
        for suite in ("Proxmox", "OS"):
            ids = _suite_ids(ta, suite)
            if not ids:
                continue
            pa2 = sum(1 for i in ids if ta[i].status == "PASS")
            fa2 = sum(1 for i in ids if ta[i].status == "FAIL")
            wa2 = sum(1 for i in ids if ta[i].status == "WARN")
            na2 = sum(1 for i in ids if ta[i].status == "NA")
            label = "Non-regression OS" if suite == "OS" else "Non-regression Proxmox"
            kpis.append(
                '<div><div class="v {}">{}/{}</div><div class="l">{}</div></div>'.format(
                    "good" if fa2 == 0 else "bad", pa2, len(ids), label
                )
            )
            kpis.append(
                '<div><div class="v">{} / {}</div><div class="l">WARN / NA {}</div></div>'.format(
                    wa2, na2, label
                )
            )

    sections = "".join(_html_table(name, row) for name, row in model["tables"])
    return """<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<title>{title}</title>
<style>{css}</style></head>
<body>
<header>
  <h1>{title}</h1>
  <div class="meta">
    Avant : <code>{before}</code> &nbsp;|&nbsp;
    Apres : <code>{after}</code> &nbsp;|&nbsp;
    Genere le {stamp}
  </div>
</header>
<main>
  <h3>Synthese</h3>
  <div class="kpi">{kpis}</div>
  {sections}
</main>
<footer>
  Genere par pve9-hardening-lab / scripts/pve.py report &mdash; collecteur lecture seule guest/audit-pve.sh.
  Controles codes PASS / FAIL / NA (non applicable dans ce lab) / INFO.
</footer>
</body></html>
""".format(
        title=_esc(model["title"]),
        css=_CSS,
        before=_esc(relative(model["before_dir"])),
        after=_esc(relative(model["after_dir"])),
        stamp=_esc(model["stamp"]),
        kpis="".join(kpis),
        sections=sections,
    )


# ------------------------------------------------------------------- ecriture
def write_report(
    before_dir: str | Path,
    after_dir: str | Path,
    report_path: str | Path | None = None,
    pdf_path: str | Path | None = None,
    title: str = "Comparatif de hardening - Proxmox VE 9",
    before_func: str | Path | None = None,
    after_func: str | Path | None = None,
    no_pdf: bool = False,
) -> tuple[Path, Path | None, Path | None]:
    """Ecrit le rapport Markdown, HTML et (optionnellement) PDF."""
    model = build_report(before_dir, after_dir, title, before_func, after_func)

    console.step("Comparatif de posture de securite")
    console.write("Avant : PASS={} FAIL={}".format(model["pb"], model["fb"]))
    console.write("Apres : PASS={} FAIL={}".format(model["pa"], model["fa"]))
    console.write("Delta : {:+d} controles conformes".format(model["delta"]))
    console.write("")
    console.write("Regressions  : {}".format(len(model["regressions"])))
    console.write("Ameliorations: {}".format(len(model["improvements"])))
    console.write("Inchanges    : {}".format(len(model["unchanged"])))
    console.write("Nouveaux     : {}".format(len(model["new"])))
    console.write("Perdus       : {}".format(len(model["lost"])))
    console.write("")

    if model["regressions"]:
        console.write("--- REGRESSIONS (a analyser) ---", "red")
        for b, a in model["regressions"]:
            console.write("  {}".format(a.id), "red")
            console.dim("      avant : {} - {}".format(b.status, b.detail))
            console.dim("      apres : {} - {}".format(a.status, a.detail))
        console.write("")

    if report_path is None:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        report_path = Path(after_dir).parent / "comparatif-{}.md".format(stamp)
    report_path = Path(report_path)
    if pdf_path is None:
        pdf_path = report_path.with_suffix(".pdf")
    pdf_path = Path(pdf_path)
    html_path = report_path.with_suffix(".html")

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(render_markdown(model), encoding="utf-8")
    console.ok("Rapport Markdown : {}".format(report_path))

    html_path.write_text(render_html(model), encoding="utf-8")
    console.ok("Rapport HTML     : {}".format(html_path))

    produced_pdf = None
    if not no_pdf:
        try:
            produced_pdf = render_html_to_pdf(html_path, pdf_path)
        except PdfError as exc:
            console.error("  PDF non produit : {}".format(exc))
    return report_path, html_path, produced_pdf
