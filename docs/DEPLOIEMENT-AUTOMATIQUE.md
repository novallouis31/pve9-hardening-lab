# Deploiement automatise de Proxmox VE 9 sur plusieurs VM

Ce document explique comment le lab de hardening recree des VM Proxmox VE 9
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
- Le disque doit etre visible en **`/dev/sda`**. Sur un controleur **SATA**
  (AHCI), le disque attache en port 0 apparait bien en `/dev/sda` ; sur un
  controleur **IDE**, il faut verifier que le port 0 est bien le disque
  (et non un DVD).

## Preparation de l'ISO

L'ISO officielle ne contient pas de Rock Ridge : sous Linux, `/cdrom/answer.toml`
serait invisible avec les noms ISO9660 (8.3). Il faut donc **reconstruire l'ISO**
en injectant les deux fichiers avec un nom Rock Ridge.

```bash
pip install pycdlib
python3 - <<'PY'
import io, shutil, pycdlib
SRC = "/mnt/c/Users/Louis/Downloads/proxmox-ve_9.2-1.iso"
OUT = "/mnt/c/vbox/pve2-auto.iso"
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

Verification du contenu (noms Rock Ridge) :

```bash
python3 - <<'PY'
import io, pycdlib
iso = pycdlib.PyCdlib(); iso.open('/mnt/c/vbox/pve2-auto.iso')
for root, dirs, files in iso.walk(rr_path="/"):
    for name in files:
        rp = (root.rstrip("/") + "/" + name)
        if name.lower() in ("answer.toml", "auto-installer-mode.toml"):
            buf = io.BytesIO(); iso.get_file_from_iso_fp(rr_path=rp, outfp=buf)
            print(rp); print(buf.getvalue().decode())
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
| **le VM ne redemarre plus apres N restores** | **disques differentiels cumules** | **snapshots (UUID preserve) : ne jamais cloner** |
| `VERR_DISK_FULL` / `Could not create the clone medium` | **disque hote plein** | verifier `Get-PSDrive C` : il faut ~15 Go libres pour un disque PVE de 64 Go |
| `createmedium` echoue sans raison claire | medium deja enregistre dans le registre media | detacher le disque (`storageattach ... --medium=none`) **puis** supprimer le fichier, attendre 3 s, recreer |
| `UUID {...} of the medium does not match the value {...} stored in the media registry` | **registre media de VirtualBox corrompu** (snapshots supprimes a la main) | recreer la VM : `unregistervm <nom> --delete` puis `createvm` + `storageattach` du disque **de base** |
| 2 emplacements de disque affiches pour le port 0 | UUID fantomes dans le registre | idem : recreer la VM |
| la VM reboot en boucle, le disque ne grossit pas | l'ISO automatise n'est pas monte (media verrouille) ou `boot1=floppy` | `--boot1=dvd --boot2=disk`, verifier `Port 1, Unit 0` |
| UUID de disque incompatible GRUB | un **clone VDI** porte un UUID different : `Waiting for root device...` | **snapshots uniquement** (l'UUID est preserve) |
| `snapshot restore` bloque indefiniment | snapshot sur un disque lent (carte 82540EM) + differentiels cumules | supprimer le snapshot (fusion) et reattacher le disque de base ; privilegier `virtio` |
| SSH injoignable apres un `snapshot restore` | la restauration ecrase `/etc/pve/priv/authorized_keys` (fichier partage Proxmox) | reinjection automatique de la cle a chaque cycle (voir `Install-SshPubKey`) |
| SSH injoignable apres un `snapshot restore` | le snapshot a ete restaure **a chaud** (VM en marche) | toujours arreter la VM (`poweroff`) **avant** `snapshot restore` |

## Regles de disque (cause racine de la plupart des pannes)

Le disque hote doit disposer d'**au moins 15 Go libres** par VM deployee
(disque de travail 4,4 Go + image de reference 4,4 Go + fichier temporaire de
clonage 4,4 Go coexistent le temps d'un cycle).

```
Get-PSDrive C | Select-Object @{n='LibreGo';e={[math]::Round($_.Free/1GB,2)}}
```

Si `VERR_DISK_FULL` apparait : `createmedium` et `clonemedium` echouent
silencieusement ou avec une erreur trompeuse, ce qui donne l'impression que la
VM est cassee (le VM ne demarre plus, aucune banniere SSH).

## Pourquoi le snapshot est prefere au clonage

Un **clone de disque VDI porte un UUID different** de la source. Or
l'installateur Proxmox ecrit cet UUID dans la configuration GRUB
(`/etc/default/grub`, `GRUB_DEVICE_UUID`) et dans `/etc/fstab` : le clone
demarre alors sur `Waiting for root device...` puis se fige. Symptome : la VM
reste `running` mais aucune banniere SSH n'arrive, et le disque ne grossit pas.

Un **snapshot conserve l'UUID du disque** : le boot fonctionne parfaitement.
Seul le differentiel cree par le snapshot grossit (quelques Mo par cycle de
durcissement), ce qui reste tres acceptable.

Workflow retenu :

```
VBoxManage snapshot proxmox take pristine     # fige l'etat propre
... cycle : restore pristine -> boot -> baseline -> apply -> verify ...
```

Si le VM ne redemarre plus apres plusieurs `restore` successifs :
`VBoxManage snapshot proxmox delete pristine` fusionne le differentiel dans la
base et rend le disque de nouveau bootable (verifie dans cette session).

## Sequence de deploiement

```powershell
# 1. Creer le disque 64 Go et la VM
VBoxManage createmedium disk --filename "$VMDIR\proxmox.vdi" --size 65536 --format VDI
VBoxManage createvm --name proxmox --ostype Debian_64 --register --basefolder $VMDIR
VBoxManage modifyvm proxmox --memory 8192 --cpus 4 --firmware bios --acpi on --ioapic on
VBoxManage modifyvm proxmox --nic1 nat --nictype1 virtio --cable-connected1 on
VBoxManage storagectl proxmox --name IDE --add ide --controller PIIX4 --bootable on
VBoxManage storageattach proxmox --storagectl IDE --port 0 --device 0 --type hdd --medium proxmox.vdi
VBoxManage storageattach proxmox --storagectl IDE --port 1 --device 0 --type dvddrive --medium proxmox-auto.iso
VBoxManage modifyvm proxmox --boot1=dvd --boot2=disk
VBoxManage modifyvm proxmox --nat-pf1 "pve-web,tcp,127.0.0.1,8006,,8006" --nat-pf2 "pve-ssh,tcp,127.0.0.1,2222,,22"

# 2. Demarrer : l'installeur automatique se declenche (timeout GRUB = 10s)
VBoxManage startvm proxmox --type headless

# 3. Attendre la fin (le VM s'eteint : reboot-mode = power-off)

# 4. Retirer l'ISO, booter sur le disque
VBoxManage storageattach proxmox --storagectl IDE --port 1 --device 0 --type dvddrive --medium=none
VBoxManage modifyvm proxmox --boot1=disk --boot2=dvd
VBoxManage startvm proxmox --type headless

# 5. Snapshot de reference (VM eteinte)
powershell -File scripts\\vm-snapshot.ps1 -Action Create -Name pristine
```

## Regles NAT (a reappliquer a chaque arret)

Les regles de redirection NAT sont perdues a chaque arret du VM (`poweroff`).
Les recreer systematiquement **avant** la boucle d'attente SSH :

```powershell
VBoxManage controlvm proxmox natpf1 delete pve-ssh
VBoxManage controlvm proxmox natpf1 "pve-ssh,tcp,127.0.0.1,2222,,22"
VBoxManage controlvm proxmox natpf1 "pve-web,tcp,127.0.0.1,8006,,8006"
```

## Cycle de test

```powershell
# Restauration de la base propre
powershell -File scripts\\vm-snapshot.ps1 -Action Restore -Name pristine
VBoxManage startvm proxmox --type headless
# ... attendre SSH ...

# Baseline + durcissement + rapport
powershell -File scripts\\run-phase.ps1 -Phase all -Target core -Level 2 `
    -AuditExtra anssi,ceph,cis13,communautaire -RunFunc
```

## Scripts annexes

| Fichier | Role |
|---|---|
| `scripts/ssh-tool.py` | wrapper SSH/SFTP via paramiko (contourne les problemes de `ssh.exe` sous PowerShell) |
| `scripts/vm-image.ps1` | sauvegarde/restauration de l'image de reference par **clonage complet** du disque |
| `guest/reset-pristine.sh` | retour a l'etat propre (annule le hardening) |
| `guest/func-test-pve.sh` | tests fonctionnels de non-regression Proxmox (21 tests) |
| `guest/func-test-os.sh` | tests fonctionnels de non-regression OS (48 tests) |
