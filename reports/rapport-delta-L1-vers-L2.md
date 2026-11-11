# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-083425`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-084429`
- **Genere le** : 2026-11-11 08:55:25

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 45 | 47 | +2 |
| Controles en echec (FAIL) | 13 | 12 | (-2) |
| Regressions | - | 0 | |
| Ameliorations | - | 2 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `OS.AUDITD.PVE` | FAIL | PASS | regles d'audit sur /etc/pve |
| `OS.ROOTKIT.TOOL` | FAIL | PASS | outil de detection de rootkit installe |

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

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 2 | `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=2 enforce=2 |
| 3 | `OS.AUDITD.ACTIVE` | PASS | PASS | inchange | auditd actif |
| 4 | `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| 5 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 6 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 7 | `OS.CRON.CRONTAB` | PASS | PASS | inchange | /etc/crontab en 600 |
| 8 | `OS.CRON.DIR.cron.d` | PASS | PASS | inchange | /etc/cron.d en 700 |
| 9 | `OS.CRON.DIR.cron.daily` | PASS | PASS | inchange | /etc/cron.daily en 700 |
| 10 | `OS.CRON.DIR.cron.hourly` | PASS | PASS | inchange | /etc/cron.hourly en 700 |
| 11 | `OS.CRON.DIR.cron.monthly` | PASS | PASS | inchange | /etc/cron.monthly en 700 |
| 12 | `OS.CRON.DIR.cron.weekly` | PASS | PASS | inchange | /etc/cron.weekly en 700 |
| 13 | `OS.JOURNALD.Compress` | PASS | PASS | inchange | Compress=yes |
| 14 | `OS.JOURNALD.Storage` | PASS | PASS | inchange | Storage=persistent |
| 15 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 16 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 17 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 18 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 19 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 20 | `OS.MOUNT._dev_shm` | PASS | PASS | inchange | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 21 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| 22 | `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| 23 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 24 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 25 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 26 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 27 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 28 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 29 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 30 | `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| 31 | `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| 32 | `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| 33 | `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| 34 | `OS.ROOTKIT.TOOL` | FAIL | PASS | amelioration | outil de detection de rootkit installe |
| 35 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 36 | `OS.SSHD.ALLOWLIST` | FAIL | FAIL | inchange | aucune restriction AllowUsers/AllowGroups |
| 37 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 38 | `OS.SSHD.CLIENTALIVE` | PASS | PASS | inchange | ClientAliveInterval=300 CountMax=2 |
| 39 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 40 | `OS.SSHD.GRACETIME` | PASS | PASS | inchange | LoginGraceTime=30 |
| 41 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 42 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 43 | `OS.SSHD.MACS` | PASS | PASS | inchange | MACs sans algorithme faible |
| 44 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 45 | `OS.SSHD.PASSWORDAUTH` | PASS | PASS | inchange | PasswordAuthentication=no |
| 46 | `OS.SSHD.PERM.sshd_config` | PASS | PASS | inchange | /etc/ssh/sshd_config en 600 |
| 47 | `OS.SSHD.PERM.sshd_config.d` | PASS | PASS | inchange | /etc/ssh/sshd_config.d en 700 |
| 48 | `OS.SSHD.PERMITROOT` | INFO | INFO | inchange | PermitRootLogin=without-password (acces root par cle uniquement) |
| 49 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 50 | `OS.SSHD.X11` | PASS | PASS | inchange | X11Forwarding=no |
| 51 | `OS.UNATTENDED.ENABLED` | PASS | PASS | inchange | mises a jour automatiques activees |
| 52 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 53 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 54 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 55 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 56 | `PVE.CRYPT.LUKS` | FAIL | FAIL | inchange | aucun chiffrement de disque (LUKS) |
| 57 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 58 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 59 | `PVE.FW.CLUSTER` | PASS | PASS | inchange | /etc/pve/firewall/cluster.fw present |
| 60 | `PVE.FW.FORWARD` | NA | FAIL | modifie | politique FORWARD non DROP (enable: 1;) |
| 61 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 62 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 63 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 64 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 65 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 66 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 67 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

