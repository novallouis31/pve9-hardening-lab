# Choix du projet de hardening Proxmox VE 9

Recherche effectuee sur GitHub le 10-11/11/2026 (mots-cles : `proxmox hardening`,
`pve hardening`, `proxmox security script`, `proxmox cis benchmark`, `proxmox postinstall`,
soit ~150 depots examines). Cinq candidats ont ete retenus pour analyse detaillee.

## Classement final

| Rang | Depot | Etoiles | Dernier push | Type | Verdict |
|---|---|---:|---|---|---|
| **1** | [`HomeSecExplorer/Proxmox-Hardening-Guide`](https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide) | 580 | 2026-02-09 | Guide | **Projet principal** |
| **2** | [`abualialfatih23/PVE-9-Hardening`](https://github.com/abualialfatih23/PVE-9-Hardening) | 17 | 2025-12-20 | Script automatise | **Comparaison automatisee** |
| **3** | [`alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9`](https://github.com/alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9) | 78 | 2026-08-02 | Guide SSH | Reference ponctuelle |
| **4** | [`MrMasterbay/proxmox-security-hardening`](https://github.com/MrMasterbay/proxmox-security-hardening) | 114 | 2026-01-07 | Script agressif | Test de rupture |
| — | `Leox1024/homelab-ansible-ops` | 104 | 2026-11-02 | Playbooks Ansible | Ecarte (hors PVE hardening) |
| — | `community-scripts/ProxmoxVE` | 30 088 | 2026-11-10 | Scripts LXC | Ecarte (installers, pas du hardening) |

## Pourquoi le depot HomeSecExplorer en tete

1. **Couverture PVE 9 dediee** : un guide `docs/pve9-hardening-guide.md` de 62 ko,
   version 0.9.2, arborescence en 5 familles de controles (1 Initial Setup,
   2 Users/API/GUI, 3 Cluster, 4 Backup/DR, 5 Logging/Auditing), 55 recommandations
   numerotees et levelisees.
2. **Alignement CIS Debian 13** avec les deviations Proxmox documentees (c'est la
   valeur ajoutee la plus rare) :
   - § 5.1.21 *Disable SSH root login* **a ne pas appliquer** sur un cluster PVE
     (migration live et repli d'ailleurs) -> alternative `PermitRootLogin prohibit-password`.
   - § 1.1.1.11 : `fuse` et `ceph` **ne doivent pas** etre neutralises.
   - § 5.1.8 *DisableForwarding* casse la migration live -> alternative par `Match`.
   - § 4 *Host-Based Firewall* a remplacer par le pare-feu PVE.
3. **Licence CC BY 4.0**, contributions ouvertes, depose non archivee.
4. **Ne modifie rien automatiquement** : chaque controle est un choix documente.
   Pour un test de hardening c'est l'approche la plus saine, et c'est ce que notre
   script `apply-homesec-core.sh` exploite : il applique et **trace** chaque
   reference de controle (`1.2.4`, `5.1.2`, etc.).
5. Le projet demande explicitement de l'aide pour **valider en lab** certains
   controles non verifies : c'est exactement ce que le present lab fait.

## Pourquoi le depot abualialfatih23 en second

- **Cible exactement votre cas** : son README indique avoir ete teste sur des
  clusters PVE simules sous **VirtualBox**, un noeud par VM, sans virtualisation
  imbriquee — le meme scenario que le votre.
- Le script implémente un modele **a niveaux** (1 a 5), ce qui permet de tester
  une montee progressive et d'observer ce qui casse a chaque palier.
- Signal de prudence : **aucune release**, depot de 17 etoiles, aucune licence
  declaree, `set -e` sans filet. Il faut le tester derriere un snapshot.

## Pourquoi MrMasterbay en dernier

- **Depot archive** sur GitHub (plus de developpement).
- Script de 5 091 lignes tres invasif : cree des comptes, active le 2FA, coupe
  l'acces root SSH hors liste blanche, installe fail2ban, ClamAV, AIDE, STIG...
- Utile **uniquement** comme test de rupture ("qu'est-ce qui casse ?"), jamais
  comme baseline. Assimiler ce script a un guide d'exploitation serait une erreur.

## Reperes de version retenus

| Depot | Commit epinglé | Date | Release |
|---|---|---|---|
| HomeSecExplorer | `d630ff29ca5f89db2a9b416e88634d385fa7f708` | 2026-02-09 | 0.9.5 |
| abualialfatih23 | `c9909d0422a77f89ea3d5ebc61ca4284bacd0b5a` | 2025-12-20 | — |
| alexandreravelli | `c35a64617523299fa4e5396a72016973f6422510` | 2026-08-02 | v1.0.0 |
| MrMasterbay | `44e0154bedfa5ecde2f557710c7108fc734c423e` | 2026-01-07 | — |

Les artefacts sont telecharges sur ces commits precis par `scripts/fetch-vendor.ps1`
et verifies par `scripts/verify-vendor.ps1` (`vendor/SHA256SUMS.txt`). Rien ne peut
donc changer entre deux executions du lab.
