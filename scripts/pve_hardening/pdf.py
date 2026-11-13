"""Rendu PDF d'un fichier HTML via un moteur Chromium headless.

Fonctionne avec Chrome, Chromium, Edge ou Brave, sur Windows comme sur
Linux. L'ordre de recherche est le suivant :

1. le chemin fourni explicitement ;
2. la variable d'environnement ``CHROME_PATH`` (ou ``BROWSER_PATH``) ;
3. les binaires connus du systeme.

Deux contournements indispensables, appliques aussi sous Windows :

* **profil isole** : un repertoire temporaire dedie evite tout conflit
  avec un navigateur deja ouvert ;
* **sortie temporaire sans espace ni accent** : Chromium headless echoue si
  le chemin de sortie contient des espaces ou des caracteres accentues.
  On imprime donc dans un fichier temporaire, puis on deplace le resultat.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

from .console import console

#: Candidats installes sur Windows.
_WINDOWS_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
)

#: Candidats trouves dans le PATH sur Linux / macOS.
_UNIX_CANDIDATES = (
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "microsoft-edge",
    "brave-browser",
)


class PdfError(RuntimeError):
    """Erreur de rendu PDF."""


def find_browser(preferred: str | None = None) -> str:
    """Retourne le chemin du premier moteur Chromium trouve."""
    candidates: list[str] = []
    if preferred:
        candidates.append(preferred)
    for var in ("CHROME_PATH", "BROWSER_PATH"):
        value = os.environ.get(var)
        if value:
            candidates.append(value)
    if os.name == "nt":
        candidates.extend(_WINDOWS_CANDIDATES)
    else:
        candidates.extend(_UNIX_CANDIDATES)

    for candidate in candidates:
        if not candidate:
            continue
        if os.path.isabs(candidate):
            if os.path.exists(candidate):
                return candidate
        else:
            found = shutil.which(candidate)
            if found:
                return found

    raise PdfError(
        "moteur Chromium introuvable pour l'impression PDF.\n"
        "  Installer l'un de : google-chrome, chromium, chromium-browser, microsoft-edge\n"
        "  ou definir CHROME_PATH=/chemin/vers/le/binaire"
    )


def render_html_to_pdf(html: str | Path, pdf: str | Path, browser: str | None = None) -> Path:
    """Convertit ``html`` en ``pdf`` et retourne le chemin du PDF produit."""
    html_path = Path(html).resolve()
    pdf_path = Path(pdf).resolve()

    if not html_path.exists():
        raise PdfError("HTML introuvable : {}".format(html_path))

    engine = find_browser(browser)
    pdf_path.parent.mkdir(parents=True, exist_ok=True)

    # URI file:// : percent-encoding correct des espaces et des accents.
    src_uri = html_path.as_uri()

    tmp_dir = Path(tempfile.gettempdir())
    profile_dir = tmp_dir / ("pve9-pdf-" + uuid.uuid4().hex)
    profile_dir.mkdir(parents=True, exist_ok=True)
    tmp_pdf = tmp_dir / ("pve9-out-" + uuid.uuid4().hex + ".pdf")

    args = [
        engine,
        "--headless",
        "--disable-gpu",
        "--disable-extensions",
        "--no-first-run",
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--no-pdf-header-footer",
        "--user-data-dir={}".format(profile_dir),
        "--print-to-pdf={}".format(tmp_pdf),
        src_uri,
    ]

    console.dim("  moteur    : {}".format(engine))
    console.dim("  source    : {}".format(src_uri))

    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
            check=False,
        )
        if proc.returncode != 0:
            raise PdfError(
                "Chromium headless a echoue (code {}) : {}".format(
                    proc.returncode,
                    proc.stderr.decode("utf-8", "replace").strip()[-400:],
                )
            )
        if not tmp_pdf.exists():
            raise PdfError("le PDF n'a pas ete produit : {}".format(tmp_pdf))
        shutil.move(str(tmp_pdf), str(pdf_path))
    finally:
        shutil.rmtree(profile_dir, ignore_errors=True)
        if tmp_pdf.exists():
            tmp_pdf.unlink(missing_ok=True)

    size_kb = pdf_path.stat().st_size / 1024
    console.ok("  pdf       : {} ({:.1f} ko)".format(pdf_path, size_kb))
    return pdf_path
