# Rapports de hardening - Proxmox VE 9

Cible : VM VirtualBox locale `pve` (PVE 9.2.2, Debian 13, noyau 7.0.2-6-pve, ext4).

Collecteurs (lecture seule, **160 controles** au total) :
- `guest/audit-pve.sh` — controles PVE / CIS de base (67)
- `guest/audit-cis13.sh` — controles CIS Debian 13 officiels, IDs du referentiel (19)
- `guest/audit-anssi.sh` — controles ANSSI BP-028 (32)
- `guest/audit-ceph.sh` — controles Ceph (11)
- `guest/audit-communautaire.sh` — controles harbian-audit + BP-028 (31)

Tests fonctionnels : `guest/func-test-pve.sh` (21 tests Proxmox) et
`guest/func-test-os.sh` (48 tests OS).

## Resultats

| Rapport | Perimetre | PASS avant | PASS apres | Delta | Regressions | Reg. fonctionnelles |
|---|---|---:|---:|---:|---:|---:|
| [rapport-CIS-Level1.pdf](rapport-CIS-Level1.pdf) | CIS Debian 13 Level 1 + guide PVE 9 | 68 | 131 | **+63** | 0 | 0 |
| [rapport-CIS-Level2.pdf](rapport-CIS-Level2.pdf) | + politique DROP / nftables | 68 | 132 | **+64** | 0 | 0 |
| [rapport-delta-L1-vers-L2.pdf](rapport-delta-L1-vers-L2.pdf) | Ce qu'apporte le niveau 2 | 131 | 132 | +1 | 0 | 0 |
| [rapport-stack-complet.pdf](rapport-stack-complet.pdf) | **CIS L2 + ANSSI L3 + Ceph** | 68 | **146** | **+78** | 0 | 0 |
| [rapport-ANSSI-Level3.pdf](rapport-ANSSI-Level3.pdf) | ANSSI BP-028 niveau 3 seul | 34 | 43 | +9 | 0 | 0 |
| [rapport-Ceph.pdf](rapport-Ceph.pdf) | Ceph seul | 34 | 39 | +5 | 0 | 0 |
| [rapport-validation-proxmox.pdf](rapport-validation-proxmox.pdf) | Validation croisee (VM `proxmox`) | 67 | **145** | **+78** | 0 | 0 |
| [rapport-validation-proxmox3.pdf](rapport-validation-proxmox3.pdf) | Validation croisee (VM `proxmox3`) | 67 | **145** | **+78** | 0 | 0 |

### Validation croisee (reproductibilite)

Le meme cycle a ete execute sur des VM **independantes** : les deux aboutissent
a des resultats **strictement identiques** (145 PASS / 0 FAIL / 72 tests
fonctionnels / 5 perimetres a 100 %). Voir
[rapport-validation-croisee.md](rapport-validation-croisee.md).

### Conformite par perimetre (stack complet : CIS L2 + ANSSI L3 + Ceph)

| Perimetre | Controles | PASS avant | PASS apres | Echecs restants | Conformite |
|---|---:|---:|---:|---:|---:|
| CIS Debian 13 | 19 | 6 | 19 | 0 | **100 %** |
| ANSSI BP-028 | 32 | 15 | 32 | 0 | **100 %** |
| Ceph | 11 | 1 | 6 | 0 | **100 %** |
| Communautaire (harbian/BP-028) | 31 | 20 | 29 | 0 | **100 %** |
| PVE 9 / OS | 67 | 25 | 60 | 0 | **100 %** |
| **Total** | **160** | **68** | **146** | **0** | **100 %** |

Les 8 controles `NA` sont documentes : Secure Boot indisponible sous VirtualBox
(firmware BIOS), chiffrement de disque hors perimetre d'installation, Ceph sans
cluster local, et quelques controles non applicables a un hote Proxmox.

## Contenu de chaque rapport

1. **Synthese** — KPI : PASS avant/apres, delta, regressions, tests fonctionnels
   (ventiles Proxmox / OS)
2. **Ameliorations** — controles passes de FAIL a PASS
3. **Conformite par perimetre de guide** — CIS / ANSSI / Ceph / communautaire / PVE
4. **Recapitulatif complet** — chaque controle avec Avant / Apres / Evolution / Detail
5. **Tests fonctionnels - avant / apres durcissement** — 69 tests detailles
6. **Tests fonctionnels - synthese par suite (non-regression)** — PASS/FAIL par suite

## Tests fonctionnels (non-regression)

| Suite | Script | Objet | Resultat stack complet |
|---|---|---|---|
| Proxmox | `guest/func-test-pve.sh` | le durcissement ne casse **pas Proxmox** | 19/21 PASS, **0 FAIL**, 0 regression |
| OS | `guest/func-test-os.sh` | le durcissement ne casse **pas l'OS** | 47/48 PASS, **0 FAIL**, 0 regression |

**Suite Proxmox** : Web UI (8006), API pvesh, authentification SSH par cle,
services critiques (pveproxy, pvedaemon, pvestatd, ssh), pare-feu PVE, stockage
(pvesm), reseau (interface, pont vmbr0, passerelle), noeud en ligne, taches,
**creation puis destruction d'un conteneur LXC de test**, depot de fichiers
(pveam), certificat TLS, journalisation.

**Suite OS** : etat systemd et unites en echec, application effective des
sysctl, montages et options (`nosuid`/`nodev`/`noexec`), espace disque et
inodes, loopback / DNS / route par defaut, chaine PAM et authentification,
sudo, comptes et shells, cron (daemon, `cron.allow`, crontab), journald /
rsyslog / auditd, profils AppArmor, coherence dpkg et `apt-get check`, modules
noyau charges, limites (`ulimit -c`), synchronisation horaire, locale et
fuseau.

### Bugs fonctionnels reels detectes par la suite OS

| Symptome | Cause racine | Correctif |
|---|---|---|
| `fail2ban.service` en echec (`status=255`), OS `degraded` | filtre `proxmox` de fail2ban 1.x : `failregex` **sans groupe `<HOST>`** (`ERROR No failure-id group`) | filtre dedie `pveproxy` ecrit par le lab |
| idem | la regex JSON du filtre ne correspondait pas au format reel du log pveproxy (format Apache) | regex `401`/`403` au format Apache |
| idem | `port = https,http` generait une regle nftables `dport { https,http }` invalide | un port par jail |
| idem | jail ecrit via heredoc demarrant par un backslash litteral (`File contains no section headers`) | ecriture via `write_file` |

Ces 4 bugs etaient **invisibles** pour les seuls tests Proxmox : Proxmox
fonctionnait parfaitement, mais le service de protection de l'interface web etait
mort et l'OS etait en etat `degraded`.

## Points cles

- Le durcissement ne casse pas le fonctionnement de Proxmox **ni de l'OS** :
  verifie systematiquement par 69 tests fonctionnels avant/apres.
- Le controle `OS.SSHD.PERMITROOT` a impose de revoir la strategie root SSH :
  le guide PVE 9 **interdit** `PermitRootLogin no` sur Proxmox et recommende
  l'**option B** (restriction au sous-reseau de management), appliquee ici.
- Chaque modification machine est tracable jusqu'a la recommandation du guide
  PVE 9 / CIS Debian 13 / ANSSI BP-028 / checks harbian-audit via la reference
  de controle inscrite dans le script.
- Rollback : `/root/rollback-hardening.sh` genere sur le noeud, plus le snapshot
  VirtualBox `pristine` (restauration de la base saine entre deux cycles).

## Sources de reference

| Source | Usage |
|---|---|
| `HomeSecExplorer/Proxmox-Hardening-Guide` (581*) | guide PVE 9 / CIS Debian 13, sections Ceph 3.3-3.5, option B root SSH |
| `ansible-lockdown/DEBIAN13-CIS` (29*) | IDs et seuils CIS Debian 13 officiels (PAM, umask, permissions) |
| `Makaveli81/ansible-linux-hardening` (59*) | audit_items ANSSI BP-028 (niveaux M/I/R/E) |
| `hardenedlinux/harbian-audit` (472*) | 284 checks Debian durcis (sysctl, sudoers, comptes, SSH) |
| `abualialfatih23/PVE-9-Hardening` (17*) | cible de comparaison (niveaux 1-5) |
| `alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9` (78*) | reference SSH PVE 9 |
| `MrMasterbay/proxmox-security-hardening` (114*) | cible de rupture (depot archive) |

## Reproduction

```powershell
# Niveau 1 (par defaut)
powershell -File scripts\\run-phase.ps1 -Phase apply -Target core -Level 1
# Niveau 2 / ANSSI 3 / Ceph
powershell -File scripts\\run-phase.ps1 -Phase apply -Target core  -Level 2
powershell -File scripts\\run-phase.ps1 -Phase apply -Target anssi -Level 3
powershell -File scripts\\run-phase.ps1 -Phase apply -Target ceph
```

Cycle complet (baseline + audit fonctionnel avant, durcissement, audit + audit
fonctionnel apres, rapport PDF) en une commande :

```powershell
powershell -File scripts\\run-phase.ps1 -Phase all -Target core -Level 2 `
    -AuditExtra anssi,ceph,cis13,communautaire -RunFunc
```

Voir `docs/PLAN-DE-TEST.md` (protocole complet) et
`docs/DEPLOIEMENT-AUTOMATIQUE.md` (creation de la VM PVE sans intervention).
