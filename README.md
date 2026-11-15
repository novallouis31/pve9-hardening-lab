# pve9-hardening-lab

Lab de test de hardening pour **Proxmox VE 9.x** sur des VM **VirtualBox** locales.

Objectifs : mesurer la **conformite CIS Debian 13 / ANSSI BP-028 / Ceph**, verifier
que le durcissement **ne casse ni Proxmox ni l'OS** (69 tests fonctionnels
avant/apres), et produire un **rapport PDF du delta** par guide.

## Durcir une instance Proxmox (usage rapide)

L'outillage de reference est en **Python** et fonctionne sous Linux
(Ubuntu, SLES, RHEL), macOS et Windows. Pour durcir une instance
Proxmox existante, une seule commande :

```bash
# mot de passe root
python3 scripts/pve.py harden --host 192.168.1.50 --level 2 --password 'secret'

# cle SSH
python3 scripts/pve.py harden --host 10.0.0.5 --level 3 --key ~/.ssh/id_ed25519

# simulation sans modification
python3 scripts/pve.py harden --host 10.0.0.5 --level 2 --password 'secret' --dry-run
```

La commande verifie que la cible est bien un noeud Proxmox, demande une
confirmation, sauvegarde chaque fichier modifie sur la cible, genere un
script de rollback, puis **controle que les services critiques restent
actifs**.

| Option | Role |
|---|---|
| `--host` / `--port` / `--user` | cible de l'instance |
| `--key` ou `--password` | authentification (ou `$PVE_ROOT_PASSWORD`) |
| `--level 1..4` | niveau de durcissement |
| `--plan cis\|anssi\|ceph\|stack` | plan applique |
| `--dry-run` / `--yes` | simulation / non interactif |
| `--audit` | audit de conformite immediat apres durcissement |

Details, installation des dependances et depannage :
[docs/LINUX.md](docs/LINUX.md).

## De-durcir une instance Proxmox (retour a l'etat d'origine)

Pour **faire evoluer un noeud durci** (montee de version PVE 8 -> PVE 9,
mise a jour de paquets), le durcissement peut bloquer l'operation : SSH
restreint, PAM strict, modules noyau filtres, `/etc/fstab` modifie. Le
de-hardening retire ces mesures et **restaure l'etat d'origine** a partir des
sauvegardes produites pendant le durcissement.

```bash
# client bash : IP + mot de passe root (aucune dependance Python)
bash scripts/deharden.sh --host 192.168.1.50 --password 'secret'

# cle SSH
bash scripts/deharden.sh --host 10.0.0.5 --key ~/.ssh/id_ed25519

# simulation : affiche ce qui serait fait, ne modifie rien
bash scripts/deharden.sh --host 10.0.0.5 --password 'secret' --dry-run

# equivalent Python
python3 scripts/pve.py deharden --host 192.168.1.50 --password 'secret'
```

Le client refuse une cible qui n'est pas un noeud Proxmox, copie le script
distant sur la cible, l'execute et recupere le rapport Markdown. Le script
distant verifie la configuration SSH (`sshd -t`) **avant** de recharger le
service : l'acces ne peut pas etre coupe.

Guide complet : [docs/DE-HARDENING.md](docs/DE-HARDENING.md) — rapport de
validation : [reports/rapport-validation-deharden.md](reports/rapport-validation-deharden.md).

## Mesurer la conformite (cycle de lab)

```bash
python3 scripts/pve.py run --phase all --target core --level 2 \
    --audit-extra anssi,ceph,cis13,communautaire --run-func
```

L'outillage est **integralement en Python** : il fonctionne sous Linux
(Ubuntu, SLES, RHEL), macOS et Windows, sans dependance hors stdlib
(paramiko et un moteur Chromium suffisent).

> **Gestion du depot avec GitKraken** (client Git graphique du poste) :
> [docs/GITKRAKEN.md](docs/GITKRAKEN.md) — creation du PAT, clone, push,
> pull requests, resolution de conflits, depannage.
> La CLI GitKraken (`gk`) est egalement supportee (`gk provider add github -t <PAT>`).

## Resultats

| Perimetre | PASS avant | PASS apres | Delta | Compliance | Regressions | Reg. fonctionnelles |
|---|---:|---:|---:|---:|---:|---:|
| CIS Level 1 | 67 | 131 | +64 | 89,4 % | 0 | 0 |
| CIS Level 2 | 67 | 132 | +65 | 100 % | 0 | 0 |
| **Stack complet (CIS L2 + ANSSI N3 + Ceph)** | 67 | **145** | **+78** | **100 %** | **0** | **0** |

**160 controles** collectes par 5 modules, **0 echec** sur le stack complet, et
**0 regression** fonctionnelle. La validation croisee (meme cycle sur des VM
independantes) donne des resultats **strictement identiques** — voir
[reports/rapport-validation-croisee.md](reports/rapport-validation-croisee.md).

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
| Proxmox | `guest/func-test-pve.sh` | le durcissement ne casse **pas Proxmox** | 23 |
| OS | `guest/func-test-os.sh` | le durcissement ne casse **pas l'OS** | 49 |

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
|   |-- pve.py               CLI multiplateforme (point d'entree Python)
|   |-- pve_hardening/       paquet Python (phases, rapports, SSH, PDF, VirtualBox)
|   |-- ssh-tool.py          wrapper SSH/SFTP (paramiko) : test|exec|put|get
|   |-- ssh-exec.py          execution d'une commande distante (usage unique)
|   |-- deharden.sh          client bash de de-hardening (IP + mot de passe / cle)
|-- guest/
|   |-- audit-pve.sh         collecteur PVE/CIS de base, LECTURE SEULE
|   |-- audit-cis13.sh       controles CIS Debian 13 officiels (IDs CIS)
|   |-- audit-anssi.sh       controles ANSSI BP-028
|   |-- audit-ceph.sh        controles Ceph
|   |-- audit-communautaire.sh controles harbian-audit + BP-028
|   |-- func-test-pve.sh     tests fonctionnels Proxmox (23)
|   |-- func-test-os.sh      tests fonctionnels OS (49)
|   |-- apply-homesec-core.sh durcissement CIS niveau 1 a 4
|   |-- apply-anssi.sh       durcissement ANSSI niveau 1 a 4
|   |-- apply-ceph.sh        durcissement Ceph
|   |-- deharden-pve.sh      de-hardening executed sur le noeud (restauration)
|   |-- reset-pristine.sh    retour a l'etat propre
|   |-- bootstrap-sshkey.sh  installe la cle publique du lab
|-- vendor/                  artefacts des projets (generes par `pve.py fetch-vendor`)
|-- answers/mrmasterbay.txt  reponses pour l'assistant interactif archive
|-- reports/                 rapports PDF par guide + rapport de validation
|-- docs/PLAN-DE-TEST.md     protocole complet
|-- docs/DE-HARDENING.md     de-hardening : restauration, upgrade, depannage
|-- docs/CHOIX-PROJET.md     analyse comparative des projets GitHub
|-- docs/LINUX.md            utilisation sous Linux (Ubuntu, SLES, RHEL)
|-- docs/DEPLOIEMENT-AUTOMATIQUE.md  creation de la VM PVE sans intervention
|-- docs/GITKRAKEN.md        utilisation de GitKraken (PAT, push, PR, conflits)
```

## Depot public

Le projet est publie sur GitHub :

- code et documentation : <https://github.com/novallouis31/pve9-hardening-lab>
- atelier de jeux voisin (depot distinct) : <https://github.com/novallouis31/petit-atelier-de-jeux>

```bash
git clone https://github.com/novallouis31/pve9-hardening-lab.git
```

Les secrets et les artefacts de mesure ne sont pas versionnes (`.keys/`,
`artifacts/`, `vendor/`, `reports/*.html`). Les rapports livres sont dans
`reports/` (`rapport-final-*.pdf`, `rapport-validation-deharden.pdf`).

### Republier avec GitKraken

```bash
# 1. enregistrer le Personal Access Token dans la CLI GitKraken
gk provider add github -t ghp_VOTRE_JETON
gk whoami

# 2. publier (le script verifie l'absence de secret avant le push)
python3 scripts/pve.py publish --repo pve9-hardening-lab --token ghp_VOTRE_JETON
```

Detail des operations (clone, push, pull request, conflits, depannage) :
[docs/GITKRAKEN.md](docs/GITKRAKEN.md).

## Demarrage rapide

```bash
# 0. artefacts
python3 scripts/pve.py fetch-vendor
python3 scripts/pve.py verify-vendor

# 1. VM (la creation automatisee de PVE est documentee dans
#    docs/DEPLOIEMENT-AUTOMATIQUE.md)
python3 scripts/pve.py prepare-vm --no-iso

# 2. snapshot de reference (base propre, VM eteinte)
python3 scripts/pve.py snapshot --action create --name pristine

# 3. cycle complet : baseline + audit fonctionnel AVANT, durcissement,
#    audit + audit fonctionnel APRES, rapport PDF
python3 scripts/pve.py run --phase all --target core --level 2 \
    --audit-extra anssi,ceph,cis13,communautaire --run-func
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
