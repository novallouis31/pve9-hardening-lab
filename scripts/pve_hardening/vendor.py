"""Telechargement et verification des artefacts de hardening (projets open source).

Chaque artefact est fige sur un commit SHA : le contenu ne peut pas changer
entre deux executions, ce qui rend les tests reproductibles.

Equivalent Python de ``scripts/fetch-vendor.ps1`` et
``scripts/verify-vendor.ps1``.
"""

from __future__ import annotations

import hashlib
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from .config import VENDOR_DIR
from .console import console


@dataclass(frozen=True)
class Artifact:
    """Un artefact de reference, fige sur un commit."""

    id: str
    repo: str
    sha: str
    path: str
    dest: str


#: Artefacts de reference (memes SHAs que la version PowerShell).
ARTIFACTS = (
    Artifact("homesec-pve9-guide", "HomeSecExplorer/Proxmox-Hardening-Guide",
             "d630ff29ca5f89db2a9b416e88634d385fa7f708",
             "docs/pve9-hardening-guide.md", "homesec/pve9-hardening-guide.md"),
    Artifact("homesec-readme", "HomeSecExplorer/Proxmox-Hardening-Guide",
             "d630ff29ca5f89db2a9b416e88634d385fa7f708",
             "README.md", "homesec/README.md"),
    Artifact("abua-script", "abualialfatih23/PVE-9-Hardening",
             "c9909d0422a77f89ea3d5ebc61ca4284bacd0b5a",
             "PVE9-Harden-FinalVersion-v1.sh",
             "abualialfatih23/PVE9-Harden-FinalVersion-v1.sh"),
    Artifact("abua-readme", "abualialfatih23/PVE-9-Hardening",
             "c9909d0422a77f89ea3d5ebc61ca4284bacd0b5a",
             "README.md", "abualialfatih23/README.md"),
    Artifact("mm-script", "MrMasterbay/proxmox-security-hardening",
             "44e0154bedfa5ecde2f557710c7108fc734c423e",
             "seuwurity.sh", "mrmasterbay/seuwurity.sh"),
    Artifact("mm-readme", "MrMasterbay/proxmox-security-hardening",
             "44e0154bedfa5ecde2f557710c7108fc734c423e",
             "README.md", "mrmasterbay/README.md"),
    Artifact("ssh-guide", "alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9",
             "c35a64617523299fa4e5396a72016973f6422510",
             "README.md", "ssh-guide/README.md"),
)

_RAW = "https://raw.githubusercontent.com/{repo}/{sha}/{path}"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(vendor_dir: Path | None = None, force: bool = False, timeout: int = 60) -> int:
    """Telecharge les artefacts et genere ``SHA256SUMS.txt``."""
    base = Path(vendor_dir) if vendor_dir else VENDOR_DIR
    base.mkdir(parents=True, exist_ok=True)

    lines = ["# SHA256SUMS - artefacts de hardening PVE 9 (verifie par verify_vendor)"]
    failures = 0

    for art in ARTIFACTS:
        dest = base / art.dest
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and not force:
            console.dim("[skip] {} deja present ({})".format(art.id, art.dest))
        else:
            url = _RAW.format(repo=art.repo, sha=art.sha, path=art.path)
            console.write("[get ] {} <- {}@{}".format(art.id, art.repo, art.sha[:7]), "cyan")
            try:
                request = urllib.request.Request(
                    url, headers={"User-Agent": "pve9-hardening-lab"}
                )
                with urllib.request.urlopen(request, timeout=timeout) as response:
                    dest.write_bytes(response.read())
            except (urllib.error.URLError, OSError) as exc:
                console.error("[FAIL] {} : {}".format(art.id, exc))
                failures += 1
                continue
        lines.append("{}  {}".format(_sha256(dest), art.dest.replace("\\", "/")))

    sum_file = base / "SHA256SUMS.txt"
    sum_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    console.write("")
    console.write("Vendor dir : {}".format(base))
    console.write("Checksums  : {}".format(sum_file))
    console.write("Artefacts  : {}/{}".format(len(ARTIFACTS) - failures, len(ARTIFACTS)))
    return 1 if failures else 0


def verify(vendor_dir: Path | None = None) -> int:
    """Verifie l'integrite des artefacts (SHA256SUMS.txt)."""
    base = Path(vendor_dir) if vendor_dir else VENDOR_DIR
    sum_file = base / "SHA256SUMS.txt"
    if not sum_file.exists():
        raise FileNotFoundError(
            "SHA256SUMS.txt absent. Lancez d'abord : pve.py fetch-vendor"
        )

    ok = ko = 0
    for line in sum_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) != 2 or len(parts[0]) != 64:
            continue
        expected, rel = parts[0].lower(), parts[1].strip()
        # rel utilise '/' comme separateur (format sha256sum) : on le convertit
        # en composants natifs pour rester multiplateforme.
        path = base.joinpath(*Path(rel).parts)
        if not path.exists():
            console.error("[MANQUANT] {}".format(rel))
            ko += 1
            continue
        actual = _sha256(path)
        if actual == expected:
            console.write("[OK]      {}".format(rel), "green")
            ok += 1
        else:
            console.error("[ALTERE]  {}".format(rel))
            console.error("          attendu {}".format(expected))
            console.error("          obtenu  {}".format(actual))
            ko += 1

    console.write("")
    console.write("Artefacts conformes : {}/{}".format(ok, ok + ko))
    return 1 if ko else 0
