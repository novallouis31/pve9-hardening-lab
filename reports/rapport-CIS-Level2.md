# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261111-083123`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-084429`
- **Genere le** : 2026-11-11 08:48:58

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

## Detail - Systeme d exploitation (OS)

| Controle |
|---|
| Avant |
| Apres |
| Evolution |
| Detail (apres) |
| `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=2 enforce=2 |
| `OS.AUDITD.ACTIVE` | FAIL | PASS | amelioration | auditd actif |
| `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| `OS.CRON.CRONTAB` | FAIL | PASS | amelioration | /etc/crontab en 600 |
| `OS.CRON.DIR.cron.d` | FAIL | PASS | amelioration | /etc/cron.d en 700 |
| `OS.CRON.DIR.cron.daily` | FAIL | PASS | amelioration | /etc/cron.daily en 700 |
| `OS.CRON.DIR.cron.hourly` | FAIL | PASS | amelioration | /etc/cron.hourly en 700 |
| `OS.CRON.DIR.cron.monthly` | FAIL | PASS | amelioration | /etc/cron.monthly en 700 |
| `OS.CRON.DIR.cron.weekly` | FAIL | PASS | amelioration | /etc/cron.weekly en 700 |
| `OS.JOURNALD.Compress` | FAIL | PASS | amelioration | Compress=yes |
| `OS.JOURNALD.Storage` | FAIL | PASS | amelioration | Storage=persistent |
| `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| `OS.MOUNT._dev_shm` | FAIL | PASS | amelioration | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| `OS.ROOTKIT.TOOL` | FAIL | PASS | amelioration | outil de detection de rootkit installe |
| `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| `OS.SSHD.ALLOWLIST` | FAIL | FAIL | inchange | aucune restriction AllowUsers/AllowGroups |
| `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| `OS.SSHD.CLIENTALIVE` | FAIL | PASS | amelioration | ClientAliveInterval=300 CountMax=2 |
| `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| `OS.SSHD.GRACETIME` | FAIL | PASS | amelioration | LoginGraceTime=30 |
| `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| `OS.SSHD.MACS` | FAIL | PASS | amelioration | MACs sans algorithme faible |
| `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| `OS.SSHD.PERM.sshd_config` | FAIL | PASS | amelioration | /etc/ssh/sshd_config en 600 |
| `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | amelioration | /etc/ssh/sshd_config.d en 700 |
| `OS.SSHD.PERMITROOT` | FAIL | INFO | modifie | PermitRootLogin=without-password (acces root par cle uniquement) |
| `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| `OS.SSHD.X11` | FAIL | PASS | amelioration | X11Forwarding=no |
| `OS.UNATTENDED.ENABLED` | FAIL | PASS | amelioration | mises a jour automatiques activees |
| `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |

## Detail - Proxmox VE (PVE)

| Controle |
|---|
| Avant |
| Apres |
| Evolution |
| Detail (apres) |
| `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| `PVE.CRYPT.LUKS` | FAIL | FAIL | inchange | aucun chiffrement de disque (LUKS) |
| `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| `PVE.FW.CLUSTER` | FAIL | PASS | amelioration | /etc/pve/firewall/cluster.fw present |
| `PVE.FW.FORWARD` | NA | FAIL | modifie | politique FORWARD non DROP (enable: 1;) |
| `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |

## Detail - Systeme (SYS)

| Controle |
|---|
| Avant |
| Apres |
| Evolution |
| Detail (apres) |
| `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |

## Detail - Utilisateurs (USR)

| Controle |
|---|
| Avant |
| Apres |
| Evolution |
| Detail (apres) |
| `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

