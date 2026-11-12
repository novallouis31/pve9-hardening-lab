# Rapports de hardening - Proxmox VE 9

Cible : VM VirtualBox locale `pve` (PVE 9.2.2, Debian 13, noyau 7.0.2-6-pve, ext4).

Collecteurs (lecture seule, **111 controles** au total) :
- `guest/audit-pve.sh` — controles PVE / CIS de base (87)
- `guest/audit-cis13.sh` — controles CIS Debian 13 officiels, IDs du referentiel (19)
- `guest/audit-anssi.sh` — controles ANSSI (14)
- `guest/audit-ceph.sh` — controles Ceph (11)

Test fonctionnel : `guest/func-test-pve.sh` (21 tests de non-regression PVE).

## Resultats

| Rapport | Perimetre | PASS avant | PASS apres | Delta | Regressions | Reg. fonctionnelles |
|---|---|---:|---:|---:|---:|---:|
| [rapport-CIS-Level1.pdf](rapport-CIS-Level1.pdf) | CIS Debian 13 Level 1 + guide PVE 9 | 34 | **84** | **+50** | 0 | 0 |
| [rapport-CIS-Level2.pdf](rapport-CIS-Level2.pdf) | + politique FORWARD DROP / nftables | 33 | 84 | +51 | 0 | 0 |
| [rapport-delta-L1-vers-L2.pdf](rapport-delta-L1-vers-L2.pdf) | Ce qu'apporte le niveau 2 | 84 | 85 | +1 | 0 | 0 |
| [rapport-ANSSI-Level3.pdf](rapport-ANSSI-Level3.pdf) | ANSSI niveau 3 (AIDE, rsyslog, SSH root=no) | 34 | 43 | +9 | 0 | 0 |
| [rapport-Ceph.pdf](rapport-Ceph.pdf) | cephx, msgr2, permissions | 34 | 39 | +5 | 0 | 0 |

**Compliance CIS Level 1 : 89,4 %** (84/94 controles evaluables).
Sur le perimetre strict **CIS / OS / PVE / USR, la conformite atteint 100 %** : les
10 controles restants en echec sont `ANS.*` (6) et `CEPH.*` (4), qui relevent
d'autres guides et sont appliques par leurs propres niveaux.

## Contenu de chaque rapport

1. **Synthese** — KPI : PASS avant/apres, delta, regressions, tests fonctionnels
2. **Ameliorations** — controles passes de FAIL a PASS
3. **Controles en echec restants** — ce qui reste non conforme
4. **Recapitulatif complet** — chaque controle avec Avant / Apres / Evolution / Detail
5. **Tests fonctionnels avant / apres** — non-regression du fonctionnement PVE

## Tests fonctionnels (non-regression)

Deux suites sont executees **avant et apres** chaque cycle de durcissement, et
leurs resultats sont traces dans chaque PDF :

| Suite | Script | Objet | Volume |
|---|---|---|---|
| Proxmox | `guest/func-test-pve.sh` | le durcissement ne casse **pas Proxmox** | 21 tests |
| OS | `guest/func-test-os.sh` | le durcissement ne casse **pas l'OS** | 48 tests |

**Suite OS** (systemd, sysctl, montages, espace disque, DNS/routage, PAM, sudo,
comptes, cron, journald/rsyslog/auditd, AppArmor, dpkg/apt, noyau/limites,
horloge, locale). Elle est indispensable : un durcissement peut laisser
Proxmox intact tout en cassant l'OS (sysctl incoherent, PAM corrompu, cron
bloque, journalisation perdue) — ce que les seuls tests Proxmox ne
detecteraient pas.

Chaque PDF contient :
- la section **« Tests fonctionnels - synthese par suite (non-regression) »**
  (PASS avant/apres, FAIL avant/apres, regressions par suite) ;
- la section **« Tests fonctionnels - avant / apres durcissement »** avec le
  detail de chaque test et sa serie Proxmox ou OS ;
- les KPI dedies **« Non-regression Proxmox »** et **« Non-regression OS »**
  dans le bandeau de synthese.

Les tests PVE couvrent : Web UI (8006), API pvesh, authentification SSH par
cle, services critiques (pveproxy, pvedaemon, pvestatd, ssh), pare-feu PVE,
stockage (pvesm), reseau (interface, pont vmbr0, passerelle), noeud en ligne,
taches, **creation puis destruction d'un conteneur LXC de test**, depot de
fichiers (pveam), certificat TLS, journalisation.

Les tests OS couvrent : etat systemd et unites en echec, application effective
des sysctl, montages et options (`nosuid`/`nodev`/`noexec`), espace disque et
inodes, loopback / DNS / route par defaut, chaine PAM et authentification,
sudo, comptes et shells, cron (daemon, `cron.allow`, crontab), journald /
rsyslog / auditd, profils AppArmor, coherence dpkg et `apt-get check`, modules
noyau charges, limites (`ulimit -c`), synchronisation horaire, locale et
fuseau.

## Points cles

- Le durcissement ne casse pas le fonctionnement de Proxmox : verifie systematiquement.
- Les controles `NA` sont documentes comme tels : Secure Boot indisponible sous
  VirtualBox (firmware BIOS), chiffrement de disque hors perimetre d'installation,
  Ceph sans cluster local.
- Chaque modification machine est tracable jusqu'a la recommandation du guide
  PVE 9 / CIS Debian 13 via la reference de controle inscrite dans le script.
- Rollback : `/root/rollback-hardening.sh` genere sur le noeud, plus le snapshot
  VirtualBox `pristine` (restauration de la base saine entre deux cycles).

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
# Niveau 2 / ANSSI 3 / Ceph
powershell -File scripts\run-phase.ps1 -Phase apply -Target core  -Level 2
powershell -File scripts\run-phase.ps1 -Phase apply -Target anssi -Level 3
powershell -File scripts\run-phase.ps1 -Phase apply -Target ceph
```

Cycle complet (baseline + audit fonctionnel avant, durcissement, audit + audit
fonctionnel apres, rapport PDF) en une commande :

```powershell
powershell -File scripts\run-phase.ps1 -Phase all -Target core -Level 1 `
    -AuditExtra anssi,ceph,cis13 -RunFunc
```

Voir `docs/PLAN-DE-TEST.md` (protocole complet) et
`docs/DEPLOIEMENT-AUTOMATIQUE.md` (creation de la VM PVE sans intervention).
