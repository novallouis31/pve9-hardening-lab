# Utilisation sous Linux (Ubuntu, SLES, RHEL)

Ce projet est utilisable sur **Linux** (Ubuntu, Debian, SLES, RHEL), macOS et
Windows. Deux usages sont possibles :

1. **durcir une instance Proxmox existante** (usage le plus courant) :
   une seule commande, depuis n'importe quel poste d'administration ;
2. **rejouer le cycle de mesure complet** (baseline, durcissement, rapport
   PDF) sur une VM de laboratoire.

L'outillage est **integralement en Python** (`scripts/pve.py`). Il fonctionne a
l'identique sous Linux (Ubuntu, SLES, RHEL), macOS et Windows : aucun script
PowerShell n'est requis.

## Prerequis

| Besoin | Paquet (Debian/Ubuntu) | Paquet (RHEL) | Paquet (SLES) |
|---|---|---|---|
| Python 3.9+ | `python3` | `python3` | `python3` |
| SSH (paramiko) | `python3-paramiko` ou `pip install paramiko` | `python3-paramiko` | `python3-paramiko` |
| Rendu PDF | `chromium` ou `google-chrome-stable` | `chromium` | `chromium` |
| VirtualBox (optionnel, pour le lab) | `virtualbox` | `virtualbox` | `virtualbox` |

```bash
# Debian / Ubuntu
sudo apt install -y python3 python3-paramiko chromium
# RHEL / Rocky / Alma
sudo dnf install -y python3 python3-paramiko chromium
# SLES
sudo zypper install -y python3 python3-paramiko chromium
```

Seuls `paramiko` et un moteur Chromium sont necessaires en dehors de la
bibliotheque standard. Aucun paquet n'est a installer sur la cible durcie :
les scripts de durcissement (`guest/*.sh`) n'utilisent que `bash` et les
outils habituels de la distribution.

## 1. Durcir une instance Proxmox existante

C'est le cas d'usage principal. Le script se connecte en SSH, verifie que la
cible est bien un noeud Proxmox, applique le durcissement demande, puis
controle que les services critiques sont toujours actifs.

```bash
# Mot de passe root
python3 scripts/pve.py harden --host 192.168.1.50 --level 2 --password 'secret'

# Cle SSH
python3 scripts/pve.py harden --host 10.0.0.5 --level 3 --key ~/.ssh/id_ed25519

# Mot de passe fourni par variable d'environnement (plus sûr pour l'historique)
export PVE_ROOT_PASSWORD='secret'
python3 scripts/pve.py harden --host 10.0.0.5 --level 2

# Simulation : affiche ce qui serait fait, sans modifier
python3 scripts/pve.py harden --host 10.0.0.5 --level 2 --password 'secret' --dry-run

# Non interactif (automatisation, CI)
python3 scripts/pve.py harden --host 10.0.0.5 --level 2 --password 'secret' --yes

# Avec audit de conformite immediat
python3 scripts/pve.py harden --host 10.0.0.5 --level 2 --password 'secret' --audit
```

### Options

| Option | Defaut | Role |
|---|---|---|
| `--host` | *(obligatoire)* | adresse IP ou nom d'hote de l'instance |
| `--port` | `22` | port SSH |
| `--user` | `root` | utilisateur SSH |
| `--key` | — | cle privee SSH |
| `--password` | `$PVE_ROOT_PASSWORD` | mot de passe root |
| `--level` | `2` | niveau de durcissement (1 a 4) |
| `--plan` | `stack` | `cis`, `anssi`, `ceph` ou `stack` (les trois) |
| `--dry-run` | — | simulation, aucune modification |
| `--yes` | — | ne demande pas de confirmation |
| `--audit` | — | execute l'audit de conformite apres le durcissement |
| `--audit-extra` | `anssi,ceph,cis13,communautaire` | modules d'audit supplementaires |
| `--report` / `--pdf` | — | ecrit un rapport Markdown / PDF |

### Niveaux de durcissement

| Niveau | Portee |
|---|---|
| 1 | socle : modules noyau, sysctl, montages, cron, journald, SSH, PAM, patches, pare-feu PVE, fail2ban, comptes, auditd, rkhunter |
| 2 | + politique `FORWARD DROP` et backend nftables, `umask 027` |
| 3 | ANSSI : integrite AIDE, centralisation rsyslog, AppArmor enforce, USB desactive, `cron.allow`, **root SSH restreint au sous-reseau de management** |
| 4 | ANSSI eleve : services non essentiels desactives, `umask 077` root, nettoyage des comptes |

### Garanties

* la cible est **verifiee** avant toute modification : le durcissement est
  specifique a Proxmox VE (pveproxy, `/etc/pve`, pve-firewall) et la
  commande **refuse** une machine qui n'en est pas une ;
* une **confirmation** est demandee (sauf `--yes`) ;
* chaque fichier modifie est **sauvegarde** sur la cible dans
  `/root/hardening-backups/<horodatage>/` et un script de rollback est genere ;
* apres application, les services `ssh` et `pveproxy` sont **verifies** ; en
  cas de panne, le rollback est immediatement disponible :

```bash
bash /root/rollback-hardening.sh /root/hardening-backups/20261113_074520
```

## 2. De-durcir une instance (retour a l'etat d'origine)

Pour qu'un noeud durci puisse **evoluer** (montee de version PVE 8 -> PVE 9,
mise a jour de paquets), le de-hardening retire les mesures de durcissement et
restaure l'etat d'origine.

```bash
# Client bash : IP + mot de passe root, aucune dependance Python
bash scripts/deharden.sh --host 192.168.1.50 --password 'secret'

# Cle SSH
bash scripts/deharden.sh --host 10.0.0.5 --key ~/.ssh/id_ed25519

# Simulation : affiche ce qui serait fait, ne modifie rien
bash scripts/deharden.sh --host 10.0.0.5 --password 'secret' --dry-run

# Equivalent Python (meme script distant)
python3 scripts/pve.py deharden --host 192.168.1.50 --password 'secret'
```

| Option | Role |
|---|---|
| `--host` / `--port` / `--user` | cible de l'instance |
| `--password` / `--key` | authentification |
| `--dry-run` | simulation, aucune modification |
| `--keep-packages` | conserve les paquets installes par le durcissement |
| `--report` | rapport Markdown local |

> Sous WSL (ou sur tout systeme de fichiers monte), une cle SSH lisible par
> tous est refusee par OpenSSH : le client copie la cle dans `$HOME/.ssh`
> (mode `600`) avant de l'utiliser.

Guide complet : [DE-HARDENING.md](DE-HARDENING.md).

## 3. Rejouer le cycle de mesure complet

Pour un **rapport PDF avant/apres** (conformite + non-regression), on utilise
la commande `run`, qui enchaine baseline, durcissement et rapport :

```bash
# Cycle complet sur une VM de laboratoire
python3 scripts/pve.py run --phase all --target core --level 2 \
    --audit-extra anssi,ceph,cis13,communautaire --run-func

# Phases separees
python3 scripts/pve.py run --phase baseline --audit-extra anssi,ceph,cis13,communautaire
python3 scripts/pve.py run --phase apply --target core --level 2
python3 scripts/pve.py run --phase verify --audit-extra anssi,ceph,cis13,communautaire --run-func

# Rapport seul, a partir de deux instantsanes
python3 scripts/pve.py report \
    --before artifacts/baseline-20261113-074520 \
    --after  artifacts/after-20261113-080000 \
    --before-func artifacts/func-before-20261113-074520/fonctionnel.txt \
    --after-func  artifacts/func-after-20261113-080000/fonctionnel.txt \
    --report reports/mon-rapport.md --pdf reports/mon-rapport.pdf
```

Les artefacts sont ecrits dans `artifacts/`, les rapports livres dans
`reports/`.

## 4. Gestion des VM de laboratoire (VirtualBox)

```bash
# Creer un snapshot de reference
python3 scripts/pve.py snapshot --action create --name pristine --vm proxmox

# Lister / restaurer / supprimer
python3 scripts/pve.py snapshot --action list   --vm proxmox
python3 scripts/pve.py snapshot --action restore --name pristine --vm proxmox
python3 scripts/pve.py snapshot --action delete  --name pristine --vm proxmox
```

> **Rappel** : un **clone** de disque VDI porte un UUID different, ce qui
> casse le demarrage de Proxmox (GRUB ne trouve plus la racine). Utilisez
> des **snapshots** : ils preservent l'UUID du disque.

## 5. Artefacts de reference

Les scripts de durcissement d'autres projets (pour comparaison) sont
telecharges et verifies par empreinte SHA256 :

```bash
python3 scripts/pve.py fetch-vendor
python3 scripts/pve.py verify-vendor
```

Ils sont figes sur un commit SHA : le contenu ne peut pas changer entre deux
executions, ce qui rend les tests reproductibles.

## 6. Depannage

| Symptome | Cause | Correctif |
|---|---|---|
| `connexion par cle impossible ... repli sur le mot de passe` | la restauration d'un snapshot reinitialise `/etc/pve/priv/authorized_keys` (fichier partage Proxmox) | normal : le repli est automatique, la cle est reinjectee au cycle suivant |
| `la cible n'est pas un noeud Proxmox` | l'hote ne tourne pas Proxmox, ou le durcissement est incompatible | verifier avec `ssh root@cible 'cat /etc/pve/version'` |
| `Chromium introuvable pour l'impression PDF` | aucun moteur installe | `sudo apt install chromium` ou `export CHROME_PATH=/chemin/vers/chromium` |
| `Permission denied (publickey)` | cle absente ou mauvaise | `ssh -i ~/.ssh/id_ed25519 root@cible` pour verifier |
| `Timeout` pendant l'application | l'init AIDE ou une installation apt est longue | augmenter `--ssh-timeout` (defaut 3600 s) |
| `OS.MOUNT._dev_shm` en echec apres redemarrage | `/dev/shm` n'etait pas declare dans `/etc/fstab` | corrige : le script declare les trois points de montage temporaires |

## 7. Correspondance des anciennes commandes

L'outillage est **integralement en Python** : il n'y a plus de script
PowerShell. La table ci-dessous donne l'equivalent de chaque ancien
script, pour les reponses de suivi fournies dans la documentation.
| Ancien script (supprime) | Equivalent Python |
|---|---|
| `scripts/pve.py run` | `python3 scripts/pve.py run` |
| `scripts/pve.py report` | `python3 scripts/pve.py report` |
| `scripts/pve.py fetch-vendor` | `python3 scripts/pve.py fetch-vendor` |
| `scripts/pve.py verify-vendor` | `python3 scripts/pve.py verify-vendor` |
| `scripts/pve.py pdf` | `python3 scripts/pve.py pdf` |
| `scripts/pve.py snapshot` | `python3 scripts/pve.py snapshot` |
| `scripts/pve.py image` | `python3 scripts/pve.py image` |
| `scripts/pve.py prepare-vm` | `python3 scripts/pve.py prepare-vm` |
| `scripts/pve.py publish` | `python3 scripts/pve.py publish` |
| *(nouveau)* | `python3 scripts/pve.py harden` |

Le rapport Markdown et le HTML produits par Python sont identiques a ceux
que produisait PowerShell (memes sections, memes tableaux, meme tri
culturel des controles) ; le PDF est genere par le meme moteur.
