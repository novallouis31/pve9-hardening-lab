# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261111-083123`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-084429`
- **Genere le** : 2026-11-11 08:51:05

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 26 | 47 | +21 |
| Controles en echec (FAIL) | 33 | 12 | (-21) |
| Regressions | - | 0 | |
| Ameliorations | - | 21 | |

## Ameliorations

| Controle |
|---|
| Avant |
| Apres |
| Detail |
| `OS.MOUNT._dev_shm` | FAIL | PASS | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| `OS.CRON.CRONTAB` | FAIL | PASS | /etc/crontab en 600 |
| `OS.CRON.DIR.cron.daily` | FAIL | PASS | /etc/cron.daily en 700 |
| `OS.CRON.DIR.cron.hourly` | FAIL | PASS | /etc/cron.hourly en 700 |
| `OS.CRON.DIR.cron.weekly` | FAIL | PASS | /etc/cron.weekly en 700 |
| `OS.CRON.DIR.cron.monthly` | FAIL | PASS | /etc/cron.monthly en 700 |
| `OS.CRON.DIR.cron.d` | FAIL | PASS | /etc/cron.d en 700 |
| `OS.JOURNALD.Storage` | FAIL | PASS | Storage=persistent |
| `OS.JOURNALD.Compress` | FAIL | PASS | Compress=yes |
| `OS.AUDITD.ACTIVE` | FAIL | PASS | auditd actif |
| `OS.AUDITD.PVE` | FAIL | PASS | regles d'audit sur /etc/pve |
| `OS.SSHD.PERM.sshd_config` | FAIL | PASS | /etc/ssh/sshd_config en 600 |
| `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | /etc/ssh/sshd_config.d en 700 |
| `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | PasswordAuthentication=no |
| `OS.SSHD.X11` | FAIL | PASS | X11Forwarding=no |
| `OS.SSHD.GRACETIME` | FAIL | PASS | LoginGraceTime=30 |
| `OS.SSHD.CLIENTALIVE` | FAIL | PASS | ClientAliveInterval=300 CountMax=2 |
| `OS.SSHD.MACS` | FAIL | PASS | MACs sans algorithme faible |
| `OS.UNATTENDED.ENABLED` | FAIL | PASS | mises a jour automatiques activees |
| `PVE.FW.CLUSTER` | FAIL | PASS | /etc/pve/firewall/cluster.fw present |
| `OS.ROOTKIT.TOOL` | FAIL | PASS | outil de detection de rootkit installe |

## Controles en echec restants (apres)

| Controle |
|---|
| Statut |
| Detail |
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

| # |
|---|
| Controle |
| Avant |
| Apres |
| Evolution |
| Detail (apres) |
| 1 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 2 | `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=2 enforce=2 |
| 3 | `OS.AUDITD.ACTIVE` | FAIL | PASS | amelioration | auditd actif |
| 4 | `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| 5 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 6 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 7 | `OS.CRON.CRONTAB` | FAIL | PASS | amelioration | /etc/crontab en 600 |
| 8 | `OS.CRON.DIR.cron.d` | FAIL | PASS | amelioration | /etc/cron.d en 700 |
| 9 | `OS.CRON.DIR.cron.daily` | FAIL | PASS | amelioration | /etc/cron.daily en 700 |
| 10 | `OS.CRON.DIR.cron.hourly` | FAIL | PASS | amelioration | /etc/cron.hourly en 700 |
| 11 | `OS.CRON.DIR.cron.monthly` | FAIL | PASS | amelioration | /etc/cron.monthly en 700 |
| 12 | `OS.CRON.DIR.cron.weekly` | FAIL | PASS | amelioration | /etc/cron.weekly en 700 |
| 13 | `OS.JOURNALD.Compress` | FAIL | PASS | amelioration | Compress=yes |
| 14 | `OS.JOURNALD.Storage` | FAIL | PASS | amelioration | Storage=persistent |
| 15 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 16 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 17 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 18 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 19 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 20 | `OS.MOUNT._dev_shm` | FAIL | PASS | amelioration | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
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
| 38 | `OS.SSHD.CLIENTALIVE` | FAIL | PASS | amelioration | ClientAliveInterval=300 CountMax=2 |
| 39 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 40 | `OS.SSHD.GRACETIME` | FAIL | PASS | amelioration | LoginGraceTime=30 |
| 41 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 42 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 43 | `OS.SSHD.MACS` | FAIL | PASS | amelioration | MACs sans algorithme faible |
| 44 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 45 | `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 46 | `OS.SSHD.PERM.sshd_config` | FAIL | PASS | amelioration | /etc/ssh/sshd_config en 600 |
| 47 | `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | amelioration | /etc/ssh/sshd_config.d en 700 |
| 48 | `OS.SSHD.PERMITROOT` | FAIL | INFO | modifie | PermitRootLogin=without-password (acces root par cle uniquement) |
| 49 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 50 | `OS.SSHD.X11` | FAIL | PASS | amelioration | X11Forwarding=no |
| 51 | `OS.UNATTENDED.ENABLED` | FAIL | PASS | amelioration | mises a jour automatiques activees |
| 52 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 53 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 54 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 55 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 56 | `PVE.CRYPT.LUKS` | FAIL | FAIL | inchange | aucun chiffrement de disque (LUKS) |
| 57 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 58 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 59 | `PVE.FW.CLUSTER` | FAIL | PASS | amelioration | /etc/pve/firewall/cluster.fw present |
| 60 | `PVE.FW.FORWARD` | NA | FAIL | modifie | politique FORWARD non DROP (enable: 1;) |
| 61 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 62 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 63 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 64 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 65 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 66 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 67 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

