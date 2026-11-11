# Rapports de hardening - Proxmox VE 9

Cible : VM VirtualBox locale `proxmox` (PVE 9.2.2, Debian 13, noyau 7.0.2-6-pve).
Collecteur : `guest/audit-pve.sh` (lecture seule, ~67 controles codes PASS/FAIL/NA/INFO).

## Resultats

| Rapport | Perimetre | PASS avant | PASS apres | Delta | Regressions |
|---|---|---:|---:|---:|---:|
| [rapport-CIS-Level1.pdf](rapport-CIS-Level1.pdf) | CIS Debian 13 Level 1 + guide PVE 9 § 1.2.4 (pare-feu) | 26 | 45 | +19 | 0 |
| [rapport-CIS-Level2.pdf](rapport-CIS-Level2.pdf) | CIS Debian 13 Level 1+2 (FORWARD DROP/nftables, auditd sur /etc/pve, rkhunter, umask 027) | 26 | 47 | +21 | 0 |
| [rapport-ANSSI-Level3.pdf](rapport-ANSSI-Level3.pdf) | ANSSI niveau 3 (renforce) au-dessus de CIS L2 | 47 | 56 | +9 | 0 |
| [rapport-Ceph.pdf](rapport-Ceph.pdf) | Durcissement Ceph (config client + permissions) | 47 | 51 | +4 | 0 |

## Points cles

- Aucune regression sur les trois niveaux testes.
- Les controles declares `NA` (firmware BIOS -> Secure Boot non applicable, chiffrement de disque hors perimetre niveau 1) sont documentes comme tels.
- Chaque modification machine est tracable jusqu'a la recommandation du guide PVE 9 via la reference de controle (ex. `1.2.4`, `5.1.21`) inscrite dans `guest/apply-homesec-core.sh`.
- Rollback : `/root/rollback-hardening.sh` genere sur le noeud, plus snapshot VirtualBox `pre-hardening`.

## Note Ceph

Le cluster Ceph n'est pas deploye dans cette VM (uniquement les bibliotheques client).
Le rapport Ceph couvre donc le durcissement de la configuration client (`/etc/ceph/ceph.conf`,
cephx, msgr2 en mode secure, permissions des keyrings) ; les controles `CEPH.CLUSTER`
et `CEPH.DASHBOARD` sont marques `NA`. Pour un durcissement complet d'un cluster Ceph,
deployer d'abord un cluster (`pveceph init` + OSD) puis relancer avec un niveau de
durcissement adapte.

```powershell
# Niveau 1 (par defaut)
powershell -File scripts\run-phase.ps1 -Phase apply -Target core -Level 1
# Niveau 2
powershell -File scripts\run-phase.ps1 -Phase apply -Target core -Level 2
```

Voir `docs/PLAN-DE-TEST.md` pour le protocole complet.
