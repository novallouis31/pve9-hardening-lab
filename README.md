# pve9-hardening-lab

Lab de test de hardening pour **Proxmox VE 9.x** sur une VM **VirtualBox** locale.

## Le projet retenu

[`HomeSecExplorer/Proxmox-Hardening-Guide`](https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide)
(version PVE 9, 580 etoiles, alignement CIS Debian 13 avec les deviations
Proxmox documentees). Detail du choix et des candidats ecartes :
[docs/CHOIX-PROJET.md](docs/CHOIX-PROJET.md).

## Structure

```
pve9-hardening-lab/
├── scripts/
│   ├── fetch-vendor.ps1     telecharge les projets, epinglés sur un commit SHA
│   ├── verify-vendor.ps1    verifie l'integrite (SHA256SUMS.txt)
│   ├── prepare-vm.ps1       configure la VM VirtualBox (RAM/CPU/disk/NAT/serie)
│   ├── vm-snapshot.ps1      create / list / restore / delete de snapshots
│   ├── run-phase.ps1        orchestrateur : bootstrap|baseline|apply|verify|all
│   └── compare.ps1          rapport de comparaison avant / apres
├── guest/
│   ├── audit-pve.sh         collecteur d'audit, LECTURE SEULE, ~60 controles
│   ├── apply-homesec-core.sh automatisation tracée du guide PVE 9
│   └── bootstrap-sshkey.sh  installe la cle publique du lab
├── vendor/                  artefacts des projets (generes par fetch-vendor.ps1)
├── answers/mrmasterbay.txt  reponses pour l'assistant interactif archive
├── docs/PLAN-DE-TEST.md     protocole complet en 8 etapes
└── docs/CHOIX-PROJET.md     analyse comparative des projets GitHub
```

## Demarrage rapide

```powershell
# 0. artefacts
powershell -ExecutionPolicy Bypass -File scripts\fetch-vendor.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-vendor.ps1

# 1. VM eteinte obligatoire
powershell -ExecutionPolicy Bypass -File scripts\prepare-vm.ps1

# 2. demarrer la VM, installer Proxmox VE 9.2 depuis l'ISO

# 3. injecter la cle SSH du lab
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase bootstrap

# 4. photographie avant hardening
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase baseline

# 5. filet de securite
powershell -ExecutionPolicy Bypass -File scripts\vm-snapshot.ps1 -Action Create -Name pre-hardening

# 6. appliquer (LEVEL=1 = CIS Debian 13 Level 1, par defaut)
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase apply -Target core

# 7. comparer et produire le rapport PDF
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase verify
```

## Principes de conception

- **Reproductible** : les projets sont figés sur des commits SHA et verifies par
  SHA256 ; la config VM est enregistree dans `vm-config.json`.
- **Reversible** : snapshot VirtualBox + `/root/rollback-hardening.sh` genere par
  le script de hardening + sauvegarde de chaque fichier touche.
- **Observe** : rien n'est applique sans un baseline avant, rien n'est affirme
  sans un audit apres. Les controles sont codes `PASS|FAIL|NA|INFO`, pas interpretes.
- **Conscient des contraintes du lab** : VirtualBox n'expose ni Secure Boot ni de
  virtualisation imbriquee, ces controles sont declarés N/A, pas passes sous silence.

## Limites connues

- Les deux depots avec script (`abualialfatih23`, `MrMasterbay`) sont des
  assistants **interactifs** ; le pilotage automatique passe par un PTY (`script`)
  et une sequence de reponses, qui peut se decaler si le depot evolue.
- Un seul noeud : les controles de cluster (§ 3.x), de Ceph et de PBS sont hors
  perimetre.
