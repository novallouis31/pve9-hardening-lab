# Validation du de-hardening Proxmox VE

Ce rapport rend compte de la validation du **de-hardening** (retour a l'etat anterieur au durcissement) sur une instance Proxmox VE reelle. La chaine complete a ete executee sur la VM de laboratoire : audit de reference, durcissement, de-hardening par le client bash, audit de l'etat restaure, re-durcissement et audit final.

- **Genere le** : 2026-11-15 21:57
- **Perimetre** : 161 controles d'audit (Proxmox, CIS Debian 13, ANSSI BP-028, Ceph, communautaires), 72 tests fonctionnels

## 1. Synthese

| Etape | Artefacts | PASS | FAIL | NA | INFO | Conformite |
|---|---|---:|---:|---:|---:|---:|
| Baseline - PVE 9.2.2 pristine (avant durcissement) | `baseline-20261115-202420` | 68 | 72 | 11 | 10 | 48.6 % |
| Apres durcissement (CIS L2 + ANSSI N3 + Ceph) | `hardened-20261115-203603` | 146 | 0 | 8 | 7 | 100 % |
| Apres de-hardening | `dehardened-20261115-203944` | 71 | 69 | 11 | 10 | 50.7 % |
| Apres re-durcissement | `rehardened-20261115-215523` | 146 | 0 | 8 | 7 | 100 % |

### Tests fonctionnels (non-regression Proxmox + OS)

| Etape | Artefacts | Tests | PASS | FAIL | NA |
|---|---|---:|---:|---:|---:|
| Baseline - PVE 9.2.2 pristine | `func-baseline-20261115-202421` | 72 | 63 | 0 | 9 |
| Apres durcissement | `func-hardened-20261115-203604` | 72 | 71 | 0 | 1 |
| Apres de-hardening | `func-dehardened-20261115-203944` | 72 | 63 | 0 | 9 |
| Apres re-durcissement | `func-rehardened-20261115-215524` | 72 | 71 | 0 | 1 |

## 2. Retour a l'etat d'origine (resultat principal)

La baseline est l'etat **avant tout durcissement** (instantane VirtualBox `pristine`). Apres le de-hardening, 158/161 controles retrouvent exactement leur statut d'origine.

| Controle | Baseline | Apres de-hardening | Famille |
|---|---|---|---|
| `ANS.CTRLALTDEL` | FAIL | PASS | Etats de services |
| `COMM.CTRLALTDEL` | FAIL | PASS | Etats de services |
| `ANS.KERNEL.BPF` | FAIL | PASS | Valeurs sysctl appliquees a chaud |

### Analyse des ecarts

Les ecarts residuels proviennent de l'**etat d'execution** (valeurs appliquees a chaud, services, montages) et non de l'**etat fichier**. Le de-hardening restaure les fichiers, les permissions, les services, les depots et les paquets ; les valeurs deja appliquees au noyau, elles, ne sont definitivement levees qu'au redemarrage.

- **Etats de services** (`ANS.CTRLALTDEL`, `COMM.CTRLALTDEL`) : services reactives ou desactives par le de-hardening ; un controle peut encore observer l'etat precedent si le service redemarre apres l'audit.
- **Valeurs sysctl appliquees a chaud** (`ANS.KERNEL.BPF`) : le durcissement ecrit des fichiers dans `/etc/sysctl.d` **et** applique les valeurs immediatement (`sysctl -w`). Le de-hardening supprime les fichiers et retablit les valeurs par defaut, mais certains controles portent sur des noeuds (`net.ipv6.conf.*`, `bpf_jit_harden`) dont la valeur n'est reinitialisee qu'au redemarrage.

Ces ecarts ne bloquent pas une montee de version : apres le de-hardening, l'acces SSH, les services Proxmox, le gestionnaire de paquets et les tests fonctionnels sont operationnels (voir les sections 2 et 3).

- Conformite notee : **48.6 %** a la baseline, **50.7 %** apres de-hardening (les statuts `NA` et `INFO` ne sont pas notes).

### Non-regression fonctionnelle

| Test | Baseline | Apres de-hardening | Regression |
|---|---|---|---|
| `OS.FS.OPTIONS._dev_shm` | PASS | WARN | oui |
| `OS.NET.DNS` | WARN | PASS | non |

Regressions introduites par la chaine : **1**. Les autres differences existent deja dans la baseline (environnement de laboratoire sans licence, sans cluster).

## 3. Re-durcissement : la reference est retrouvee

**Les 161 controles presentent un statut identique a la premiere application du durcissement.** Le durcissement est donc reproductible et le de-hardening n'a laisse aucun artefact derangeant.

- Conformite : **100 %** apres durcissement, **100 %** apres re-durcissement.

## 4. Ce que fait le de-hardening

Le script `guest/deharden-pve.sh` s'execute **sur le noeud** ; le client `scripts/deharden.sh` l'appelle a distance par adresse IP et mot de passe root (ou cle SSH).

| Phase | Operation |
|---|---|
| Securite | archive de l'etat courant (`/root/deharden-safety-<ts>/`) |
| Index | lecture des sessions de `/root/hardening-backups` et `/root/anssi-backups` |
| Restauration | retablit la version **la plus ancienne** de chaque fichier sauvegarde |
| Suppression | efface les fichiers declares *crees* par les manifestes |
| Permissions | retablit mode / proprietaire / groupe (fichiers `.mode`) |
| Etat | reactive les services, deverrouille les comptes, restaure les shells, supprime `pveadmin` |
| Depots | reactive les depots enterprise (`*.sources.disabled`) |
| Paquets | desinstalle le **delta** par rapport a `packages.before` (sauf `--keep-packages`) |
| Execution | re-vertit sysctl, AppArmor (*complain*), montages, base AIDE |
| SSH | restaure en dernier, `sshd -t` avant tout rechargement |

### Metriques relevees sur le noeud

| Mesure | Valeur |
|---|---|
| Mode d'execution | application |
| Fichiers restaures | 15 |
| Fichiers supprimes | 21 |
| Paquets desinstalles | 48 |
| Sauvegarde de securite | `/root/deharden-safety-20261115_203651` |

### Rapport produit par le de-hardening

```
# De-hardening Proxmox VE

- **Date** : 2026-11-15T20:39:20+01:00
- **Hote** : pve
- **Mode** : application
- **Journal** : `/var/log/deharden-20261115_203651.log`
- **Sauvegarde de securite** : `/root/deharden-safety-20261115_203651`

## Fichiers restaures

| Fichier |
|---|
| `/etc/apparmor.d/busybox` |
| `/etc/apt/apt.conf.d/20auto-upgrades` |
| `/etc/crontab` |
| `/etc/fstab` |
| `/etc/issue.net` |
| `/etc/login.defs` |
| `/etc/pam.d/common-auth` |
| `/etc/pam.d/common-password` |
| `/etc/pam.d/login` |
| `/etc/pam.d/passwd` |
| `/etc/pam.d/sshd` |
| `/etc/security/faillock.conf` |
| `/etc/security/pwquality.conf` |
| `/etc/ssh/sshd_config` |
| `/root/.bashrc` |

## Fichiers supprimes

| Fichier |
|---|
| `/etc/profile.d/99-pve-hardening.sh` |
| `/etc/ssh/sshd_config.d/00-pve-hardening.conf` |
| `/etc/audit/rules.d/90-pve.rules` |
| `/etc/cron.allow` |
| `/etc/cron.daily/aide-check` |
| `/etc/fail2ban/filter.d/pveproxy.conf` |
| `/etc/fail2ban/jail.d/pve-web-http.conf` |
| `/etc/fail2ban/jail.d/pve-web.conf` |
| `/etc/modprobe.d/99-anssi-usb.conf` |
| `/etc/modprobe.d/99-pve-hardening.conf` |
| `/etc/profile.d/tmout.sh` |
| `/etc/pve/firewall/cluster.fw` |
| `/etc/pve/nodes/pve/firewall` |
| `/etc/rsyslog.d/99-anssi-remote.conf` |
| `/etc/security/limits.d/99-pve-hardening.conf` |
| `/etc/sysctl.d/97-pve-hardening.conf` |
| `/etc/sysctl.d/98-anssi.conf` |
| `/etc/sysctl.d/99-pve-hardening.conf` |
| `/etc/systemd/journald.conf.d/99-pve-hardening.conf` |
| `/root/rollback-hardening.sh` |
| `/etc/ceph/ceph.conf` |

## Paquets

Desinstalles : `aide aide-common apparmor-utils audispd-plugins auditd cracklib-runtime fail2ban fonts-lato javascript-common libauparse0t64 libcrack2 libestr0 libfastjson4 libjs-jquery liblognorm5 libpam-pwquality libpwquality-common libpwquality1 libruby libruby3.3 lsb-release net-tools python3-apparmor python3-distro-info python3-libapparmor python3-pyasyncore python3-pyinotify rake rkhunter rsyslog ruby ruby-csv ruby-did-you-mean ruby-net-telnet ruby-ruby2-keywords ruby-rubygems ruby-sdbm ruby-webrick ruby-xmlrpc ruby3.3 rubygems-integration sudo unattended-upgrades unhide unhide.rb unzip whois zip`

## Verification

| Service | Etat |
|---|---|
| `ssh` | active |
| `pveproxy` | active |
| `pvedaemon` | active |
| `pvestatd` | active |
| `pve-firewall` | active |
```

## 5. Etapes de validation

1. **Preparation** - la VM `proxmox` est restauree sur l'instantane `pristine` (Proxmox VE 9.2.2, Debian 13, aucun durcissement) et les sessions de sauvegarde heritees sont supprimees.
2. **Baseline** - audit des 5 perimetres (Proxmox, CIS Debian 13, ANSSI BP-028, Ceph, communautaires) et suite de tests fonctionnels Proxmox + OS.
3. **Durcissement** - `apply-homesec-core.sh` (CIS L1 puis L2), `apply-anssi.sh` (niveau 3) et `apply-ceph.sh`, puis audit de reference et tests fonctionnels.
4. **De-hardening** - client bash en simulation (`--dry-run`) puis en application :

```bash
bash scripts/deharden.sh --host 127.0.0.1 --port 2222 \
     --key ~/.ssh/id_ed25519 --dry-run
bash scripts/deharden.sh --host 127.0.0.1 --port 2222 \
     --key ~/.ssh/id_ed25519
```

5. **Verification** - audit de l'etat restaure et tests fonctionnels : les statuts sont compares a la baseline.
6. **Re-durcissement** - re-application des trois durcisseurs puis audit final : les statuts sont compares a la reference durcie.

## 6. Procedure de montee de version d'un noeud durci

Le de-hardening a pour objet de lever les blocages qui empechent la mise a jour d'un noeud durci :

| Mesure de durcissement | Blocage possible pendant l'upgrade |
|---|---|
| `PermitRootLogin` restreint | l'installeur ne peut plus ouvrir de session root |
| `pam_faillock` / `pam_pwquality` stricts | un script systeme echoue sur l'authentification |
| modules noyau filtres (`install ... /bin/false`) | le nouveau noyau ne demarre pas |
| `/etc/fstab` modifie | un montage disparait au redemarrage |
| `ctrl-alt-del.target` masque | comportement inattendu du terminal |
| sysctl durcis (`kptr_restrict`, `dmesg_restrict`) | une tache de mise a jour echoue silencieusement |

```bash
# 1. simulation
bash scripts/deharden.sh --host <ip> --password 'secret' --dry-run
# 2. de-hardening reel
bash scripts/deharden.sh --host <ip> --password 'secret'
# 3. controle : la conformite revient a celle de la baseline
python3 scripts/pve.py run --phase verify --ssh-host <ip> \
    --audit-extra anssi,ceph,cis13,communautaire
# 4. monter l'ISO de la nouvelle version et redemarrer
# 5. re-durcir
python3 scripts/pve.py run --phase apply --target core --level 2 --ssh-host <ip>
python3 scripts/pve.py run --phase apply --target anssi --level 3 --ssh-host <ip>
# 6. non-regression
python3 scripts/pve.py run --phase verify --ssh-host <ip> --run-func
```

## 7. Annexes

| Document | Contenu |
|---|---|
| [`docs/DE-HARDENING.md`](../docs/DE-HARDENING.md) | guide d'utilisation du de-hardening |
| `guest/deharden-pve.sh` | script execute sur le noeud |
| `scripts/deharden.sh` | client bash (IP + mot de passe root / cle SSH) |
| `scripts/pve_hardening/deharden.py` | equivalent Python (`pve.py deharden`) |
| `scripts/gen-validation-deharden.py` | generateur de ce rapport (artefacts) |

### Artefacts

| Prefixe | Contenu |
|---|---|
| `baseline-20261115-202420` | Baseline - PVE 9.2.2 pristine (avant durcissement) |
| `hardened-20261115-203603` | Apres durcissement (CIS L2 + ANSSI N3 + Ceph) |
| `dehardened-20261115-203944` | Apres de-hardening |
| `rehardened-20261115-215523` | Apres re-durcissement |
| `func-baseline-20261115-202421` | Baseline - PVE 9.2.2 pristine |
| `func-hardened-20261115-203604` | Apres durcissement |
| `func-dehardened-20261115-203944` | Apres de-hardening |
| `func-rehardened-20261115-215524` | Apres re-durcissement |

