"""Publication du depot sur GitHub (PAT ou CLI GitKraken).

Deux modes :

* ``--token`` : le Personal Access Token est fourni explicitement. Il est
  aussi enregistre dans le magasin chiffre de la CLI GitKraken
  (``gk provider add github -t ...``) pour que ``gk`` fonctionne ensuite.
* ``--use-gitkraken`` : le jeton est deja enregistre dans GitKraken ; le
  script guide l'utilisateur pour l'ajouter.

Dans les deux cas, le jeton n'est **jamais** ecrit dans ``.git/config`` : le
remote ``origin`` reste une URL HTTPS propre.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

from .config import LAB_ROOT
from .console import console

_API = "https://api.github.com"

#: Motifs de detection d'un secret dans un fichier suivi.
_SECRET_PATTERNS = (
    re.compile(r"BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"glpat-[A-Za-z0-9_-]{20,}"),
)


class PublishError(RuntimeError):
    """Erreur de publication."""


def _git(*args: str, cwd: Path) -> str:
    proc = subprocess.run(
        ["git", "-C", str(cwd)] + list(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return proc.stdout.decode("utf-8", "replace")


def _tracked_files(repo: Path) -> list[str]:
    return [ln for ln in _git("ls-files", cwd=repo).splitlines() if ln.strip()]


def _scan_secrets(repo: Path) -> list[str]:
    """Retourne la liste des fichiers-suivis contenant un secret."""
    alerts: list[str] = []
    for rel in _tracked_files(repo):
        path = repo.joinpath(*Path(rel).parts)
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for pattern in _SECRET_PATTERNS:
            if pattern.search(content):
                alerts.append(rel)
                break
    return alerts


def _api(path: str, token: str, method: str = "GET", body: dict | None = None):
    url = _API + path
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "Authorization": "Bearer {}".format(token),
        "User-Agent": "pve9-hardening-lab",
        "Accept": "application/vnd.github+json",
    }
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read()
        return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise PublishError("API GitHub {} : {}".format(exc.code, detail[:400])) from exc
    except urllib.error.URLError as exc:
        raise PublishError("API GitHub injoignable : {}".format(exc)) from exc


def _gk_path() -> Path | None:
    import os

    candidate = Path(os.environ.get("LOCALAPPDATA", "")) / "GitKrakenCLI" / "gk.exe"
    if candidate.exists():
        return candidate
    found = shutil.which("gk")
    return Path(found) if found else None


def _register_in_gitkraken(token: str) -> None:
    """Enregistre le PAT dans le magasin chiffre de la CLI GitKraken."""
    gk = _gk_path()
    if gk is None:
        console.dim("  CLI GitKraken introuvable : PAT non enregistre dans gk")
        return
    proc = subprocess.run(
        [str(gk), "provider", "add", "github", "-t", token],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    for line in proc.stdout.decode("utf-8", "replace").splitlines()[-3:]:
        if line.strip():
            console.dim("  gk : {}".format(line.strip()))


def publish(
    repo_path: Path,
    repo_name: str,
    token: str = "",
    use_gitkraken: bool = False,
    owner: str = "",
    visibility: str = "public",
    push_tags: bool = False,
) -> int:
    """Publie le depot local sur GitHub."""
    repo_path = Path(repo_path).resolve()
    console.step("1. controle du depot a publier")
    branch = _git("rev-parse", "--abbrev-ref", "HEAD", cwd=repo_path).strip()
    files = _tracked_files(repo_path)
    console.write("  depot local : {}".format(repo_path))
    console.write("  branche     : {}".format(branch))
    console.write("  {} fichiers suivis".format(len(files)))
    dirty = [ln for ln in _git("status", "--short", cwd=repo_path).splitlines() if ln.strip()]
    if dirty:
        console.warn("  modifications non commitees :")
        for line in dirty[:10]:
            console.write("    {}".format(line), "yellow")
    else:
        console.write("  arbre propre", "green")

    alerts = _scan_secrets(repo_path)
    if alerts:
        for rel in alerts:
            console.error("  FUITE : secret detecte dans {}".format(rel))
        console.error("Publication interrompue : secret detecte")
        return 1
    console.write("  aucun secret detecte", "green")

    console.step("2. authentification GitHub")
    if not token:
        gk = _gk_path()
        if gk and use_gitkraken:
            proc = subprocess.run(
                [str(gk), "provider", "list"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            for line in proc.stdout.decode("utf-8", "replace").splitlines():
                if "github" in line.lower():
                    console.write("  gk : {}".format(line.strip()))
        console.write("  Pour publier : gk provider add github -t ghp_...")
        console.dim("  (le jeton est stocke chiffre par GitKraken, jamais dans le depot)")
        return 2

    _register_in_gitkraken(token)

    console.step("3. depot GitHub")
    if not owner:
        me = _api("/user", token)
        owner = me.get("login", "")
        console.write("  compte : {}".format(owner))
    remote = "https://github.com/{}/{}.git".format(owner, repo_name)
    console.write("  cible : {}".format(remote))

    exists = True
    try:
        _api("/repos/{}/{}".format(owner, repo_name), token)
    except PublishError:
        exists = False
    if not exists:
        try:
            _api(
                "/user/repos",
                token,
                method="POST",
                body={
                    "name": repo_name,
                    "description": "Lab de hardening Proxmox VE 9 : CIS Debian 13 / "
                    "ANSSI BP-028 / Ceph, 160 controles, 72 tests de non-regression, "
                    "rapports PDF",
                    "private": visibility == "private",
                    "auto_init": False,
                },
            )
            console.write("  depot cree ({})".format(visibility), "green")
        except PublishError as exc:
            console.error("  ECHEC creation : {}".format(exc))
            return 1
    else:
        console.dim("  depot deja existant")

    console.step("4. remote")
    _git("remote", "remove", "origin", cwd=repo_path)
    _git("remote", "add", "origin", remote, cwd=repo_path)
    console.write("  origin -> {}".format(remote), "green")

    console.step("5. push")
    push_url = "https://{}:{}@github.com/{}/{}.git".format(
        owner, token, owner, repo_name
    )
    args = ["push", "-u", push_url, branch]
    if push_tags:
        args.append("--tags")
    out = _git(*args, cwd=repo_path)
    for line in out.splitlines()[-10:]:
        console.dim("  {}".format(line))
    _git("remote", "set-url", "origin", remote, cwd=repo_path)

    if "rejected" in out or "error" in out.lower():
        console.error("  ECHEC du push")
        console.warn("  Verifiez que le PAT a le perimetre 'repo' et n'est pas expire.")
        return 1

    console.write("")
    console.write("=== PUBLICATION REUSSIE ===", "green")
    console.write("  https://github.com/{}/{}".format(owner, repo_name), "green")
    console.write("")
    console.dim("  Dans GitKraken : File > Open > {}".format(repo_path))
    console.dim("  Puis : bouton Push (branche {})".format(branch))
    return 0
