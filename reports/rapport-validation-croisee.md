# Validation croisee - reproductibilite des resultats

Le meme cycle de durcissement (CIS L1 + CIS L2 + ANSSI BP-028 N3 + Ceph) a ete
execute sur plusieurs VM Proxmox VE 9 **independantes**, chacune departing de
son snapshot `pristine`, afin de verifier que les resultats ne dependent pas
d'un etat residuel de l'environnement.

## Resultats

| VM | PASS | FAIL | Compliance | Regressions | Echecs fonctionnels |
|---|---:|---:|---:|---:|---:|
| `proxmox`  | 145 | 0 | **100 %** | 0 | 0 |
| `proxmox3` | 145 | 0 | **100 %** | 0 | 0 |
| `proxmox2` | 145 | 0 | **100 %** | 0 | 0 |

Les trois VM partent de la **meme baseline** (67 PASS / 72 FAIL / 160 controles)
et aboutissent au **meme resultat** (145 PASS / 0 FAIL).

## Conformite par perimetre (identique sur les 3 VM)

| Perimetre | Controles | PASS apres | Echecs restants | Conformite |
|---|---:|---:|---:|---:|
| CIS Debian 13 | 19 | 19 | 0 | **100 %** |
| ANSSI BP-028 | 32 | 32 | 0 | **100 %** |
| Ceph | 11 | 6 | 0 | **100 %** |
| Communautaire (harbian-audit / BP-028) | 31 | 29 | 0 | **100 %** |
| PVE 9 / OS | 67 | 59 | 0 | **100 %** |
| **Total** | **160** | **145** | **0** | **100 %** |

## Non-regression fonctionnelle (identique sur les 3 VM)

| Suite | Tests | PASS av. | PASS ap. | FAIL av. | FAIL ap. | WARN av. | WARN ap. | NA av. | NA ap. | Regression | Controle somme |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Proxmox | 23 | 22 | 22 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | OK (23/23) |
| OS | 49 | 40 | 49 | 1 | 0 | 4 | 0 | 4 | 0 | 0 | OK (49/49) |
| **TOTAL** | **72** | **62** | **71** | **1** | **0** | **5** | **1** | **4** | **0** | **0** | av.=72/72 ap.=72/72 OK |

La colonne **« Controle somme »** verifie que la somme des statuts (PASS +
FAIL + WARN + NA) egale le nombre total de tests : aucune categorie n'est
 masquee et aucun test n'est « perdu ».

## Conditions de reproductibilite

La reproductibilite a exige la correction de plusieurs problemes **d'outillage**
(decouverts par la validation croisee elle-meme) :

| Probleme | Symptome | Correctif |
|---|---|---|
| DNS corporate non route par le NAT VirtualBox | `apt-get update` echoue, aucun paquet installable | bascule sur le DNS interne du NAT (10.0.2.3) |
| Listes apt a zero octet mises en cache | `apt-get update` annonce « Hit » sans rien retelecharger, `Unable to locate package` | purge des index vides avant chaque `update` |
| Fichier de transfert tronque sur la VM | script **vide** execute sans rien faire, cycle bloque a l'infini | verification SHA256 + taille de chaque copie |
| Message de succes du transfert sur stderr | PowerShell 5.1 le transforme en erreur bloquante | message sur stdout |
| `authorized_keys` ecrit dans le fichier **partage** Proxmox | la restauration de snapshot supprime la cle du lab | reinjection automatique a chaque cycle + repli par mot de passe |
| Snapshot restaure a chaud | le guest reste sans reseau, le cycle echoue au verify | arret systematique de la VM avant `snapshot restore` |

Ces corrections sont dans `guest/apply-homesec-core.sh`, `guest/apply-anssi.sh`,
`scripts/ssh-tool.py` et `scripts/pve.py run`.

## Rapports PDF

| Rapport | Contenu |
|---|---|
| [rapport-validation-proxmox.pdf](rapport-validation-proxmox.pdf) | cycle complet sur `proxmox` |
| [rapport-validation-proxmox2.pdf](rapport-validation-proxmox2.pdf) | cycle complet sur `proxmox2` |
| [rapport-validation-proxmox3.pdf](rapport-validation-proxmox3.pdf) | cycle complet sur `proxmox3` |

Genere le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').
