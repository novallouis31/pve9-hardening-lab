# Plan de test de hardening — Proxmox VE 9 sur VirtualBox

## Contexte materiel (releve le 10-11/2026)

| Element | Valeur | Impact sur le test |
|---|---|---|
| PC hote | Intel i9-11950H, 16 fils, 64 Go RAM, Win 11 | suffisant |
| VirtualBox | 7.2.12 r174389 | syntaxe `--nat-pf1`, `--uart-mode1=file` |
| VM cible | `proxmox` (uuid `f4e60ee7-…`), ISO `proxmox-ve_9.2-1.iso` attachee | OK |
| VT-x imbrique | **non supporte** (`Processor supports nested HW virtualization: no`) | pas de `/dev/kvm` dans la VM : les VMs PVE ne fonctionneront pas, les conteneurs LXC si |
| VM avant preparation | RAM **64 Mo**, `x86-long-mode=off`, disque **2 Mo**, NAT sans redirection | **non bootable** : corrige par `pve.py prepare-vm` |

> Le manque de virtualisation imbriquee n'empêche pas le test de hardening : les
> controles visent l'hyperviseur PVE lui-même (SSH, PAM, pare-feu, PVE API, noyau,
> conteneurs). Il est simplement impossible de creer une VM a l'interieur de la VM.

## Protocole en 8 etapes

Chaque etape est un script : rien n'est fait a la main a part l'installation de
Proxmox, la lecture des resultats et les decisions d'arbitrage.

### Etape 0 — Recuperer et verifier les projets

```bash
python3 scripts/pve.py fetch-vendor     # telecharge, epinglé sur commit
python3 scripts/pve.py verify-vendor    # controle SHA256
```

### Etape 1 — Preparer la VM

```bash
python3 scripts/pve.py prepare-vm       # VM ETEINTE obligatoire
```

Corrige : `os-type=Debian_64`, 8 Go RAM, 4 CPU, `x86-long-mode=on`, disque 64 Go,
`firmware=bios`, boot dvd puis disque, `nic1=nat` virtio, redirection
`127.0.0.1:8006 -> 8006` et `127.0.0.1:2222 -> 22`, port serie `ttyS0`
journalise dans `<VM>\console.log` (acces hors bande en cas de blocage), et
genere la paire de cles SSH du lab dans `.keys/`.

Le choix `bios` (plutot qu'`efi`) est delibere : VirtualBox 7.2 **n'implemente pas**
le Secure Boot, donc les controles *1.2.1.1 UEFI Secure Boot* et *1.2.1.2 Kernel
Lockdown* du guide sont declarés **N/A** dans ce lab. Les codes d'audit `audit-pve.sh`
les classent automatiquement N/A pour ne pas polluer le score.

### Etape 2 — Installer Proxmox VE 9.2

Demarrer la VM (GUI VirtualBox), suivre l'installeur, memoriser le mot de passe root.
Le partitionnement standard (LVM, ext4) suffit ; ZFS est aussi possible mais avec
le RAM disponible, LVM est plus representative d'un noeud de test homelab.

A la fin de l'installation, la web UI est sur <https://127.0.0.1:8006/> (certificat
autologgué, acceptez l'avertissement du navigateur).

### Etape 3 — Ouvrir l'acces SSH automatise (bootstrap)

```bash
python3 scripts/pve.py run --phase bootstrap
```

Affiche une commande a coller une seule fois dans **Web UI -> Noeud -> Shell**. Elle
installe la cle publique du lab dans `/root/.ssh/authorized_keys`. Sur PVE ce fichier
est un lien vers `/etc/pve/priv/authorized_keys` (partage entre noeuds) : sans
importance sur un noeud seul, mais a connaitre si vous ajoutez des noeuds.

### Etape 4 — Prendre une photographie AVANT

```bash
python3 scripts/pve.py run --phase baseline
```

Deploie `guest/audit-pve.sh` (lecture seule) et recupere `artifacts/baseline-<ts>/`
contenant `audit.txt` et `checks.tsv`. **129 controles objectifs** (CIS Debian 13,
guide PVE 9, ANSSI BP-028, Ceph, controles communautaires) codes
`PASS|FAIL|NA|INFO`. **Sans ce baseline, aucune conclusion avant/apres n'est
possible.**

Avec `-RunFunc`, deux suites de tests fonctionnels sont executees et archivees :

| Suite | Script | Objet | Tests |
|---|---|---|---|
| Proxmox | `guest/func-test-pve.sh` | le durcissement ne casse **pas Proxmox** | Web UI, API, SSH par cle, services critiques, pare-feu, stockage, reseau, cycle de vie LXC, pveam, TLS, journalisation |
| OS | `guest/func-test-os.sh` | le durcissement ne casse **pas l'OS** | systemd, sysctl, montages/options, espace disque, DNS/routage, PAM, sudo, comptes, cron, journald/rsyslog/auditd, AppArmor, dpkg/apt, noyau/limites, horloge |

Les deux suites produisent un rapport **unifie** (`artifacts/func-<label>-<ts>/fonctionnel.txt`)
et les resultats sont traces dans le PDF avec une ventilation par suite
(« Tests fonctionnels - synthese par suite (non-regression) »), ce qui permet de
verifier separement que **Proxmox ET l'OS** fonctionnent toujours apres hardening.

La suite OS est indispensable : un durcissement peut laisser Proxmox intact tout en
casseant l'OS (sysctl incoherent, PAM corrompu, cron bloque, journalisation perdue),
ce que les seuls tests Proxmox ne detecteraient pas.

### Bugs fonctionnels reels detectes par la suite OS

La suite OS a immediatement mis en evidence une regression que les 21 tests Proxmox
ne pouvaient pas voir :

| Symptome | Cause racine | Correctif |
|---|---|---|
| `fail2ban.service` en echec (`status=255`), OS en etat `degraded` | le filtre `proxmox` de fail2ban 1.x contient une `failregex` **sans groupe `<HOST>`** -> `ERROR No failure-id group` | filtre dedie `pveproxy` ecrit par le lab |
| idem | la regex JSON du filtre ne correspondait pas au format reel du log pveproxy (format Apache, pas JSON) | regex `401`/`403` au format Apache |
| idem | `port = https,http` genereait une regle nftables `dport { https,http }` invalide | un port par jail |
| idem | le fichier de jail ecrit via heredoc demarrait par un backslash litteral -> `File contains no section headers` | ecriture via `write_file` |

Le control audit `OS.SSHD.PERMITROOT` a egalement impose de revoir la strategie
root SSH : voir la section dediee dans le README.

### Trois faux WARN/NA elimines (tests qui signalaient un probleme inexistant)

| Test | Symptome | Cause | Correctif |
|---|---|---|---|
| `FUNC.TLS.CERT` | WARN systematique | le test cherchait `pveproxy-ssl.pem` ; Proxmox VE 9 utilise `/etc/pve/local/pve-ssl.pem` | recherche des 3 chemins possibles + validation OpenSSL du certificat |
| `OS.SVC.systemd-timesyncd` | WARN alors que la synchro est operationnelle | PVE n'embarque pas `systemd-timesyncd` mais **chrony** | le test accepte chrony OU systemd-timesyncd |
| `FUNC.LXC.CREATE` | NA (aucun test reel) | aucun template Debian local | le test installe le template via `pveam` avant de tester le cycle de vie |

### Tracabilite complete des tests fonctionnels

Le tableau de synthese affiche **tous** les statuts (PASS / FAIL / WARN / NA)
avant et apres, avec une **colonne de controle** qui verifie que la somme des
statuts egale le nombre total de tests :

```
| Suite   | Tests | PASS av. | PASS ap. | FAIL av. | FAIL ap. | WARN av. | WARN ap. | NA av. | NA ap. | Regression | Controle somme |
| Proxmox | 21    | 19       | 19       | 0        | 0        | 1        | 1        | 1      | 1      | 0          | OK (21/21)    |
| OS      | 48    | 40       | 47       | 0        | 0        | 4        | 1        | 4      | 0      | 0          | OK (48/48)    |
| TOTAL   | 69    | 59       | 66       | 0        | 0        | 5        | 2        | 5      | 1      | 0          | av.=69/69 ap.=69/69 OK |
```

Une section supplementaire detaille **chaque** test non PASS (WARN ou NA) avec
son motif : aucune correction n'est masquee.

### Etape 5 — Faire un snapshot

```bash
python3 scripts/pve.py snapshot --action create --name pre-hardening
```

Le hardening est destructif par definition. Sans snapshot, une erreur (typiquement :
couper SSH ou la web UI) impose une reinstallation complete.

### Etape 6 — Appliquer le hardening

```bash
python3 scripts/pve.py run --phase apply --target core
```

Le script du lab accepte un **niveau CIS** : `LEVEL=1` (defaut), `LEVEL=2`, `LEVEL=3`.
Les blocs non inclus au niveau demande sont affiches `SKIP` avec leur reference de
controle, donc on sait precisement ce qui n'est pas applique.

| Cible | Ce que c'est | Pourquoi le tester |
|---|---|---|
| `core` (defaut) | `guest/apply-homesec-core.sh`, notre automatisation tracée du guide PVE 9 | resultat reproductible, chaque bloc porte sa reference de controle, rollback genere |
| `abua` | `PVE9-Harden-FinalVersion-v1.sh` pilote a `niveau 3` via PTY | le seul depot du panel deja teste sous VirtualBox ; permet de comparer une implementation a l'autre |
| `mrmasterbay` | `seuwrity.sh` pilote avec `answers/mrmasterbay.txt` | depot **archive** et tres agressif : sert a documenter ce qui casse |

Périmètre appliqué à `LEVEL=1` (CIS Debian 13 Level 1 + guide 1.2.4) :

| Famille | Controles |
|---|---|
| Noyau | modules FS et protocoles inutilises (CIS 1.1.1.x, 3.2.x), core dumps (1.5.11-13), sysctl de base |
| Systeme de fichiers | `/tmp`, `/var/tmp`, `/dev/shm` nosuid/nodev (+ noexec sur shm) (CIS 1.1.2.x) |
| Cron / at | permissions 600 / 700 (CIS 2.4.1.x) |
| Journalisation | journald persistent + compress (CIS 4.2.1.x) |
| SSH | permissions fichiers (5.1.1-5.1.3), `PermitRootLogin prohibit-password` (deviation § 5.1.21), `PasswordAuthentication no`, chiffrement CIS (5.1.4-5.1.22) |
| PAM | `pam_faillock` (5.3.3.1), `pwquality` (5.4.1), vieillissement des mots de passe |
| Patches | `unattended-upgrades` (guide 1.1.3) |
| Pare-feu | pare-feu PVE active avec regles 22 / 8006 / 3128 depuis le sous-reseau de gestion (guide 1.2.4) |
| Web | fail2ban sur `pveproxy` (guide 2.3.3) |
| Comptes | compte nominatif `pveadmin` (guide 2.1.1 / 2.1.2) |

Reportés à `LEVEL=2` : politique FORWARD DROP + backend nftables (1.2.5), auditd
sur `/etc/pve` (5.1.2), rkhunter (5.3.2), profil ssh-audit strict (1.1.4), umask 027.

Le script `core` inclut des garde-fous : il refuse de couper
`PasswordAuthentication` tant qu'aucune cle publique n'est installee, verifie
`sshd -t` avant de redemarrer sshd, genere `/root/rollback-hardening.sh`, et
sauvegarde chaque fichier touche dans `/root/hardening-backups/<ts>/`.

### Etape 7 — Comparer avant / apres et produire le rapport PDF

```bash
python3 scripts/pve.py run --phase verify
```

Appelle `scripts/pve.py report` qui produit trois fichiers dans `artifacts/` :

| Fichier | Contenu |
|---|---|
| `comparatif-<ts>.md` | version Markdown, diffable |
| `comparatif-<ts>.html` | mise en page imprimee (tableaux, badges PASS/FAIL) |
| `comparatif-<ts>.pdf` | **livrable final A4**, rendu par Chrome headless |

Le PDF met en avant quatre familles, dans cet ordre de priorite :
**regressions** (controle conforme devenu non conforme — a analyser), puis
**ameliorations**, puis **controles encore en echec**, puis **details** des ~60
controles avec leur statut avant et apres.

Le rendu PDF ne depend d'aucun package : il utilise le moteur d'impression de
Chrome ou Edge, tous deux presents sur Windows 11 (`scripts/pve.py pdf`).

### Etape 8 — Rollback ou itération

```bash
python3 scripts/pve.py snapshot --action restore --name pre-hardening
```

## Ce qui est intrinsequement hors portee dans ce lab

| Controle du guide | Raison |
|---|---|
| 1.2.1.1 UEFI Secure Boot | VirtualBox 7.2 n'expose pas de Secure Boot |
| 1.2.1.2 Kernel Lockdown | depend du Secure Boot |
| 3.x Cluster / Ceph | un seul noeud, pas de virtualisation imbriquee |
| 4.x PBS / 3-2-1 | necessite un noeud Proxmox Backup Server |
| 2.3.1/2.3.2 certificats tiers + renouvellement | possible mais hors perimetre du premier passage |

Ces controles sont declares `N/A` par `audit-pve.sh`, pas passes sous silence :
ils apparaissent dans la synthese sans penaliser le score.

## Livrables attendus

1. `artifacts/baseline-*/audit.txt` — etat de depart
2. `artifacts/after-*/audit.txt` — etat final
3. `artifacts/comparatif-*.md` / `.html` / **`.pdf`** — rapport de comparaison (le PDF est le livrable a partager)
4. `console.log` — journal serie (diagnostic si la VM devient inaccessible)
5. Transcription de session SSH pour les cibles interactives
