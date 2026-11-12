# ANSSI BP-028 niveau 3 (renforce) - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261112-133216`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-133901`
- **Genere le** : 2026-11-12 13:41:50

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 48 | 84 | +36 |
| Controles en echec (FAIL) | 64 | 30 | (-36) |
| Regressions | - | 0 | |
| Ameliorations | - | 36 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `OS.CRON.CRONTAB` | FAIL | PASS | /etc/crontab en 600 |
| `OS.CRON.DIR.cron.daily` | FAIL | PASS | /etc/cron.daily en 700 |
| `OS.CRON.DIR.cron.hourly` | FAIL | PASS | /etc/cron.hourly en 700 |
| `OS.CRON.DIR.cron.weekly` | FAIL | PASS | /etc/cron.weekly en 700 |
| `OS.CRON.DIR.cron.monthly` | FAIL | PASS | /etc/cron.monthly en 700 |
| `OS.CRON.DIR.cron.d` | FAIL | PASS | /etc/cron.d en 700 |
| `OS.RSYSLOG` | INFO | PASS | rsyslog actif |
| `OS.SSHD.PERMITROOT` | FAIL | PASS | PermitRootLogin=no |
| `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | PasswordAuthentication=no |
| `OS.SSHD.X11` | FAIL | PASS | X11Forwarding=no |
| `OS.SSHD.GRACETIME` | FAIL | PASS | LoginGraceTime=30 |
| `OS.SSHD.ALLOWLIST` | FAIL | PASS | AllowUsers=root AllowGroups=none |
| `OS.SSHD.CLIENTALIVE` | FAIL | PASS | ClientAliveInterval=300 CountMax=2 |
| `OS.SSHD.MACS` | FAIL | PASS | MACs sans algorithme faible |
| `OS.APPARMOR.ENFORCE` | FAIL | PASS | 119 profils en enforce, 0 en complain |
| `ANS.BOOT.PERM` | FAIL | PASS | /boot mode=700 |
| `ANS.CTRLALTDEL` | FAIL | PASS | ctrl-alt-del.target desactive |
| `ANS.KERNEL.BPF` | FAIL | PASS | unprivileged_bpf_disabled=1 |
| `ANS.KERNEL.JIT` | FAIL | PASS | bpf_jit_harden=2 |
| `ANS.KERNEL.KPTR` | FAIL | PASS | kptr_restrict=2 |
| `ANS.SESSION.TMOUT` | FAIL | PASS | TMOUT=900 |
| `ANS.AIDE.INSTALLED` | FAIL | PASS | aide installe |
| `ANS.AIDE.DB` | FAIL | PASS | base AIDE presente |
| `ANS.PASSWORD.AGING` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `ANS.RSYSLOG.REMOTE` | FAIL | PASS | transfert distant configure (omfwd) |
| `ANS.RSYSLOG.ACTIVE` | FAIL | PASS | rsyslog actif |
| `ANS.APPARMOR.ENFORCE` | FAIL | PASS | aucun profil en mode complain |
| `ANS.USBSTORAGE` | FAIL | PASS | usb-storage desactive |
| `ANS.CRON.ALLOW` | FAIL | PASS | /etc/cron.allow present |
| `ANS.LOGIN.UMASK` | FAIL | PASS | UMASK=027 |
| `ANS.SSH.ROOTLOGIN` | FAIL | PASS | PermitRootLogin=no global, exception restreinte a 10.0.2.0/24 (guide PVE 9 option B) |
| `ANS.SSH.PASSWORDAUTH` | FAIL | PASS | PasswordAuthentication=no |
| `CIS.5.4.2.1` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `CIS.5.4.2.2` | FAIL | PASS | PASS_MIN_DAYS=1 |
| `CIS.5.4.3.1` | FAIL | PASS | UMASK=027 |
| `CIS.4.1.2.1` | INFO | PASS | rsyslog transfere vers un collecteur distant |

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
| `OS.MOUNT._var_tmp` | FAIL | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| `OS.MOUNT._dev_shm` | FAIL | /dev/shm opts=rw,nosuid,nodev,inode64 (manquant: noexec ) |
| `OS.JOURNALD.Storage` | FAIL | Storage != persistent |
| `OS.JOURNALD.Compress` | FAIL | Compress != yes |
| `OS.AUDITD.ACTIVE` | FAIL | auditd inactif ou absent |
| `OS.AUDITD.PVE` | FAIL | aucune regle d'audit sur /etc/pve |
| `OS.SSHD.PERM.sshd_config` | FAIL | /etc/ssh/sshd_config en 644 (attendu 600) |
| `OS.SSHD.PERM.sshd_config.d` | FAIL | /etc/ssh/sshd_config.d en 755 (attendu 700) |
| `OS.PAM.FAILLOCK` | FAIL | pam_faillock absent de /etc/pam.d/common-auth |
| `OS.PAM.FAILLOCK.POLICY` | FAIL | deny=? |
| `OS.PAM.PWQUALITY` | FAIL | aucun module de qualite de mot de passe installe |
| `OS.PAM.MINLEN` | FAIL | minlen=non defini (attendu >=12) |
| `OS.UNATTENDED.PKG` | FAIL | unattended-upgrades absent |
| `OS.UNATTENDED.ENABLED` | FAIL | mises a jour automatiques non activees |
| `PVE.F2B.PKG` | FAIL | fail2ban absent |
| `PVE.F2B.GUI` | FAIL | fail2ban absent |
| `PVE.FW.CLUSTER` | FAIL | /etc/pve/firewall/cluster.fw absent (pare-feu cluster desactive) |
| `OS.ROOTKIT.TOOL` | FAIL | ni rkhunter ni chkrootkit installes |
| `CEPH.CONF` | FAIL | /etc/ceph/ceph.conf absent |
| `CEPH.AUTH.CEPHX` | FAIL | cephx non verifiable (conf absente) |
| `CEPH.MSGR2` | FAIL | chiffrement msgr2 non verifiable (conf absente) |
| `CEPH.CONF.PERM` | FAIL | /etc/ceph en 755 (attendu 750/700) |
| `CIS.5.3.3.1.1` | FAIL | pam_faillock sans argument deny= dans les fichiers PAM |
| `CIS.5.3.3.1.2` | FAIL | pam_faillock sans argument unlock_time= dans les fichiers PAM |
| `CIS.5.3.3.1.3` | FAIL | pam_faillock n'inclut pas root (even_deny_root / root_unlock_time) |
| `CIS.5.4.1.1` | FAIL | pam_pwquality absent de la chaine password |
| `CIS.5.4.1.3` | FAIL | minlen=non defini (attendu >= 14) |
| `CIS.5.4.1.4` | FAIL | minclass=non defini (attendu >= 4) |
| `CIS.4.1.1.1` | FAIL | auditd inactif |
| `CIS.3.2.1.1` | FAIL | seulement 0 modules inutilises desactives (attendu 12) |

## Conformite par perimetre de guide

| Perimetre | Controles | PASS avant | PASS apres | Delta | Echecs restants | Conformite apres |
|---|---|---|---|---|---|---|
| ANSSI BP-028 | 32 | 15 | 32 | 17 | 0 | 100 % |
| Ceph | 11 | 1 | 1 | 0 | 4 | 20 % |
| CIS Debian 13 | 19 | 6 | 10 | 4 | 8 | 55.6 % |
| PVE 9 / OS | 67 | 25 | 40 | 15 | 18 | 69 % |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `ANS.AIDE.DB` | FAIL | PASS | amelioration | base AIDE presente |
| 2 | `ANS.AIDE.INSTALLED` | FAIL | PASS | amelioration | aide installe |
| 3 | `ANS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | aucun profil en mode complain |
| 4 | `ANS.BANNER` | PASS | PASS | inchange | /etc/issue.net present (2 ligne(s)) |
| 5 | `ANS.BOOT.PERM` | FAIL | PASS | amelioration | /boot mode=700 |
| 6 | `ANS.CRON.ALLOW` | FAIL | PASS | amelioration | /etc/cron.allow present |
| 7 | `ANS.CRON.DIR.PERM` | PASS | PASS | inchange | /etc/cron.d en 700 |
| 8 | `ANS.CRON.PERM` | PASS | PASS | inchange | /etc/crontab en 600 |
| 9 | `ANS.CTRLALTDEL` | FAIL | PASS | amelioration | ctrl-alt-del.target desactive |
| 10 | `ANS.FIC.GROUP.PERM` | PASS | PASS | inchange | /etc/group 644 |
| 11 | `ANS.FIC.GSHADOW.PERM` | PASS | PASS | inchange | /etc/gshadow 640 |
| 12 | `ANS.FIC.PASSWD.PERM` | PASS | PASS | inchange | /etc/passwd 644 root root |
| 13 | `ANS.FIC.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow 640 root shadow |
| 14 | `ANS.KERNEL.ASLR` | PASS | PASS | inchange | randomize_va_space=2 |
| 15 | `ANS.KERNEL.BPF` | FAIL | PASS | amelioration | unprivileged_bpf_disabled=1 |
| 16 | `ANS.KERNEL.DMESG` | PASS | PASS | inchange | dmesg_restrict=1 |
| 17 | `ANS.KERNEL.JIT` | FAIL | PASS | amelioration | bpf_jit_harden=2 |
| 18 | `ANS.KERNEL.KPTR` | FAIL | PASS | amelioration | kptr_restrict=2 |
| 19 | `ANS.KERNEL.PTRACE` | PASS | PASS | inchange | ptrace_scope=1 |
| 20 | `ANS.KERNEL.SYMLINK` | PASS | PASS | inchange | protected_symlinks=1 |
| 21 | `ANS.LOGIN.UMASK` | FAIL | PASS | amelioration | UMASK=027 |
| 22 | `ANS.PASSWORD.AGING` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 23 | `ANS.RSYSLOG.ACTIVE` | FAIL | PASS | amelioration | rsyslog actif |
| 24 | `ANS.RSYSLOG.REMOTE` | FAIL | PASS | amelioration | transfert distant configure (omfwd) |
| 25 | `ANS.SERVICES.AVAHI` | PASS | PASS | inchange | avahi-daemon inactif |
| 26 | `ANS.SERVICES.NETWORK` | PASS | PASS | inchange | aucun service reseau legacy actif |
| 27 | `ANS.SESSION.TMOUT` | FAIL | PASS | amelioration | TMOUT=900 |
| 28 | `ANS.SSH.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 29 | `ANS.SSH.ROOTLOGIN` | FAIL | PASS | amelioration | PermitRootLogin=no global, exception restreinte a 10.0.2.0/24 (guide PVE 9 option B) |
| 30 | `ANS.USBSTORAGE` | FAIL | PASS | amelioration | usb-storage desactive |
| 31 | `ANS.USR.NOLOGIN` | PASS | PASS | inchange | comptes systeme sans shell interactif |
| 32 | `ANS.USR.UID0` | PASS | PASS | inchange | root est le seul compte UID 0 |
| 33 | `CEPH.AUTH.CEPHX` | FAIL | FAIL | inchange | cephx non verifiable (conf absente) |
| 34 | `CEPH.CLUSTER` | NA | NA | inchange | aucun cluster Ceph sur ce noeud (mode client seul) |
| 35 | `CEPH.CONF` | FAIL | FAIL | inchange | /etc/ceph/ceph.conf absent |
| 36 | `CEPH.CONF.PERM` | FAIL | FAIL | inchange | /etc/ceph en 755 (attendu 750/700) |
| 37 | `CEPH.DASHBOARD` | NA | NA | inchange | ceph-dashboard non installe (pas de cluster) |
| 38 | `CEPH.KEYRING.PERM` | NA | NA | inchange | aucun keyring present |
| 39 | `CEPH.MGR.MODULES` | NA | NA | inchange | ceph-mgr inactif |
| 40 | `CEPH.MSGR2` | FAIL | FAIL | inchange | chiffrement msgr2 non verifiable (conf absente) |
| 41 | `CEPH.OSD.ENCRYPT` | NA | NA | inchange | ceph.conf absent |
| 42 | `CEPH.PKG` | PASS | PASS | inchange | client ceph installe |
| 43 | `CEPH.POOL.SIZING` | NA | NA | inchange | cluster Ceph injoignable (pas de pool a verifier) |
| 44 | `CIS.3.2.1.1` | FAIL | FAIL | inchange | seulement 0 modules inutilises desactives (attendu 12) |
| 45 | `CIS.4.1.1.1` | FAIL | FAIL | inchange | auditd inactif |
| 46 | `CIS.4.1.2.1` | INFO | PASS | amelioration | rsyslog transfere vers un collecteur distant |
| 47 | `CIS.5.3.3.1.1` | FAIL | FAIL | inchange | pam_faillock sans argument deny= dans les fichiers PAM |
| 48 | `CIS.5.3.3.1.2` | FAIL | FAIL | inchange | pam_faillock sans argument unlock_time= dans les fichiers PAM |
| 49 | `CIS.5.3.3.1.3` | FAIL | FAIL | inchange | pam_faillock n'inclut pas root (even_deny_root / root_unlock_time) |
| 50 | `CIS.5.4.1.1` | FAIL | FAIL | inchange | pam_pwquality absent de la chaine password |
| 51 | `CIS.5.4.1.2` | NA | NA | inchange | pam_pwquality non configure |
| 52 | `CIS.5.4.1.3` | FAIL | FAIL | inchange | minlen=non defini (attendu >= 14) |
| 53 | `CIS.5.4.1.4` | FAIL | FAIL | inchange | minclass=non defini (attendu >= 4) |
| 54 | `CIS.5.4.2.1` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 55 | `CIS.5.4.2.2` | FAIL | PASS | amelioration | PASS_MIN_DAYS=1 |
| 56 | `CIS.5.4.2.3` | PASS | PASS | inchange | PASS_WARN_AGE=7 |
| 57 | `CIS.5.4.3.1` | FAIL | PASS | amelioration | UMASK=027 |
| 58 | `CIS.6.1.2.1` | PASS | PASS | inchange | /etc/passwd en 644 |
| 59 | `CIS.6.1.2.2` | PASS | PASS | inchange | /etc/shadow en 640 |
| 60 | `CIS.6.1.2.3` | PASS | PASS | inchange | /etc/group en 644 |
| 61 | `CIS.6.1.2.4` | PASS | PASS | inchange | /etc/gshadow en 640 |
| 62 | `CIS.6.1.3.1` | PASS | PASS | inchange | /root en 700 |
| 63 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 64 | `OS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | 119 profils en enforce, 0 en complain |
| 65 | `OS.AUDITD.ACTIVE` | FAIL | FAIL | inchange | auditd inactif ou absent |
| 66 | `OS.AUDITD.PVE` | FAIL | FAIL | inchange | aucune regle d'audit sur /etc/pve |
| 67 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 68 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 69 | `OS.CRON.CRONTAB` | FAIL | PASS | amelioration | /etc/crontab en 600 |
| 70 | `OS.CRON.DIR.cron.d` | FAIL | PASS | amelioration | /etc/cron.d en 700 |
| 71 | `OS.CRON.DIR.cron.daily` | FAIL | PASS | amelioration | /etc/cron.daily en 700 |
| 72 | `OS.CRON.DIR.cron.hourly` | FAIL | PASS | amelioration | /etc/cron.hourly en 700 |
| 73 | `OS.CRON.DIR.cron.monthly` | FAIL | PASS | amelioration | /etc/cron.monthly en 700 |
| 74 | `OS.CRON.DIR.cron.weekly` | FAIL | PASS | amelioration | /etc/cron.weekly en 700 |
| 75 | `OS.JOURNALD.Compress` | FAIL | FAIL | inchange | Compress != yes |
| 76 | `OS.JOURNALD.Storage` | FAIL | FAIL | inchange | Storage != persistent |
| 77 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs non charge |
| 78 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs non charge |
| 79 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs non charge |
| 80 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus non charge |
| 81 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 non charge |
| 82 | `OS.MOUNT._dev_shm` | FAIL | FAIL | inchange | /dev/shm opts=rw,nosuid,nodev,inode64 (manquant: noexec ) |
| 83 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,nr_inodes=1048576,inode64 |
| 84 | `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| 85 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm non charge |
| 86 | `OS.NETMOD.can` | PASS | PASS | inchange | module can non charge |
| 87 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp non charge |
| 88 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds non charge |
| 89 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp non charge |
| 90 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc non charge |
| 91 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 92 | `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| 93 | `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| 94 | `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| 95 | `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| 96 | `OS.ROOTKIT.TOOL` | FAIL | FAIL | inchange | ni rkhunter ni chkrootkit installes |
| 97 | `OS.RSYSLOG` | INFO | PASS | amelioration | rsyslog actif |
| 98 | `OS.SSHD.ALLOWLIST` | FAIL | PASS | amelioration | AllowUsers=root AllowGroups=none |
| 99 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 100 | `OS.SSHD.CLIENTALIVE` | FAIL | PASS | amelioration | ClientAliveInterval=300 CountMax=2 |
| 101 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 102 | `OS.SSHD.GRACETIME` | FAIL | PASS | amelioration | LoginGraceTime=30 |
| 103 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 104 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 105 | `OS.SSHD.MACS` | FAIL | PASS | amelioration | MACs sans algorithme faible |
| 106 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 107 | `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 108 | `OS.SSHD.PERM.sshd_config` | FAIL | FAIL | inchange | /etc/ssh/sshd_config en 644 (attendu 600) |
| 109 | `OS.SSHD.PERM.sshd_config.d` | FAIL | FAIL | inchange | /etc/ssh/sshd_config.d en 755 (attendu 700) |
| 110 | `OS.SSHD.PERMITROOT` | FAIL | PASS | amelioration | PermitRootLogin=no |
| 111 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 112 | `OS.SSHD.X11` | FAIL | PASS | amelioration | X11Forwarding=no |
| 113 | `OS.UNATTENDED.ENABLED` | FAIL | FAIL | inchange | mises a jour automatiques non activees |
| 114 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 115 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 116 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 117 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 118 | `PVE.CRYPT.LUKS` | NA | NA | inchange | chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2) |
| 119 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 120 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 121 | `PVE.FW.CLUSTER` | FAIL | FAIL | inchange | /etc/pve/firewall/cluster.fw absent (pare-feu cluster desactive) |
| 122 | `PVE.FW.FORWARD` | NA | NA | inchange | pas de configuration firewall par noeud |
| 123 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 124 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 125 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 126 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 127 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 128 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 129 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

