# Rapports de hardening - Proxmox VE 9

Cible : VM VirtualBox locale `pve` (PVE 9.2.2, Debian 13, noyau 7.0.2-6-pve).

Collecteurs (lecture seule) :
- `guest/audit-pve.sh` — controles PVE/CIS de base
- `guest/audit-cis13.sh` — controles CIS Debian 13 officiels (IDs et seuils du referentiel)
- `guest/audit-anssi.sh` — controles ANSSI
- `guest/audit-ceph.sh` — controles Ceph

Test fonctionnel : `guest/func-test-pve.sh` (21 tests de non-regression PVE).

## Resultats

| Rapport | Perimetre | PASS avant | PASS apres | Delta | Regressions |
|---|---|---:|---:|---:|---:|
| [rapport-CIS-Level1.pdf](rapport-CIS-Level1.pdf) | CIS Debian 13 Level 1 + guide PVE 9 | 27 | 61 | +34 | 0 |
| [rapport-CIS-Level2.pdf](rapport-CIS-Level2.pdf) | CIS Level 1+2 (FORWARD DROP/nftables, auditd, rkhunter) | 26 | 47 | +21 | 0 |
| [rapport-delta-L1-vers-L2.pdf](rapport-delta-L1-vers-L2.pdf) | Ce qu'apporte le niveau 2 au-dessus du niveau 1 | 45 | 47 | +2 | 0 |
| [rapport-ANSSI-Level3.pdf](rapport-ANSSI-Level3.pdf) | ANSSI niveau 3 (AIDE, rsyslog, SSH root=no) | 47 | 56 | +9 | 0 |
| [rapport-Ceph.pdf](rapport-Ceph.pdf) | Durcissement Ceph (cephx, msgr2, permissions) | 47 | 51 | +4 | 0 |

Chaque rapport contient :

- **Synthese** (KPI : PASS avant/apres, delta, regressions, tests fonctionnels)
- **Tests fonctionnels** avant/apres durcissement (21 tests : Web UI, API, SSH, services critiques, pare-feu, stockage, reseau, cycle de vie d'un conteneur LXC, taches, journalisation)
- **Ameliorations** et **Controles en echec restants**
- **Recapitulatif complet** : chaque controle avec Avant / Apres / Evolution / Detail

## Points cles

- Aucune regression : le durcissement ne casse pas le fonctionnement de PVE, verifie par
  les tests fonctionnels (y compris la creation puis la destruction d'un conteneur LXC de test).
- Les controles `NA` sont documentes comme tels : Secure Boot indisponible sous VirtualBox
  (firmware BIOS), chiffrement de disque hors perimetre d'installation, Ceph sans cluster local.
- Chaque modification machine est tracable jusqu'a la recommandation du guide PVE 9 via la
  reference de controle inscrite dans `guest/apply-homesec-core.sh`.
- Rollback : `/root/rollback-hardening.sh` genere sur le noeud, plus l'image de reference
  VirtualBox `base-propre` (restauration par clonage complet du disque).

## Sources de reference

| Source | Usage |
|---|---|
| `HomeSecExplorer/Proxmox-Hardening-Guide` (581*) | guide PVE 9 / CIS Debian 13, sections Ceph 3.3-3.5 |
| `ansible-lockdown/DEBIAN13-CIS` (29*) | IDs et seuils CIS Debian 13 officiels (PAM, umask, permissions) |
| `abualialfatih23/PVE-9-Hardening` (17*) | cible de comparaison (niveaux 1-5) |
| `alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9` (78*) | reference SSH PVE 9 |
| `MrMasterbay/proxmox-security-hardening` (114*) | cible de rupture (depot archive) |

## Reproduction

```powershell
# Niveau 1 (par defaut)
powershell -File scripts\run-phase.ps1 -Phase apply -Target core -Level 1
# Niveau 2
powershell -File scripts\run-phase.ps1 -Phase apply -Target core -Level 2
# ANSSI niveau 3
powershell -File scripts\run-phase.ps1 -Phase apply -Target anssi -Level 3
# Ceph
powershell -File scripts\run-phase.ps1 -Phase apply -Target ceph
```

Le cycle complet (baseline + audit fonctionnel avant, apply, verify + audit fonctionnel
apres + rapport PDF) se fait en une fois :

```powershell
powershell -File scripts\run-phase.ps1 -Phase all -Target core -Level 1 `
    -AuditExtra anssi,ceph,cis13 -RunFunc
```

Voir `docs/PLAN-DE-TEST.md` pour le protocole complet.
