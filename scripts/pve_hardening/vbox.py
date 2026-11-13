"""Pilotage de VirtualBox (equivalent de vm-snapshot.ps1 / vm-image.ps1).

``VBoxManage`` existe sur Linux (paquet ``virtualbox``) comme sur Windows :
le code est donc directement portable. Seule la recherche du binaire change.

Rappel important documente dans le lab : **un clone de disque VDI porte un
UUID different**, ce qui casse le demarrage de Proxmox (GRUB ne trouve plus
la racine). Seul le **snapshot** preserve l'UUID du disque.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from .console import console


class VBoxError(RuntimeError):
    """Erreur de pilotage VirtualBox."""


def find_vboxmanage() -> str:
    """Retourne le chemin de ``VBoxManage``."""
    override = os.environ.get("VBOXMANAGE")
    if override and Path(override).exists():
        return override
    if os.name == "nt":
        candidates = (
            r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
            r"C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe",
        )
        for candidate in candidates:
            if Path(candidate).exists():
                return candidate
        found = shutil.which("VBoxManage")
        if found:
            return found
        raise VBoxError("VBoxManage.exe introuvable")
    found = shutil.which("VBoxManage")
    if found:
        return found
    raise VBoxError(
        "VBoxManage introuvable. Installer VirtualBox :\n"
        "  Debian/Ubuntu : sudo apt install virtualbox\n"
        "  RHEL          : sudo dnf install virtualbox\n"
        "  SLES          : sudo zypper install virtualbox"
    )


def vbox(*args: str, check: bool = True) -> str:
    """Execute ``VBoxManage`` et retourne sa sortie."""
    exe = find_vboxmanage()
    cmd = [exe] + [str(a) for a in args]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    out = proc.stdout.decode("utf-8", "replace")
    if check and proc.returncode != 0:
        raise VBoxError("VBoxManage {} a echoue :\n{}".format(" ".join(args), out.strip()))
    return out


def vm_running(vm_name: str) -> bool:
    """Vrai si la VM tourne."""
    out = vbox("list", "runningvms", check=False)
    return '"{}"'.format(vm_name) in out


def snapshot_create(vm_name: str, name: str, description: str = "PVE9 hardening lab") -> None:
    """Cree un snapshot."""
    if vm_running(vm_name):
        console.warn(
            "La VM est en marche : le snapshot sera 'en ligne' (memoire capturee)."
        )
        console.warn("Eteignez la VM pour un snapshot disque complet et fiable.")
    vbox("snapshot", vm_name, "take", name, "--description", description)
    console.ok("Snapshot '{}' cree.".format(name))
    console.write(vbox("snapshot", vm_name, "list"))


def snapshot_list(vm_name: str) -> str:
    """Liste les snapshots."""
    out = vbox("snapshot", vm_name, "list")
    console.write(out)
    return out


def snapshot_restore(vm_name: str, name: str) -> None:
    """Restaure un snapshot (la VM doit etre arretee)."""
    listing = vbox("snapshot", vm_name, "list")
    found = [ln for ln in listing.splitlines() if name in ln and "Name:" in ln]
    if not found:
        raise VBoxError("Snapshot '{}' introuvable.\n{}".format(name, listing))
    console.warn("Restauration du snapshot '{}'...".format(name))
    vbox("snapshot", vm_name, "restore", name)
    console.ok("Restauration effectuee. La VM est revenue a l'etat du snapshot.")


def snapshot_delete(vm_name: str, name: str) -> None:
    """Supprime un snapshot (fusionne le differentiel dans la base)."""
    vbox("snapshot", vm_name, "delete", name)
    console.ok("Snapshot '{}' supprime.".format(name))


def image_save(vm_name: str, disk: str | Path, image: str | Path) -> Path:
    """Sauvegarde l'image de reference par clonage complet du disque."""
    disk_path = Path(disk)
    image_path = Path(image)
    if image_path.exists():
        image_path.unlink()
    vbox("clonemedium", "disk", "--format", "VDI", str(disk_path), str(image_path))
    console.ok(
        "Image de reference : {} ({:.0f} Mo)".format(
            image_path, image_path.stat().st_size / 1024 / 1024
        )
    )
    return image_path


def image_restore(vm_name: str, disk: str | Path, image: str | Path) -> Path:
    """Restaure l'image de reference par clonage complet."""
    image_path = Path(image)
    disk_path = Path(disk)
    vbox("storageattach", vm_name, "--storagectl=IDE", "--port=0", "--device=0",
         "--type=hdd", "--medium=none")
    if disk_path.exists():
        for _ in range(10):
            try:
                disk_path.unlink()
                break
            except OSError:
                pass
    vbox("clonemedium", "disk", "--format", "VDI", str(image_path), str(disk_path))
    vbox("storageattach", vm_name, "--storagectl=IDE", "--port=0", "--device=0",
         "--type=hdd", "--medium={}".format(disk_path))
    console.ok("Image restauree : {}".format(disk_path))
    return disk_path
