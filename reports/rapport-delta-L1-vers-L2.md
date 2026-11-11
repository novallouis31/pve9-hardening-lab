# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-083425`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-084429`
- **Genere le** : 2026-11-11 08:49:01

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 45 | 47 | +2 |
| Controles en echec (FAIL) | 13 | 12 | (-2) |
| Regressions | - | 0 | |
| Ameliorations | - | 2 | |

## Ameliorations

| Controle |
|---|
| Avant |
| Apres |
| Detail |
| `OS.AUDITD.PVE` | FAIL | PASS | regles d'audit sur /etc/pve |
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
| `OS.AUDITD.ACTIVE` | PASS | PASS | inchange | auditd actif |
| `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| `OS.CRON.CRONTAB` | PASS | PASS | inchange | /etc/crontab en 600 |
| `OS.CRON.DIR.cron.d` | PASS | PASS | inchange | /etc/cron.d en 700 |
| `OS.CRON.DIR.cron.daily` | PASS | PASS | inchange | /etc/cron.daily en 700 |
| `OS.CRON.DIR.cron.hourly` | PASS | PASS | inchange | /etc/cron.hourly en 700 |
| `OS.CRON.DIR.cron.monthly` | PASS | PASS | inchange | /etc/cron.monthly en 700 |
| `OS.CRON.DIR.cron.weekly` | PASS | PASS | inchange | /etc/cron.weekly en 700 |
| `OS.JOURNALD.Compress` | PASS | PASS | inchange | Compress=yes |
| `OS.JOURNALD.Storage` | PASS | PASS | inchange | Storage=persistent |
| `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| `OS.MOUNT._dev_shm` | PASS | PASS | inchange | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
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
| `OS.SSHD.CLIENTALIVE` | PASS | PASS | inchange | ClientAliveInterval=300 CountMax=2 |
| `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| `OS.SSHD.GRACETIME` | PASS | PASS | inchange | LoginGraceTime=30 |
| `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| `OS.SSHD.MACS` | PASS | PASS | inchange | MACs sans algorithme faible |
| `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| `OS.SSHD.PASSWORDAUTH` | PASS | PASS | inchange | PasswordAuthentication=no |
| `OS.SSHD.PERM.sshd_config` | PASS | PASS | inchange | /etc/ssh/sshd_config en 600 |
| `OS.SSHD.PERM.sshd_config.d` | PASS | PASS | inchange | /etc/ssh/sshd_config.d en 700 |
| `OS.SSHD.PERMITROOT` | INFO | INFO | inchange | PermitRootLogin=without-password (acces root par cle uniquement) |
| `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| `OS.SSHD.X11` | PASS | PASS | inchange | X11Forwarding=no |
| `OS.UNATTENDED.ENABLED` | PASS | PASS | inchange | mises a jour automatiques activees |
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
| `PVE.FW.CLUSTER` | PASS | PASS | inchange | /etc/pve/firewall/cluster.fw present |
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

