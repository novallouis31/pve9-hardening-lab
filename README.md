# pve9-hardening-lab

Lab de test de hardening pour **Proxmox VE 9.x** sur des VM **VirtualBox** locales.

Objectifs : mesurer la **conformite CIS Debian 13 / ANSSI BP-028 / Ceph**, verifier
que le durcissement **ne casse ni Proxmox ni l'OS** (69 tests fonctionnels
avant/apres), et produire un **rapport PDF du delta** par guide.

## Resultats

| Perimetre | PASS avant | PASS apres | Delta | Compliance | Regressions | Reg. fonctionnelles |
|---|---:|---:|---:|---:|---:|---:|
| CIS Level 1 | 67 | 131 | +64 | 89,4 % | 0 | 0 |
| CIS Level 2 | 67 | 132 | +65 | 100 % | 0 | 0 |
| **Stack complet (CIS L2 + ANSSI N3 + Ceph)** | 67 | **146** | **+79** | **100 %** | **0** | **0** |

**160 controles** collectes par 5 modules, **0 echec** sur le stack complet, et
**0 regression** fonctionnelle sur les 3 VM de validation croisee.

### Conformite par perimetre (stack complet)

| Perimetre | Controles | PASS apres | Echecs | Conformite |
|---|---:|---:|---:|---:|
| CIS Debian 13 | 19 | 19 | 0 | **100 %** |
| ANSSI BP-028 | 32 | 32 | 0 | **100 %** |
| Ceph | 11 | 6 | 0 | **100 %** |
| Communautaire (harbian-audit / BP-028) | 31 | 29 | 0 | **100 %** |
| PVE 9 / OS | 67 | 60 | 0 | **100 %** |

## Tests fonctionnels (non-regression)

| Suite | Script | Objet | Tests |
|---|---|---|---:|
| Proxmox | `guest/func-test-pve.sh` | le durcissement ne casse **pas Proxmox** | 21 |
| OS | `guest/func-test-os.sh` | le durcissement ne casse **pas l'OS** | 48 |

La suite OS est indispensable : elle a mis en evidence une regression
(`fail2ban` en `status=255`, OS en etat `degraded`) **invisible** pour les seuls
tests Proxmox.

Chaque rapport PDF contient un tableau de synthese **exhaustif** (PASS / FAIL /
WARN / NA avant et apres) avec une **colonne de controle** verifiant que la
somme des statuts egale le total de tests, plus le detail de chaque test non
PASS.

## Les projets de reference

[`HomeSecExplorer/Proxmox-Hardening-Guide`](https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide)
(version PVE 9, 581 etoiles, alignement CIS Debian 13 avec les deviations
Proxmox documentees). Detail du choix et des candidats ecartes :
[docs/CHOIX-PROJET.md](docs/CHOIX-PROJET.md).

| Source communautaire | Usage |
|---|---|
| `ansible-lockdown/DEBIAN13-CIS` (29*) | IDs et seuils CIS Debian 13 officiels (PAM, umask, permissions) |
| `Makaveli81/ansible-linux-hardening` (59*) | audit_items ANSSI BP-028 (niveaux M/I/R/E) |
| `hardenedlinux/harbian-audit` (472*) | 284 checks Debian durcis (sysctl, sudoers, comptes, SSH) |
| `abualialfatih23/PVE-9-Hardening` (17*) | cible de comparaison (niveaux 1-5) |
| `alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9` (78*) | reference SSH PVE 9 |
| `MrMasterbay/proxmox-security-hardening` (114*) | cible de rupture (depot archive) |

## Structure

```
pve9-hardening-lab/
|-- scripts/
|   |-- fetch-vendor.ps1     telecharge les projets, epingles sur un commit SHA
|   |-- verify-vendor.ps1    verifie l'integrite (SHA256SUMS.txt)
|   |-- prepare-vm.ps1       configure la VM VirtualBox (RAM/CPU/disk/NAT/serie)
|   |-- vm-snapshot.ps1      create / list / restore / delete de snapshots
|   |-- vm-image.ps1         sauvegarde / restauration de l'image de reference (clonage)
|   |-- run-phase.ps1        orchestrateur : bootstrap|baseline|apply|verify|all
|   |-- compare.ps1          rapport de comparaison avant / apres (+ tests fonctionnels)
|   |-- render-pdf.ps1       rendu PDF via Chrome headless
|   |-- ssh-tool.py          wrapper SSH/SFTP (paramiko) : test|exec|put|get
|-- guest/
|   |-- audit-pve.sh         collecteur PVE/CIS de base, LECTURE SEULE
|   |-- audit-cis13.sh       controles CIS Debian 13 officiels (IDs CIS)
|   |-- audit-anssi.sh       controles ANSSI BP-028
|   |-- audit-ceph.sh        controles Ceph
|   |-- audit-communautaire.sh controles harbian-audit + BP-028
|   |-- func-test-pve.sh     tests fonctionnels Proxmox (21)
|   |-- func-test-os.sh      tests fonctionnels OS (48)
|   |-- apply-homesec-core.sh durcissement CIS niveau 1 a 4
|   |-- apply-anssi.sh       durcissement ANSSI niveau 1 a 4
|   |-- apply-ceph.sh        durcissement Ceph
|   |-- reset-pristine.sh    retour a l'etat propre
|   |-- bootstrap-sshkey.sh  installe la cle publique du lab
|-- vendor/                  artefacts des projets (generes par fetch-vendor.ps1)
|-- answers/mrmasterbay.txt  reponses pour l'assistant interactif archive
|-- reports/                 rapports PDF par guide + README
|-- docs/PLAN-DE-TEST.md     protocole complet
|-- docs/CHOIX-PROJET.md     analyse comparative des projets GitHub
|-- docs/DEPLOIEMENT-AUTOMATIQUE.md  creation de la VM PVE sans intervention
```

## Demarrage rapide

```powershell
# 0. artefacts
powershell -ExecutionPolicy Bypass -File scripts\\fetch-vendor.ps1
powershell -ExecutionPolicy Bypass -File scripts\\verify-vendor.ps1

# 1. VM (la creation automatisee de PVE est documentee dans
#    docs/DEPLOIEMENT-AUTOMATIQUE.md)
powershell -ExecutionPolicy Bypass -File scripts\\prepare-vm.ps1 -NoIso

# 2. snapshot de reference (base propre, VM eteinte)
powershell -ExecutionPolicy Bypass -File scripts\\vm-snapshot.ps1 -Action Create -Name pristine

# 3. cycle complet : baseline + audit fonctionnel AVANT, durcissement,
#    audit + audit fonctionnel APRES, rapport PDF
powershell -ExecutionPolicy Bypass -File scripts\\run-phase.ps1 -Phase all -Target core -Level 2 `
    -AuditExtra anssi,ceph,cis13,communautaire -RunFunc
```

## Niveaux de durcissement

| Niveau | Contenu |
|---|---|
| CIS 1 | modules noyau, core dumps, sysctl, /tmp /var/tmp /dev/shm, cron, journald, SSH (option B du guide), PAM (faillock+pwquality CIS), ages des patches, pare-feu PVE, fail2ban, comptes nominatifs, auditd /etc/pve, rkhunter, apparmor-utils, sudo, chrony |
| CIS 2 | + politique DROP / backend nftables, umask 027 |
| ANSSI 1 | permissions /boot, ctrl-alt-del, sysctl noyau (ASLR, kptr, dmesg, ptrace, BPF), UMASK 027 dans login.defs, TMOUT, shells systeme non interactifs |
| ANSSI 2 | + aging mots de passe, AIDE (+ cron), AppArmor enforce, rsyslog (omfwd), permissions fichiers de comptes, banner, permissions cron |
| ANSSI 3 | + stockage USB desactive, `cron.allow`, **root SSH restreint au sous-reseau de management** (option B du guide PVE 9) |
| ANSSI 4 | + services non essentiels desactives, umask 077 root, nettoyage des comptes |
| Ceph | cephx obligatoire, msgr2 + chiffrement en transit, permissions 750/600 |

### Option B du guide PVE 9 pour le root SSH

Le guide de reference **interdit explicitement** `PermitRootLogin no` sur Proxmox
(les workflows d'administration l'exigent) et recommande l'**option B** :
interdire le root SSH globalement, sauf depuis le reseau de management.

C'est ce que le lab applique :

```
PermitRootLogin no
...
Match Address 10.0.2.0/24
    PermitRootLogin yes
```

Verifie a chaud sur la VM :

```
sshd -T                                      -> permitrootlogin no
sshd -T -C addr=10.0.2.2  (client du lab)   -> permitrootlogin yes
sshd -T -C addr=192.0.2.55 (source externe) -> permitrootlogin no
```

## Tracabilite et rollback

Chaque bloc de durcissement porte la reference du controle (guide PVE 9, IDs CIS
Debian 13, ANSSI BP-028, checks harbian-audit). Un script de rollback est genere
sur le noeud (`/root/rollback-hardening.sh`) et le snapshot VirtualBox `pristine`
permet de revenir a la base saine entre deux tests.

### Pieges d'outillage resolus (documentees dans docs/DEPLOIEMENT-AUTOMATIQUE.md)

- un **transfert de fichier tronque** produisait un fichier **vide** sur la VM,
  execute sans rien faire et bloquait le cycle indefiniment -> verification
  SHA256 + taille systematique ;
- le **message de succes** du transfert etait ecrit sur stderr, ce que
  PowerShell 5.1 convertit en erreur bloquante (`ErrorActionPreference=Stop`) ;
- la **restauration d'un snapshot** ecrase `/etc/pve/priv/authorized_keys`
  (fichier partage Proxmox) : la cle du lab est desormais reinjectee
  automatiquement a chaque cycle ;
- un **snapshot restaure a chaud** laisse le guest sans reseau : le VM doit etre
  arrete avant `snapshot restore` ;
- un **clone de disque VDI** porte un UUID different : GRUB ne trouve plus la
  racine -> **snapshots uniquement** (l'UUID est preserve) ;
- `VERR_DISK_FULL` : prevoir ~15 Go libres par VM deployee.
