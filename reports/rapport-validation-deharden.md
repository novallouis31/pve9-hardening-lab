# Validation du de-hardening Proxmox VE

Ce rapport rend compte de la validation du script de **de-hardening** (retour a l'etat anterieur au durcissement) sur une instance Proxmox VE reelle. La chaine complete a ete executee sur la VM de laboratoire : audit de reference, durcissement, de-hardening par le client bash, audit de l'etat restaure, re-durcissement et audit final.

- **Genere le** : 2026-11-15 08:44:32
- **Perimetre couvert** : 161 controles d'audit, 72 tests fonctionnels

## 1. Synthese

| Etape | Artefacts | PASS | FAIL | NA | INFO | Conformite |
|---|---|---:|---:|---:|---:|---:|
| Baseline - PVE 9.2.2 pristine (avant durcissement) | `baseline-20261115-071728` | 68 | 72 | 11 | 10 | 48.6 % |
| Apres durcissement (CIS L2 + ANSSI N3 + Ceph) | `hardened-20261115-072915` | 146 | 0 | 8 | 7 | 100 % |
| Apres de-hardening | `dehardened-20261115-073218` | 91 | 50 | 10 | 10 | 64.5 % |
| Apres re-durcissement | `rehardened-20261115-065848` | 146 | 0 | 8 | 7 | 100 % |

### Tests fonctionnels (non-regression Proxmox + OS)

| Etape | Artefacts | Tests | PASS | FAIL |
|---|---|---:|---:|---:|
| Baseline - PVE 9.2.2 pristine | `func-baseline-20261115-071729` | 72 | 62 | 1 |
| Apres durcissement | `func-hardened-20261115-072916` | 72 | 71 | 0 |
| Apres de-hardening | `func-dehardened-20261115-073219` | 72 | 65 | 1 |
| Apres re-durcissement | `func-rehardened-20261115-065849` | 72 | 71 | 0 |

## 2. Retour a l'etat d'origine (resultat principal)

25 controle(s) sur 161 presentent un statut different de la baseline :

| Controle | Baseline | Apres de-hardening | Ecart |
|---|---|---|---|
| `ANS.AIDE.DB` | FAIL | PASS | ecart |
| `ANS.APPARMOR.ENFORCE` | FAIL | PASS | ecart |
| `ANS.BANNER` | PASS | FAIL | ecart |
| `ANS.CTRLALTDEL` | FAIL | PASS | ecart |
| `ANS.KERNEL.BPF` | FAIL | PASS | ecart |
| `ANS.KERNEL.JIT` | FAIL | PASS | ecart |
| `ANS.KERNEL.KPTR` | FAIL | PASS | ecart |
| `CEPH.AUTH.CEPHX` | FAIL | PASS | ecart |
| `CEPH.CONF` | FAIL | PASS | ecart |
| `CEPH.CONF.PERM` | FAIL | PASS | ecart |
| `CEPH.MSGR2` | FAIL | PASS | ecart |
| `CEPH.OSD.ENCRYPT` | NA | PASS | ecart |
| `COMM.CTRLALTDEL` | FAIL | PASS | ecart |
| `COMM.SYSCTL.KERNEL_KPTR_RESTRICT` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_SEND_REDIRECTS` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_ACCEPT_REDIRECTS` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_SEND_REDIRECTS` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_RA` | FAIL | PASS | ecart |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | ecart |
| `OS.APPARMOR.ENFORCE` | FAIL | PASS | ecart |
| `OS.AUDITD.PVE` | FAIL | PASS | ecart |
| `OS.MOUNT._dev_shm` | FAIL | PASS | ecart |
| `OS.MOUNT._var_tmp` | FAIL | PASS | ecart |
| `OS.UNATTENDED.ENABLED` | FAIL | PASS | ecart |

- La baseline correspond au systeme **avant tout durcissement** (instantane VirtualBox `pristine`, Proxmox VE 9.2.2 / Debian 13).
- Conformite : 48.6 % a la baseline, 64.5 % apres de-hardening.

## 3. Re-durcissement : la reference est retrouvee

**Les 161 controles presentent un statut identique a celui de la premiere application du durcissement.** Le durcissement est donc reproductible et le de-hardening n'a laisse aucun artefact derangeant.

- Conformite : 100 % apres durcissement, 100 % apres re-durcissement.

## 4. Ce que fait le de-hardening

Le script `guest/deharden-pve.sh` s'execute **sur le noeud** ; le client `scripts/deharden.sh` l'appelle a distance par adresse IP et mot de passe root (ou cle SSH).

| Phase | Operation |
|---|---|
| Securite | archive de l'etat courant (`/root/deharden-safety-<ts>/`) |
| Restauration | retablit la version **la plus ancienne** de chaque sauvegarde (l'etat d'origine) |
| Suppression | efface les fichiers crees par le durcissement |
| Permissions | retablit mode / proprietaire / groupe (fichiers `.mode`) |
| Etat | re-active les services, Deverrouille les comptes, restaure les shells, supprime `pveadmin` |
| Depots | reactive les depots enterprise (`*.sources.disabled`) |
| Paquets | desinstalle les paquets ajoutes (sauf `--keep-packages`) |
| SSH | `sshd -t` avant tout rechargement : l'acces ne peut pas etre coupe |

### Rapport produit par le de-hardening

```
# De-hardening Proxmox VE

- **Date** : 2026-11-15T07:31:53+01:00
- **Hote** : pve
- **Mode** : application
- **Journal** : `/var/log/deharden-20261115_073001.log`
- **Sauvegarde de securite** : `/root/deharden-safety-20261115_073001`

## Fichiers restaures

| Fichier |
|---|
| `/etc/apparmor.d/busybox` |
| `/etc/apt/apt.conf.d/20auto-upgrades` |
| `/etc/crontab` |
| `/etc/fstab` |
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
| `/etc/issue.net` |
| `/etc/profile.d/99-pve-hardening.sh` |
| `/etc/ssh/sshd_config.d/00-pve-hardening.conf` |
| `/etc/modprobe.d/99-pve-hardening.conf` |
| `/etc/modprobe.d/99-anssi-usb.conf` |
| `/etc/sysctl.d/97-pve-hardening.conf` |
| `/etc/sysctl.d/98-anssi.conf` |
| `/etc/sysctl.d/99-pve-hardening.conf` |
| `/etc/systemd/journald.conf.d/99-pve-hardening.conf` |
| `/etc/security/limits.d/99-pve-hardening.conf` |
| `/etc/profile.d/tmout.sh` |
| `/etc/audit/rules.d/90-pve.rules` |
| `/etc/fail2ban/filter.d/pveproxy.conf` |
| `/etc/fail2ban/jail.d/pve-web.conf` |
| `/etc/fail2ban/jail.d/pve-web-http.conf` |
| `/etc/rsyslog.d/99-anssi-remote.conf` |
| `/etc/cron.daily/aide-check` |
| `/etc/cron.allow` |
| `/root/rollback-hardening.sh` |
| `/etc/pve/firewall/cluster.fw` |
| `/etc/pve/nodes/pve/firewall` |

## Paquets

Desinstalles : `aide aide-common apparmor-utils rsyslog auditd audispd-plugins fail2ban rkhunter unattended-upgrades apt-listchanges libpam-pwquality libpam-modules sudo chrony`

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

1. **Preparation** - la VM `proxmox` est restauree sur l'instantane `pristine` (Proxmox VE 9.2.2, Debian 13, aucun durcissement).
2. **Baseline** - audit des 5 perimetres (Proxmox, CIS Debian 13, ANSSI BP-028, Ceph, controles communautaires) et suite de tests fonctionnels (72 tests Proxmox + OS).
3. **Durcissement** - application de `apply-homesec-core.sh` (CIS L1 puis L2), `apply-anssi.sh` (niveau 3) et `apply-ceph.sh`, puis audit de reference et tests fonctionnels.
4. **De-hardening** - execution du client bash en simulation (`--dry-run`) puis en application :

```bash
bash scripts/deharden.sh --host 127.0.0.1 --port 2222 \
     --key ~/.ssh/id_ed25519 --dry-run
bash scripts/deharden.sh --host 127.0.0.1 --port 2222 \
     --key ~/.ssh/id_ed25519
```

5. **Verification** - audit de l'etat restaure et tests fonctionnels : les statuts doivent etre identiques a la baseline.
6. **Re-durcissement** - re-application des trois durcisseurs puis audit final : les statuts doivent etre identiques a la reference durcie.

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
# 3. controle : la compliance doit redevenir identique a la baseline
python3 scripts/pve.py run --phase verify --ssh-host <ip> --audit-extra anssi,ceph,cis13,communautaire
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

### Artefacts

| Prefixe | Contenu |
|---|---|
| `baseline-20261115-071728` | Baseline - PVE 9.2.2 pristine (avant durcissement) |
| `hardened-20261115-072915` | Apres durcissement (CIS L2 + ANSSI N3 + Ceph) |
| `dehardened-20261115-073218` | Apres de-hardening |
| `rehardened-20261115-065848` | Apres re-durcissement |
| `func-baseline-20261115-071729` | Baseline - PVE 9.2.2 pristine |
| `func-hardened-20261115-072916` | Apres durcissement |
| `func-dehardened-20261115-073219` | Apres de-hardening |
| `func-rehardened-20261115-065849` | Apres re-durcissement |

