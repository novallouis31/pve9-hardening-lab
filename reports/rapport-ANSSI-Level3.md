# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261111-091729`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261111-092235`
- **Genere le** : 2026-11-11 09:22:40

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 48 | 57 | +9 |
| Controles en echec (FAIL) | 25 | 16 | (-9) |
| Regressions | - | 0 | |
| Ameliorations | - | 9 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `ANS.BOOT.PERM` | FAIL | PASS | /boot mode=700 |
| `ANS.CTRLALTDEL` | FAIL | PASS | ctrl-alt-del.target desactive |
| `ANS.KERNEL.BPF` | FAIL | PASS | unprivileged_bpf_disabled=1 |
| `ANS.KERNEL.JIT` | FAIL | PASS | bpf_jit_harden=2 |
| `ANS.AIDE.INSTALLED` | FAIL | PASS | aide installe |
| `ANS.AIDE.DB` | FAIL | PASS | base AIDE presente |
| `ANS.PASSWORD.AGING` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `ANS.USBSTORAGE` | FAIL | PASS | usb-storage desactive |
| `ANS.CRON.ALLOW` | FAIL | PASS | /etc/cron.allow present |

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
| `ANS.RSYSLOG.REMOTE` | FAIL | aucun transfert distant (centralisation des journaux non configuree) |
| `ANS.APPARMOR.ENFORCE` | FAIL | profils en mode complain presents |
| `ANS.SSH.ROOTLOGIN` | FAIL | PermitRootLogin=prohibit-password (ANSSI renforce attend no) |
| `ANS.LOGIN.UMASK` | FAIL | UMASK=non defini |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `ANS.AIDE.DB` | FAIL | PASS | amelioration | base AIDE presente |
| 2 | `ANS.AIDE.INSTALLED` | FAIL | PASS | amelioration | aide installe |
| 3 | `ANS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | profils en mode complain presents |
| 4 | `ANS.BOOT.PERM` | FAIL | PASS | amelioration | /boot mode=700 |
| 5 | `ANS.CRON.ALLOW` | FAIL | PASS | amelioration | /etc/cron.allow present |
| 6 | `ANS.CTRLALTDEL` | FAIL | PASS | amelioration | ctrl-alt-del.target desactive |
| 7 | `ANS.KERNEL.BPF` | FAIL | PASS | amelioration | unprivileged_bpf_disabled=1 |
| 8 | `ANS.KERNEL.JIT` | FAIL | PASS | amelioration | bpf_jit_harden=2 |
| 9 | `ANS.LOGIN.UMASK` | FAIL | FAIL | inchange | UMASK=non defini |
| 10 | `ANS.PASSWORD.AGING` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 11 | `ANS.RSYSLOG.REMOTE` | FAIL | FAIL | inchange | aucun transfert distant (centralisation des journaux non configuree) |
| 12 | `ANS.SERVICES.AVAHI` | PASS | PASS | inchange | avahi-daemon inactif |
| 13 | `ANS.SSH.ROOTLOGIN` | FAIL | FAIL | inchange | PermitRootLogin=prohibit-password (ANSSI renforce attend no) |
| 14 | `ANS.USBSTORAGE` | FAIL | PASS | amelioration | usb-storage desactive |
| 15 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 16 | `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=2 enforce=2 |
| 17 | `OS.AUDITD.ACTIVE` | PASS | PASS | inchange | auditd actif |
| 18 | `OS.AUDITD.PVE` | PASS | PASS | inchange | regles d'audit sur /etc/pve |
| 19 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 20 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 21 | `OS.CRON.CRONTAB` | PASS | PASS | inchange | /etc/crontab en 600 |
| 22 | `OS.CRON.DIR.cron.d` | PASS | PASS | inchange | /etc/cron.d en 700 |
| 23 | `OS.CRON.DIR.cron.daily` | PASS | PASS | inchange | /etc/cron.daily en 700 |
| 24 | `OS.CRON.DIR.cron.hourly` | PASS | PASS | inchange | /etc/cron.hourly en 700 |
| 25 | `OS.CRON.DIR.cron.monthly` | PASS | PASS | inchange | /etc/cron.monthly en 700 |
| 26 | `OS.CRON.DIR.cron.weekly` | PASS | PASS | inchange | /etc/cron.weekly en 700 |
| 27 | `OS.JOURNALD.Compress` | PASS | PASS | inchange | Compress=yes |
| 28 | `OS.JOURNALD.Storage` | PASS | PASS | inchange | Storage=persistent |
| 29 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 30 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 31 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 32 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 33 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 34 | `OS.MOUNT._dev_shm` | PASS | PASS | inchange | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 35 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| 36 | `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| 37 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 38 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 39 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 40 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 41 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 42 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 43 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 44 | `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| 45 | `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| 46 | `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| 47 | `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| 48 | `OS.ROOTKIT.TOOL` | PASS | PASS | inchange | outil de detection de rootkit installe |
| 49 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 50 | `OS.SSHD.ALLOWLIST` | FAIL | FAIL | inchange | aucune restriction AllowUsers/AllowGroups |
| 51 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 52 | `OS.SSHD.CLIENTALIVE` | PASS | PASS | inchange | ClientAliveInterval=300 CountMax=2 |
| 53 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 54 | `OS.SSHD.GRACETIME` | PASS | PASS | inchange | LoginGraceTime=30 |
| 55 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 56 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 57 | `OS.SSHD.MACS` | PASS | PASS | inchange | MACs sans algorithme faible |
| 58 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 59 | `OS.SSHD.PASSWORDAUTH` | PASS | PASS | inchange | PasswordAuthentication=no |
| 60 | `OS.SSHD.PERM.sshd_config` | PASS | PASS | inchange | /etc/ssh/sshd_config en 600 |
| 61 | `OS.SSHD.PERM.sshd_config.d` | PASS | PASS | inchange | /etc/ssh/sshd_config.d en 700 |
| 62 | `OS.SSHD.PERMITROOT` | INFO | INFO | inchange | PermitRootLogin=without-password (acces root par cle uniquement) |
| 63 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 64 | `OS.SSHD.X11` | PASS | PASS | inchange | X11Forwarding=no |
| 65 | `OS.UNATTENDED.ENABLED` | PASS | PASS | inchange | mises a jour automatiques activees |
| 66 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 67 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 68 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 69 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 70 | `PVE.CRYPT.LUKS` | FAIL | FAIL | inchange | aucun chiffrement de disque (LUKS) |
| 71 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 72 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 73 | `PVE.FW.CLUSTER` | PASS | PASS | inchange | /etc/pve/firewall/cluster.fw present |
| 74 | `PVE.FW.FORWARD` | FAIL | FAIL | inchange | politique FORWARD non DROP (enable: 1;) |
| 75 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 76 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 77 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 78 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 79 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 80 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 81 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

