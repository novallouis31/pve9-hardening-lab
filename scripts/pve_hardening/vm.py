"""Preparation de la VM VirtualBox de laboratoire (equivalent de prepare-vm.ps1).

Configure une VM pour booting sur l'ISO d'installation automatique de Proxmox VE 9 :
CPU, memoire, firmware, NAT, port serie de secours, ISO.

Fonctionne sous Linux (VirtualBox y fournit le meme ``VBoxManage``).
"""

from __future__ import annotations

from pathlib import Path

from .console import console
from .vbox import VBoxError, vbox, vm_running


def vm_exists(vm_name: str) -> bool:
    """Vrai si la VM est enregistree."""
    return '"{}"'.format(vm_name) in vbox("list", "vms", check=False)


def vm_dir(vm_name: str) -> Path:
    """Repertoire de la VM (le plus souvent ``~/VirtualBox VMs/<nom>``)."""
    import os

    home = Path.home()
    return home / "VirtualBox VMs" / vm_name


def _nat_rules(vm_name: str) -> list[tuple[str, int]]:
    """Retourne les regles NAT de la VM : (nom, port hote)."""
    import re

    rules: list[tuple[str, int]] = []
    out = vbox("showvminfo", vm_name, check=False)
    for line in out.splitlines():
        match = re.search(r"host port = (\d+)", line)
        if not match:
            continue
        name_match = re.search(r"name = ([^,]+)", line)
        name = name_match.group(1).strip() if name_match else ""
        rules.append((name, int(match.group(1))))
    return rules


def _delete_nat_rules_for_port(vm_name: str, port: int) -> None:
    """Supprime toutes les regles NAT qui ecoutent sur le port donne.

    Les regles sont nommees differemment selon la VM ("pve-ssh", "pve2-ssh",
    "pve3-ssh"...) : filtrer sur le nom serait fragile, on filtre donc sur le
    port, qui doit etre libre pour la nouvelle regle.
    """
    for name, host_port in _nat_rules(vm_name):
        if host_port != port:
            continue
        if name:
            vbox("modifyvm", vm_name, "--nat-pf1", "delete", name, check=False)
            console.dim("  [ok] regle NAT '{}' (port {}) supprimee".format(name, port))


def prepare_vm(
    vm_name: str = "proxmox",
    memory_mb: int = 8192,
    cpu_count: int = 4,
    firmware: str = "bios",
    ssh_host_port: int = 2222,
    web_host_port: int = 8006,
    iso_path: str = "",
    no_iso: bool = False,
) -> int:
    """Configure la VM de laboratoire."""
    console.step("Configuration de la VM '{}'".format(vm_name))

    if not vm_exists(vm_name):
        raise VBoxError(
            "VM introuvable : '{}'. VMs disponibles :\n{}".format(
                vm_name, vbox("list", "vms", check=False)
            )
        )
    if vm_running(vm_name):
        raise VBoxError(
            "La VM '{}' est en cours d'execution. Eteignez-la puis relancez.".format(vm_name)
        )

    console.write("  VirtualBox : {}".format(vbox("--version", check=False).strip()))

    directory = vm_dir(vm_name)
    console_log = directory / "console.log"

    # ------------------------------------------------------------ CPU / memoire
    vbox("modifyvm", vm_name, "--os-type=Debian_64")
    vbox("modifyvm", vm_name, "--memory={}".format(memory_mb))
    vbox("modifyvm", vm_name, "--cpus={}".format(cpu_count))
    console.ok(
        "  [ok] os-type=Debian_64 memory={}Mo cpus={}".format(memory_mb, cpu_count)
    )

    # Les drapeaux 64 bits sont implicites avec ostype=Debian_64, on les force.
    for flag in ("--x86-pae=on", "--x86-long-mode=on", "--hwvirtex=on", "--nested-paging=on"):
        vbox("modifyvm", vm_name, flag)
    console.ok("  [ok] pae/long-mode/hwvirtex/nested-paging = on")

    # ------------------------------------------------------------ stabilite VM
    # Un noeud PVE est une machine headless : l'audio emule (AC'97) provoque des
    # blocages du thread audio sur hote Windows, qui se traduisent par une
    # derive d'horloge de l'invite puis un reset ACPI declenche par le watchdog
    # VirtualBox ("Guest seems to be unresponsive"). On le desactive, ainsi que
    # l'affichage distant, et on force l'horloge paravirtualisee KVM qui garde
    # l'heure stable pendant les phases longues (apt, update-initramfs).
    for flag in ("--audio=none", "--vrde=off", "--paravirt-provider=kvm"):
        vbox("modifyvm", vm_name, flag)
    console.ok("  [ok] audio=none vrde=off paravirt=kvm (stabilite horloge)")

    # --------------------------------------------------------------- firmware
    vbox("modifyvm", vm_name, "--firmware={}".format(firmware))
    vbox("modifyvm", vm_name, "--boot1=dvd")
    vbox("modifyvm", vm_name, "--boot2=disk")
    for flag in ("--acpi=on", "--ioapic=on", "--rtc-use-utc=on"):
        vbox("modifyvm", vm_name, flag)
    console.ok("  [ok] firmware={} boot=dvd,disk acpi/ioapic/rtc-utc=on".format(firmware))

    # ------------------------------------------------------------------ reseau
    vbox("modifyvm", vm_name, "--nic1=nat")
    vbox("modifyvm", vm_name, "--nic-type1=virtio")
    vbox("modifyvm", vm_name, "--cable-connected1=on")
    # On recree proprement les regles de redirection NAT (la forme
    # "--nat-pf1=delete=nom" est refusee par le parseur de VBox 7.2 : les
    # arguments doivent etre separes).
    # Attention : les regles existantes sont nommees differemment selon la VM
    # ("pve-ssh", "pve2-ssh", "pve3-ssh"...). On supprime donc TOUTES les
    # regles qui ecoutent sur les ports vises, quelle que soit leur nom.
    for port in (web_host_port, ssh_host_port):
        _delete_nat_rules_for_port(vm_name, port)
    vbox("modifyvm", vm_name, "--nat-pf1=pve-web,tcp,127.0.0.1,{},,8006".format(web_host_port))
    vbox("modifyvm", vm_name, "--nat-pf1=pve-ssh,tcp,127.0.0.1,{},,22".format(ssh_host_port))
    console.ok(
        "  [ok] NAT : 127.0.0.1:{} -> 8006 (web) | 127.0.0.1:{} -> 22 (ssh)".format(
            web_host_port, ssh_host_port
        )
    )

    # ------------------------------------------------------- port serie (secours)
    # VBox 7.2 : plus d'argument IRQ, la base seule suffit (IRQ attribuee auto).
    vbox("modifyvm", vm_name, "--uart1=0x3F8")
    vbox("modifyvm", vm_name, "--uart-mode1", "file", str(console_log))
    vbox("modifyvm", vm_name, "--uart-type1=16550A")
    console.ok("  [ok] port serie ttyS0 -> {}".format(console_log))

    # --------------------------------------------------------------------- ISO
    # Le type d'attachement optique s'appelle 'dvddrive' ('dvd' est refuse).
    if no_iso:
        vbox(
            "storageattach", vm_name, "--storagectl=IDE", "--port=1", "--device=0",
            "--type=dvddrive", "--medium=emptydrive", check=False,
        )
        vbox("modifyvm", vm_name, "--boot1=disk")
        vbox("modifyvm", vm_name, "--boot2=dvd")
        console.ok("  [ok] ISO detachee (PVE installe) - la VM boote sur le disque")
    elif iso_path and Path(iso_path).exists():
        vbox(
            "storageattach", vm_name, "--storagectl=IDE", "--port=1", "--device=0",
            "--type=dvddrive", "--medium={}".format(iso_path),
        )
        console.ok("  [ok] ISO attachee : {}".format(iso_path))
    else:
        console.warn(
            "ISO introuvable : {} (attachez-la manuellement ou corrigez --iso)".format(
                iso_path or "(non precisee)"
            )
        )

    console.write("")
    console.ok("=== VM '{}' prete ===".format(vm_name))
    return 0
