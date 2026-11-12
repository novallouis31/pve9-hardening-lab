# Validation croisee - reproductibilite des resultats

Le meme cycle de durcissement (CIS L1 + CIS L2 + ANSSI BP-028 N3 + Ceph)
a ete execute sur plusieurs VM Proxmox VE 9 **independantes**, chacune
depuis son snapshot \pristine\, pour verifier que les resultats ne
dependent pas d'un etat residuel de l'environnement.

| VM | PASS | FAIL | Compliance | Regressions | Echecs fonctionnels |
|---|---:|---:|---:|---:|---:|
| proxmox | 0 | 0 | 0 % | 0 | 0 |
| proxmox2 | 0 | 0 | 0 % | 0 | 0 |
| proxmox3 | 0 | 0 | 0 % | 0 | 0 |

Genere le 2026-11-12 16:16:50.
