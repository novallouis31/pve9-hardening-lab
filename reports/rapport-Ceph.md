# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261111-092253`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-092310`
- **Genere le** : 2026-11-11 09:23:15

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 48 | 52 | +4 |
| Controles en echec (FAIL) | 17 | 13 | (-4) |
| Regressions | - | 0 | |
| Ameliorations | - | 4 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `CEPH.CONF` | FAIL | PASS | /etc/ceph/ceph.conf present |
| `CEPH.AUTH.CEPHX` | FAIL | PASS | cephx active dans ceph.conf |
| `CEPH.MSGR2` | FAIL | PASS | msgr2 en mode secure |
| `CEPH.CONF.PERM` | FAIL | PASS | /etc/ceph mode=750 |

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
| `OS.MOUNT._var_tmp` | FAIL | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| `OS.SSHD.ALLOWLIST` | FAIL | aucune restriction AllowUsers/AllowGroups |
| `OS.PAM.FAILLOCK` | FAIL | pam_faillock absent de /etc/pam.d/common-auth |
| `OS.PAM.FAILLOCK.POLICY` | FAIL | deny=? |
| `OS.PAM.PWQUALITY` | FAIL | aucun module de qualite de mot de passe installe |
| `OS.PAM.MINLEN` | FAIL | minlen=non defini (attendu >=12) |
| `OS.APPARMOR.ENFORCE` | FAIL | complain=2 enforce=2 |
| `OS.UNATTENDED.PKG` | FAIL | unattended-upgrades absent |
| `PVE.F2B.PKG` | FAIL | fail2ban absent |
| `PVE.F2B.GUI` | FAIL | fail2ban absent |
| `PVE.FW.FORWARD` | FAIL | politique FORWARD non DROP (enable: 1;) |
| `PVE.CRYPT.LUKS` | FAIL | aucun chiffrement de disque (LUKS) |
| `CEPH.DASHBOARD` | FAIL | dashboard actif (verifier l'authentification) |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `CEPH.AUTH.CEPHX` | FAIL | PASS | amelioration | cephx active dans ceph.conf |
| 2 | `CEPH.CLUSTER` | NA | NA | inchange | ceph-mon absent (pas de cluster local) |
| 3 | `CEPH.CONF` | FAIL | PASS | amelioration | /etc/ceph/ceph.conf present |
| 4 | `CEPH.CONF.PERM` | FAIL | PASS | amelioration | /etc/ceph mode=750 |
| 5 | `CEPH.DASHBOARD` | FAIL | FAIL | inchange | dashboard actif (verifier l'authentification) |
| 6 | `CEPH.KEYRING.PERM` | NA | NA | inchange | aucun keyring present |
| 7 | `CEPH.MSGR2` | FAIL | PASS | amelioration | msgr2 en mode secure |
| 8 | `CEPH.PKG` | PASS | PASS | inchange | ceph client installe |
| 9 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 10 | `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=2 enforce=2 |
| 11 | `OS.AUDITD.ACTIVE` | PASS | PASS | inchange | auditd actif |
| 12 | `OS.AUDITD.PVE` | PASS | PASS | inchange | regles d'audit sur /etc/pve |
| 13 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 14 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 15 | `OS.CRON.CRONTAB` | PASS | PASS | inchange | /etc/crontab en 600 |
| 16 | `OS.CRON.DIR.cron.d` | PASS | PASS | inchange | /etc/cron.d en 700 |
| 17 | `OS.CRON.DIR.cron.daily` | PASS | PASS | inchange | /etc/cron.daily en 700 |
| 18 | `OS.CRON.DIR.cron.hourly` | PASS | PASS | inchange | /etc/cron.hourly en 700 |
| 19 | `OS.CRON.DIR.cron.monthly` | PASS | PASS | inchange | /etc/cron.monthly en 700 |
| 20 | `OS.CRON.DIR.cron.weekly` | PASS | PASS | inchange | /etc/cron.weekly en 700 |
| 21 | `OS.JOURNALD.Compress` | PASS | PASS | inchange | Compress=yes |
| 22 | `OS.JOURNALD.Storage` | PASS | PASS | inchange | Storage=persistent |
| 23 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 24 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 25 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 26 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 27 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 28 | `OS.MOUNT._dev_shm` | PASS | PASS | inchange | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 29 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| 30 | `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| 31 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 32 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 33 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 34 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 35 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 36 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 37 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 38 | `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| 39 | `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| 40 | `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| 41 | `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| 42 | `OS.ROOTKIT.TOOL` | PASS | PASS | inchange | outil de detection de rootkit installe |
| 43 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 44 | `OS.SSHD.ALLOWLIST` | FAIL | FAIL | inchange | aucune restriction AllowUsers/AllowGroups |
| 45 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 46 | `OS.SSHD.CLIENTALIVE` | PASS | PASS | inchange | ClientAliveInterval=300 CountMax=2 |
| 47 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 48 | `OS.SSHD.GRACETIME` | PASS | PASS | inchange | LoginGraceTime=30 |
| 49 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 50 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 51 | `OS.SSHD.MACS` | PASS | PASS | inchange | MACs sans algorithme faible |
| 52 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 53 | `OS.SSHD.PASSWORDAUTH` | PASS | PASS | inchange | PasswordAuthentication=no |
| 54 | `OS.SSHD.PERM.sshd_config` | PASS | PASS | inchange | /etc/ssh/sshd_config en 600 |
| 55 | `OS.SSHD.PERM.sshd_config.d` | PASS | PASS | inchange | /etc/ssh/sshd_config.d en 700 |
| 56 | `OS.SSHD.PERMITROOT` | INFO | INFO | inchange | PermitRootLogin=without-password (acces root par cle uniquement) |
| 57 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 58 | `OS.SSHD.X11` | PASS | PASS | inchange | X11Forwarding=no |
| 59 | `OS.UNATTENDED.ENABLED` | PASS | PASS | inchange | mises a jour automatiques activees |
| 60 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 61 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 62 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 63 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 64 | `PVE.CRYPT.LUKS` | FAIL | FAIL | inchange | aucun chiffrement de disque (LUKS) |
| 65 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 66 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 67 | `PVE.FW.CLUSTER` | PASS | PASS | inchange | /etc/pve/firewall/cluster.fw present |
| 68 | `PVE.FW.FORWARD` | FAIL | FAIL | inchange | politique FORWARD non DROP (enable: 1;) |
| 69 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 70 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 71 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 72 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 73 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 74 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 75 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

