# Deplooiement automatise de la VM PVE 9

Ce document explique comment le lab de hardening recree une VM Proxmox VE 9
**de zero, sans intervention manuelle**, a partir de l'ISO officielle.

## Principe

L'ISO Proxmox VE 9 embarque un **installateur automatique** (`proxmox-auto-installer`).
Il attend un fichier de reponses TOML (`answer.toml`) et un declencheur
(`auto-installer-mode.toml`) places a la racine du CD.

```
/cdrom/answer.toml             reponses de l'installation
/cdrom/auto-installer-mode.toml declencheur + mode de recherche du fichier answer
```

Le mode `iso` cherche le fichier de reponses directement sur le CD.

## Format des fichiers

### `auto-installer-mode.toml`

```toml
mode = "iso"
```

Champs acceptes par le binaire : `mode` (`iso` | `partition` | `http`),
`partition_label`, `http`.

### `answer.toml`

```toml
[global]
country = "fr"
timezone = "Europe/Paris"
keyboard = "fr"
mailto = "root@localhost"
root-password = "19581958"
root-ssh-keys = ["ssh-ed25519 AAAA... pve9-hardening-lab"]
fqdn = "pve.lab.local"
reboot-mode = "power-off"

[network]
source = "from-dhcp"

[disk-setup]
filesystem = "ext4"
disk-list = ["/dev/sda"]
```

Points importants decouverts a l'usage :

- `filesystem` n'accepte que `ext4`, `xfs`, `zfs`, `btrfs` (**pas** `lvm`).
- `disk-list` ou `filter` est **obligatoire**.
- `reboot-mode = "power-off"` est indispensable : avec `reboot`, l'installeur
  redemarre sur l'ISO encore present et **relance l'installation en boucle**,
  ce qui corrompt le disque.
- `root-ssh-keys` installe la cle du lab : l'acces SSH est automatique apres
  le premier demarrage, sans passer par la Web UI.

## Preparation de l'ISO

L'ISO officielle ne contient pas de Rock Ridge : sous Linux, `/cdrom/answer.toml`
serait invisible avec les noms ISO9660 (8.3). Il faut donc **reconstruire l'ISO**
en injectant les deux fichiers avec un nom Rock Ridge.

```bash
pip install pycdlib
python3 - <<'PY'
import io, shutil, pycdlib
SRC = "/mnt/c/Users/Louis/Downloads/proxmox-ve_9.2-1.iso"
OUT = "/mnt/c/Users/Louis/AppData/Local/Temp/opencode/proxmox-auto.iso"
shutil.copyfile(SRC, OUT)
iso = pycdlib.PyCdlib()
iso.open(OUT)
iso.add_fp(io.BytesIO(open("/tmp/answer.toml","rb").read()), len(...),
           iso_path="/ANSWER.TOML;1", rr_name="answer.toml")
iso.add_fp(io.BytesIO(open("/tmp/auto-installer-mode.toml","rb").read()), len(...),
           iso_path="/AUTO_INST_TOML;1", rr_name="auto-installer-mode.toml")
iso.write(OUT + ".new")
iso.close()
PY
```

## Pieges VirtualBox 7.2 (Windows)

| Symptome | Cause | Correctif |
|---|---|---|
| `VERR_INVALID_HANDLE` au demarrage | chemin du port serie avec **espaces** | `C:\vbox\console.log` (sans espace) |
| `Failed to open host device 'tcpserver,...'` | mode `tcpserver` / `server pipe` **casse dans ce build** | utiliser le mode `file`, ou pas de port serie |
| `Invalid IRQ number of the serial port` | syntaxe `--uart1=0x3F8` | `--uart1=0x3F8,4` (base, IRQ) |
| le VM s'eteint aussitot | registre media incoherent (UUID) | detacher/re-attacher le disque, recreer le VM |
| `Invalid parameter 'file'` | `--uart-mode1=file,<chemin>` | `--uart-mode1 file <chemin>` (args separes) |

## Sequence de deploiement

```powershell
# 1. Creer le disque 64 Go et le VM
VBoxManage createmedium disk --filename "$VMDIR\proxmox.vdi" --size 65536 --format VDI
VBoxManage createvm --name proxmox --ostype Debian_64 --register --basefolder $VMDIR
VBoxManage modifyvm proxmox --memory 8192 --cpus 4 --firmware bios --acpi on --ioapic on
VBoxManage modifyvm proxmox --nic1 nat --nictype1 virtio --cable-connected1 on
VBoxManage storagectl proxmox --name IDE --add ide --controller PIIX4 --bootable on
VBoxManage storageattach proxmox --storagectl IDE --port 0 --device 0 --type hdd --medium proxmox.vdi
VBoxManage storageattach proxmox --storagectl IDE --port 1 --device 0 --type dvddrive --medium proxmox-auto.iso
VBoxManage modifyvm proxmox --boot1=dvd --boot2=disk
VBoxManage modifyvm proxmox --nat-pf1 "pve-web,tcp,127.0.0.1,8006,,8006" --nat-pf2 "pve-ssh,tcp,127.0.0.1,2222,,22"

# 2. Demarrer : l'installateur automatique se declenche (timeout GRUB = 10s)
VBoxManage startvm proxmox --type headless

# 3. Attendre la fin (le VM s'eteint : reboot-mode = power-off)

# 4. Retirer l'ISO, booter sur le disque
VBoxManage storageattach proxmox --storagectl IDE --port 1 --device 0 --type dvddrive --medium=none
VBoxManage modifyvm proxmox --boot1=disk --boot2=dvd
VBoxManage startvm proxmox --type headless

# 5. Snapshot de reference (VM eteinte)
powershell -File scripts\vm-snapshot.ps1 -Action Create -Name base-propre
```

## Cycle de test

```powershell
# Restauration de la base propre
powershell -File scripts\vm-snapshot.ps1 -Action Restore -Name base-propre
VBoxManage startvm proxmox --type headless
# ... attendre SSH ...

# Baseline + durcissement + rapport
powershell -File scripts\run-phase.ps1 -Phase all -Target core -Level 1 `
    -AuditExtra anssi,ceph,cis13 -RunFunc
```

## Scripts annexes

| Fichier | Role |
|---|---|
| `scripts/ssh-tool.py` | wrapper SSH/SFTP via paramiko (contourne les problemes de `ssh.exe` sous PowerShell) |
| `scripts/vm-image.ps1` | sauvegarde/restauration de l'image de reference par **clonage complet** du disque (plus fiable que les snapshots differentiels) |
| `guest/reset-pristine.sh` | retour a l'etat propre (annule le hardening) |
| `guest/func-test-pve.sh` | tests fonctionnels de non-regression Proxmox |
