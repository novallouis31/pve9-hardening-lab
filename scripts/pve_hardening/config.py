"""Configuration et decouverte des chemins du lab.

Le lab est utilise comme un paquet Python : les chemins sont deduits de la
position du fichier, ce qui rend l'outil utilisable depuis n'importe quel
repertoire et sans variable d'environnement a configurer.
"""

from __future__ import annotations

import os
from pathlib import Path

#: Racine du depot (= dossier parent de ``scripts/``).
LAB_ROOT = Path(__file__).resolve().parent.parent.parent

#: Repertoire des scripts de l'hote.
SCRIPTS_DIR = LAB_ROOT / "scripts"

#: Repertoire des scripts deployes sur le noeud Proxmox.
GUEST_DIR = LAB_ROOT / "guest"

#: Repertoire des artefacts produits par les cycles (baseline, after, rapports).
ARTIFACTS_DIR = LAB_ROOT / "artifacts"

#: Repertoire des rapports PDF/MD livres.
REPORTS_DIR = LAB_ROOT / "reports"

#: Repertoire des artefacts telecharges (projets open source de reference).
VENDOR_DIR = LAB_ROOT / "vendor"

#: Cle privee du lab (jamais versionnee).
DEFAULT_KEY = LAB_ROOT / ".keys" / "id_ed25519"

#: Valeurs par defaut de l'acces SSH au noeud.
DEFAULT_SSH_HOST = "127.0.0.1"
DEFAULT_SSH_PORT = 2222
DEFAULT_SSH_USER = "root"
DEFAULT_SSH_PASSWORD = "19581958"

#: Timeout d'execution SSH (secondes). Les installations apt via SSH peuvent
#: depasser plusieurs minutes.
DEFAULT_SSH_TIMEOUT = 3600


def env_int(name: str, default: int) -> int:
    """Lit un entier depuis l'environnement, avec repli sur ``default``."""
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def ensure_dir(path: Path) -> Path:
    """Cree le repertoire (et ses parents) et le retourne."""
    path.mkdir(parents=True, exist_ok=True)
    return path


def relative(path: Path | str) -> str:
    """Chemin relatif au lab quand c'est possible (lisibilite des rapports)."""
    p = Path(path)
    try:
        return str(p.resolve().relative_to(LAB_ROOT))
    except ValueError:
        return str(p)
