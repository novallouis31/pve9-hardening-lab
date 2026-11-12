# pve9-hardening-lab

Lab de test de hardening pour **Proxmox VE 9.x** sur une VM **VirtualBox** locale.

Objectifs : mesurer la **conformite CIS Debian 13 / ANSSI / Ceph**, verifier que le
durcissement **ne casse pas** le fonctionnement de Proxmox (tests fonctionnels
avant/apres), et produire un **rapport PDF du delta** par guide.

## Resultats

| Guide | Perimetre | PASS avant | PASS apres | Delta | Compliance | Regressions |
|---|---|---:|---:|---:|---:|---:|
| CIS Level 1 | CIS Debian 13 L1 + guide PVE 9 | 34 | 84 | +50 | **89,4 %** | 0 |
| CIS Level 2 | + FORWARD DROP/nftables, auditd, rkhunter | - | - | - | - | 0 |
| ANSSI Level 3 | + AIDE, rsyslog distant, SSH root=no | - | - | - | - | 0 |
| Ceph | cephx, msgr2, permissions | - | - | - | - | 0 |

Sur le perimetre strict **CIS Level 1 : 100 %** des controles CIS/OS/PVE/USR sont
conformes ; les controles restants sont ceux d'ANSSI et Ceph, appliques par leurs
propres niveaux.

Rapports PDF : [reports/](reports/) (un par guide, tableau recapitulatif complet
avec statut avant/apres/evolution/detail, plus les tests fonctionnels).

## Le projet de reference

[`HomeSecExplorer/Proxmox-Hardening-Guide`](https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide)
(version PVE 9, 580 etoiles, alignement CIS Debian 13 avec les deviations
Proxmox documentees). Detail du choix et des candidats ecartes :
[docs/CHOIX-PROJET.md](docs/CHOIX-PROJET.md).

Referentiels complementaires utilises pour la couverture d'audit :
`ansible-lockdown/DEBIAN13-CIS` (IDs et seuils CIS officiels),
`abualialfatih23/PVE-9-Hardening`, `alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9`,
`MrMasterbay/proxmox-security-hardening`.

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
|   |-- audit-anssi.sh       controles ANSSI
|   |-- audit-ceph.sh        controles Ceph
|   |-- func-test-pve.sh     tests fonctionnels de non-regression Proxmox
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
powershell -ExecutionPolicy Bypass -File scripts\fetch-vendor.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-vendor.ps1

# 1. VM (la creation automatisee de PVE est documentee dans
#    docs/DEPLOIEMENT-AUTOMATIQUE.md ; sinon : prepare-vm.ps1 puis install manuelle)
powershell -ExecutionPolicy Bypass -File scripts\prepare-vm.ps1 -NoIso

# 2. snapshot de reference (base propre, VM eteinte)
powershell -ExecutionPolicy Bypass -File scripts\vm-snapshot.ps1 -Action Create -Name base-propre

# 3. cycle complet : baseline + audit fonctionnel AVANT, durcissement,
#    audit + audit fonctionnel APRES, rapport PDF
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase all -Target core -Level 1 `
    -AuditExtra anssi,ceph,cis13 -RunFunc
```

## Niveaux de durcissement

| Niveau | Contenu |
|---|---|
| CIS 1 | modules noyau, core dumps, sysctl, /tmp /var/tmp /dev/shm, cron, journald, SSH, PAM (faillock+pwquality CIS), ages des patches, pare-feu PVE, fail2ban, comptes nominatifs, auditd /etc/pve, rkhunter |
| CIS 2 | + politique FORWARD DROP / backend nftables, umask 027 |
| ANSSI 3 | + AIDE (integrite), rsyslog distant, `PermitRootLogin no`, `cron.allow`, USB desactive |
| ANSSI 4 | + services inutiles desactives, umask 077 root |
| Ceph | cephx obligatoire, msgr2 + chiffrement en transit, permissions 750/600 |

## Tests fonctionnels

`guest/func-test-pve.sh` verifie que le durcissement ne degrade pas PVE : Web UI,
API, authentification SSH par cle, services critiques, pare-feu, stockage, reseau,
noeud en ligne, taches, **creation puis destruction d'un conteneur LXC de test**,
depot de fichiers, certificats, journalisation. Les rapports avant/apres sont
integres au PDF : **0 echec fonctionnel** dans tous les cycles.

## Tracabilite et rollback

Chaque bloc de durcissement porte la reference du controle (guide PVE 9, IDs CIS
Debian 13, ANSSI). Un script de rollback est genere sur le noeud
(`/root/rollback-hardening.sh`) et l'image de reference `base-propre` permet de
revenir a la base saine entre deux tests.
