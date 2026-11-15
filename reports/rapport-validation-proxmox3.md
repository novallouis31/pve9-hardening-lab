# Validation croisee - Proxmox VE 9 (VM independante) - stack CIS L2 + ANSSI N3 + Ceph

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261112-204042`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-205511`
- **Genere le** : 2026-11-12 21:13:46

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 68 | 146 | +78 |
| Controles en echec (FAIL) | 72 | 0 | (-78) |
| Regressions | - | 0 | |
| Ameliorations | - | 78 | |
| Tests fonctionnels PASS | 62 | 71 | +9 |
| Regressions fonctionnelles | - | 0 | |
| Tests fonctionnels Proxmox (PASS / total) | 22 / 23 | 22 / 23 | +0 |
| Tests fonctionnels Proxmox (FAIL) | - | 0 | |
| Tests fonctionnels OS (PASS / total) | 40 / 49 | 49 / 49 | +9 |
| Tests fonctionnels OS (FAIL) | - | 0 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `OS.MOUNT._var_tmp` | FAIL | PASS | /var/tmp opts=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
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
| `OS.RSYSLOG` | INFO | PASS | rsyslog actif |
| `OS.SSHD.PERM.sshd_config` | FAIL | PASS | /etc/ssh/sshd_config en 600 |
| `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | /etc/ssh/sshd_config.d en 700 |
| `OS.SSHD.PERMITROOT` | FAIL | PASS | PermitRootLogin=no |
| `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | PasswordAuthentication=no |
| `OS.SSHD.X11` | FAIL | PASS | X11Forwarding=no |
| `OS.SSHD.GRACETIME` | FAIL | PASS | LoginGraceTime=30 |
| `OS.SSHD.ALLOWLIST` | FAIL | PASS | AllowUsers=root AllowGroups=none |
| `OS.SSHD.CLIENTALIVE` | FAIL | PASS | ClientAliveInterval=300 CountMax=2 |
| `OS.SSHD.MACS` | FAIL | PASS | MACs sans algorithme faible |
| `OS.PAM.FAILLOCK` | FAIL | PASS | pam_faillock configure |
| `OS.PAM.FAILLOCK.POLICY` | FAIL | PASS | deny=5 unlock_time=900 |
| `OS.PAM.PWQUALITY` | FAIL | PASS | libpam-pwquality / cracklib installe |
| `OS.PAM.MINLEN` | FAIL | PASS | minlen=14 |
| `OS.APPARMOR.ENFORCE` | FAIL | PASS | 119 profils en enforce, 0 en complain |
| `OS.UNATTENDED.PKG` | FAIL | PASS | unattended-upgrades installe |
| `OS.UNATTENDED.ENABLED` | FAIL | PASS | mises a jour automatiques activees |
| `PVE.F2B.PKG` | FAIL | PASS | fail2ban installe |
| `PVE.F2B.GUI` | FAIL | PASS | fail2ban protege l'interface web Proxmox |
| `PVE.FW.CLUSTER` | FAIL | PASS | /etc/pve/firewall/cluster.fw present |
| `PVE.FW.FORWARD` | NA | PASS | politique INPUT/FORWARD = DROP (enable: 1;policy_in: DROP;policy_out: ACCEPT;) |
| `OS.ROOTKIT.TOOL` | FAIL | PASS | outil de detection de rootkit installe |
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
| `CEPH.CONF` | FAIL | PASS | /etc/ceph/ceph.conf present |
| `CEPH.AUTH.CEPHX` | FAIL | PASS | cephx exige pour client/cluster/service |
| `CEPH.MSGR2` | FAIL | PASS | chiffrement msgr2 actif (bind+encrypt+modes secure) |
| `CEPH.CONF.PERM` | FAIL | PASS | /etc/ceph en 750 |
| `CEPH.OSD.ENCRYPT` | NA | PASS | chiffrement des OSD declare |
| `CIS.5.3.3.1.1` | FAIL | PASS | pam_faillock deny=5 sur /etc/pam.d/common-auth |
| `CIS.5.3.3.1.2` | FAIL | PASS | pam_faillock unlock_time=900 sur /etc/pam.d/common-auth |
| `CIS.5.3.3.1.3` | FAIL | PASS | pam_faillock inclut root sur /etc/pam.d/common-auth |
| `CIS.5.4.1.1` | FAIL | PASS | pam_pwquality utilise dans /etc/pam.d/common-password |
| `CIS.5.4.1.2` | NA | PASS | pam_pwquality retry=3 |
| `CIS.5.4.1.3` | FAIL | PASS | minlen=14 (>= 14) |
| `CIS.5.4.1.4` | FAIL | PASS | minclass=4 (>= 4) |
| `CIS.5.4.2.1` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `CIS.5.4.2.2` | FAIL | PASS | PASS_MIN_DAYS=1 |
| `CIS.5.4.3.1` | FAIL | PASS | UMASK=027 |
| `CIS.4.1.1.1` | FAIL | PASS | auditd actif avec regles /etc/pve |
| `CIS.3.2.1.1` | FAIL | PASS | 12 modules inutilises desactives |
| `CIS.4.1.2.1` | INFO | PASS | rsyslog transfere vers un collecteur distant |
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv4.conf.all.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv4.conf.default.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_SEND_REDIRECTS` | FAIL | PASS | net.ipv4.conf.all.send_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_SEND_REDIRECTS` | FAIL | PASS | net.ipv4.conf.default.send_redirects=0 |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv6.conf.all.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_RA` | FAIL | PASS | net.ipv6.conf.all.accept_ra=0 |
| `COMM.SYSCTL.KERNEL_KPTR_RESTRICT` | FAIL | PASS | kernel.kptr_restrict=2 |
| `COMM.JOURNALD.STORAGE` | INFO | PASS | Storage=persistent;Compress=yes; |
| `COMM.CTRLALTDEL` | FAIL | PASS | ctrl-alt-del.target desactive |

## Conformite par perimetre de guide

| Perimetre | Controles | PASS avant | PASS apres | Delta | Echecs restants | Conformite apres |
|---|---|---|---|---|---|---|
| ANSSI BP-028 | 32 | 15 | 32 | 17 | 0 | 100 % |
| Ceph | 11 | 1 | 6 | 5 | 0 | 100 % |
| CIS Debian 13 | 19 | 6 | 19 | 13 | 0 | 100 % |
| Communautaire (harbian/BP-028) | 31 | 20 | 29 | 9 | 0 | 100 % |
| PVE 9 / OS | 67 | 25 | 59 | 34 | 0 | 100 % |

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
| 33 | `CEPH.AUTH.CEPHX` | FAIL | PASS | amelioration | cephx exige pour client/cluster/service |
| 34 | `CEPH.CLUSTER` | NA | NA | inchange | aucun cluster Ceph sur ce noeud (mode client seul) |
| 35 | `CEPH.CONF` | FAIL | PASS | amelioration | /etc/ceph/ceph.conf present |
| 36 | `CEPH.CONF.PERM` | FAIL | PASS | amelioration | /etc/ceph en 750 |
| 37 | `CEPH.DASHBOARD` | NA | NA | inchange | ceph-dashboard non installe (pas de cluster) |
| 38 | `CEPH.KEYRING.PERM` | NA | NA | inchange | aucun keyring present |
| 39 | `CEPH.MGR.MODULES` | NA | NA | inchange | ceph-mgr inactif |
| 40 | `CEPH.MSGR2` | FAIL | PASS | amelioration | chiffrement msgr2 actif (bind+encrypt+modes secure) |
| 41 | `CEPH.OSD.ENCRYPT` | NA | PASS | amelioration | chiffrement des OSD declare |
| 42 | `CEPH.PKG` | PASS | PASS | inchange | client ceph installe |
| 43 | `CEPH.POOL.SIZING` | NA | NA | inchange | cluster Ceph injoignable (pas de pool a verifier) |
| 44 | `CIS.3.2.1.1` | FAIL | PASS | amelioration | 12 modules inutilises desactives |
| 45 | `CIS.4.1.1.1` | FAIL | PASS | amelioration | auditd actif avec regles /etc/pve |
| 46 | `CIS.4.1.2.1` | INFO | PASS | amelioration | rsyslog transfere vers un collecteur distant |
| 47 | `CIS.5.3.3.1.1` | FAIL | PASS | amelioration | pam_faillock deny=5 sur /etc/pam.d/common-auth |
| 48 | `CIS.5.3.3.1.2` | FAIL | PASS | amelioration | pam_faillock unlock_time=900 sur /etc/pam.d/common-auth |
| 49 | `CIS.5.3.3.1.3` | FAIL | PASS | amelioration | pam_faillock inclut root sur /etc/pam.d/common-auth |
| 50 | `CIS.5.4.1.1` | FAIL | PASS | amelioration | pam_pwquality utilise dans /etc/pam.d/common-password |
| 51 | `CIS.5.4.1.2` | NA | PASS | amelioration | pam_pwquality retry=3 |
| 52 | `CIS.5.4.1.3` | FAIL | PASS | amelioration | minlen=14 (>= 14) |
| 53 | `CIS.5.4.1.4` | FAIL | PASS | amelioration | minclass=4 (>= 4) |
| 54 | `CIS.5.4.2.1` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 55 | `CIS.5.4.2.2` | FAIL | PASS | amelioration | PASS_MIN_DAYS=1 |
| 56 | `CIS.5.4.2.3` | PASS | PASS | inchange | PASS_WARN_AGE=7 |
| 57 | `CIS.5.4.3.1` | FAIL | PASS | amelioration | UMASK=027 |
| 58 | `CIS.6.1.2.1` | PASS | PASS | inchange | /etc/passwd en 644 |
| 59 | `CIS.6.1.2.2` | PASS | PASS | inchange | /etc/shadow en 640 |
| 60 | `CIS.6.1.2.3` | PASS | PASS | inchange | /etc/group en 644 |
| 61 | `CIS.6.1.2.4` | PASS | PASS | inchange | /etc/gshadow en 640 |
| 62 | `CIS.6.1.3.1` | PASS | PASS | inchange | /root en 700 |
| 63 | `COMM.CTRLALTDEL` | FAIL | PASS | amelioration | ctrl-alt-del.target desactive |
| 64 | `COMM.FILES.SUID` | INFO | INFO | inchange | 27 fichier(s) SUID sur le systeme de fichiers racine |
| 65 | `COMM.FILES.UNOWNED` | INFO | INFO | inchange | 0 fichier(s) sans proprietaire dans /etc |
| 66 | `COMM.FILES.WORLDWRITABLE` | PASS | PASS | inchange | aucun fichier world-writable dans /etc et les binaires |
| 67 | `COMM.GSHADOW.EMPTY` | PASS | PASS | inchange | aucun groupe avec mot de passe vide |
| 68 | `COMM.HOME.OWNERSHIP` | PASS | PASS | inchange | tous les repertoires personnels appartiennent a leur utilisateur |
| 69 | `COMM.JOURNALD.STORAGE` | INFO | PASS | amelioration | Storage=persistent;Compress=yes; |
| 70 | `COMM.LOG.PERMS` | PASS | PASS | inchange | permissions des repertoires de journaux conformes |
| 71 | `COMM.PASSWD.HASH` | PASS | PASS | inchange | 1 hash(s) moderne(s) (yescrypt=1 sha512=0), 0 obsolete |
| 72 | `COMM.PKG.LEGACY` | PASS | PASS | inchange | aucun paquet reseau legacy installe |
| 73 | `COMM.SUDO.NOAUTH` | PASS | PASS | inchange | aucune directive !authenticate dans les sudoers |
| 74 | `COMM.SUDO.NOPASSWD` | PASS | PASS | inchange | aucune directive NOPASSWD dans les sudoers |
| 75 | `COMM.SYSCTL.FS_PROTECTED_HARDLINKS` | PASS | PASS | inchange | fs.protected_hardlinks=1 |
| 76 | `COMM.SYSCTL.FS_PROTECTED_SYMLINKS` | PASS | PASS | inchange | fs.protected_symlinks=1 |
| 77 | `COMM.SYSCTL.FS_SUID_DUMPABLE` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 78 | `COMM.SYSCTL.KERNEL_DMESG_RESTRICT` | PASS | PASS | inchange | kernel.dmesg_restrict=1 |
| 79 | `COMM.SYSCTL.KERNEL_KPTR_RESTRICT` | FAIL | PASS | amelioration | kernel.kptr_restrict=2 |
| 80 | `COMM.SYSCTL.KERNEL_RANDOMIZE_VA_SPACE` | PASS | PASS | inchange | kernel.randomize_va_space=2 |
| 81 | `COMM.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE` | PASS | PASS | inchange | ptrace_scope=1 (>=1) |
| 82 | `COMM.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | amelioration | net.ipv4.conf.all.accept_redirects=0 |
| 83 | `COMM.SYSCTL.NET_IPV4_CONF_all_RP_FILTER` | PASS | PASS | inchange | rp_filter=2 (1=loose, 2=strict) |
| 84 | `COMM.SYSCTL.NET_IPV4_CONF_ALL_SEND_REDIRECTS` | FAIL | PASS | amelioration | net.ipv4.conf.all.send_redirects=0 |
| 85 | `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_ACCEPT_REDIRECTS` | FAIL | PASS | amelioration | net.ipv4.conf.default.accept_redirects=0 |
| 86 | `COMM.SYSCTL.NET_IPV4_CONF_default_RP_FILTER` | PASS | PASS | inchange | rp_filter=1 (1=loose, 2=strict) |
| 87 | `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_SEND_REDIRECTS` | FAIL | PASS | amelioration | net.ipv4.conf.default.send_redirects=0 |
| 88 | `COMM.SYSCTL.NET_IPV4_ICMP_ECHO_IGNORE_BROADCASTS` | PASS | PASS | inchange | net.ipv4.icmp_echo_ignore_broadcasts=1 |
| 89 | `COMM.SYSCTL.NET_IPV4_TCP_SYNCOOKIES` | PASS | PASS | inchange | net.ipv4.tcp_syncookies=1 |
| 90 | `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_RA` | FAIL | PASS | amelioration | net.ipv6.conf.all.accept_ra=0 |
| 91 | `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | amelioration | net.ipv6.conf.all.accept_redirects=0 |
| 92 | `COMM.USR.EMPTY.PASSWORD` | PASS | PASS | inchange | aucun compte avec un champ mot de passe vide |
| 93 | `COMM.USR.NOBODY.UID` | PASS | PASS | inchange | nobody a l'UID 65534 |
| 94 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 95 | `OS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | 119 profils en enforce, 0 en complain |
| 96 | `OS.AUDITD.ACTIVE` | FAIL | PASS | amelioration | auditd actif |
| 97 | `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| 98 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 99 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 100 | `OS.CRON.CRONTAB` | FAIL | PASS | amelioration | /etc/crontab en 600 |
| 101 | `OS.CRON.DIR.cron.d` | FAIL | PASS | amelioration | /etc/cron.d en 700 |
| 102 | `OS.CRON.DIR.cron.daily` | FAIL | PASS | amelioration | /etc/cron.daily en 700 |
| 103 | `OS.CRON.DIR.cron.hourly` | FAIL | PASS | amelioration | /etc/cron.hourly en 700 |
| 104 | `OS.CRON.DIR.cron.monthly` | FAIL | PASS | amelioration | /etc/cron.monthly en 700 |
| 105 | `OS.CRON.DIR.cron.weekly` | FAIL | PASS | amelioration | /etc/cron.weekly en 700 |
| 106 | `OS.JOURNALD.Compress` | FAIL | PASS | amelioration | Compress=yes |
| 107 | `OS.JOURNALD.Storage` | FAIL | PASS | amelioration | Storage=persistent |
| 108 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 109 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 110 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 111 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 112 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 113 | `OS.MOUNT._dev_shm` | FAIL | PASS | amelioration | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 114 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,nr_inodes=1048576,inode64 |
| 115 | `OS.MOUNT._var_tmp` | FAIL | PASS | amelioration | /var/tmp opts=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 116 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 117 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 118 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 119 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 120 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 121 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 122 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 123 | `OS.PAM.FAILLOCK` | FAIL | PASS | amelioration | pam_faillock configure |
| 124 | `OS.PAM.FAILLOCK.POLICY` | FAIL | PASS | amelioration | deny=5 unlock_time=900 |
| 125 | `OS.PAM.MINLEN` | FAIL | PASS | amelioration | minlen=14 |
| 126 | `OS.PAM.PWQUALITY` | FAIL | PASS | amelioration | libpam-pwquality / cracklib installe |
| 127 | `OS.ROOTKIT.TOOL` | FAIL | PASS | amelioration | outil de detection de rootkit installe |
| 128 | `OS.RSYSLOG` | INFO | PASS | amelioration | rsyslog actif |
| 129 | `OS.SSHD.ALLOWLIST` | FAIL | PASS | amelioration | AllowUsers=root AllowGroups=none |
| 130 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 131 | `OS.SSHD.CLIENTALIVE` | FAIL | PASS | amelioration | ClientAliveInterval=300 CountMax=2 |
| 132 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 133 | `OS.SSHD.GRACETIME` | FAIL | PASS | amelioration | LoginGraceTime=30 |
| 134 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 135 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 136 | `OS.SSHD.MACS` | FAIL | PASS | amelioration | MACs sans algorithme faible |
| 137 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 138 | `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 139 | `OS.SSHD.PERM.sshd_config` | FAIL | PASS | amelioration | /etc/ssh/sshd_config en 600 |
| 140 | `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | amelioration | /etc/ssh/sshd_config.d en 700 |
| 141 | `OS.SSHD.PERMITROOT` | FAIL | PASS | amelioration | PermitRootLogin=no |
| 142 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 143 | `OS.SSHD.X11` | FAIL | PASS | amelioration | X11Forwarding=no |
| 144 | `OS.UNATTENDED.ENABLED` | FAIL | PASS | amelioration | mises a jour automatiques activees |
| 145 | `OS.UNATTENDED.PKG` | FAIL | PASS | amelioration | unattended-upgrades installe |
| 146 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 147 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 148 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 149 | `PVE.CRYPT.LUKS` | NA | NA | inchange | chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2) |
| 150 | `PVE.F2B.GUI` | FAIL | PASS | amelioration | fail2ban protege l'interface web Proxmox |
| 151 | `PVE.F2B.PKG` | FAIL | PASS | amelioration | fail2ban installe |
| 152 | `PVE.FW.CLUSTER` | FAIL | PASS | amelioration | /etc/pve/firewall/cluster.fw present |
| 153 | `PVE.FW.FORWARD` | NA | PASS | amelioration | politique INPUT/FORWARD = DROP (enable: 1;policy_in: DROP;policy_out: ACCEPT;) |
| 154 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 155 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 156 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 157 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 158 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 159 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 160 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

## Tests fonctionnels - avant / apres durcissement

| # | Suite | Test fonctionnel | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|---|
| 1 | Proxmox | `FUNC.FW.API` | PASS | PASS | inchange | options du pare-feu lisibles via l'API |
| 2 | Proxmox | `FUNC.FW.STATUS` | PASS | PASS | inchange | pve-firewall status repond |
| 3 | Proxmox | `FUNC.LOG.JOURNALD` | PASS | PASS | inchange | systemd-journald actif |
| 4 | Proxmox | `FUNC.LXC.CREATE` | PASS | PASS | inchange | conteneur LXC 99999 cree sur dir |
| 5 | Proxmox | `FUNC.LXC.DESTROY` | PASS | PASS | inchange | conteneur LXC 99999 supprime (aucun residu) |
| 6 | Proxmox | `FUNC.LXC.RUNNING` | WARN | WARN | inchange | conteneur LXC 99999 non lance |
| 7 | Proxmox | `FUNC.NET.GATEWAY` | PASS | PASS | inchange | passerelle NAT 10.0.2.2 joignable |
| 8 | Proxmox | `FUNC.NET.IFACE` | PASS | PASS | inchange | au moins une interface reseau est UP |
| 9 | Proxmox | `FUNC.NET.VMBR0` | PASS | PASS | inchange | pont vmbr0 present |
| 10 | Proxmox | `FUNC.NODE.ONLINE` | PASS | PASS | inchange | noeud localhost en ligne |
| 11 | Proxmox | `FUNC.PVE.API` | PASS | PASS | inchange | API pvesh fonctionnelle |
| 12 | Proxmox | `FUNC.PVEAM.UPDATE` | PASS | PASS | inchange | pveam update operationnel |
| 13 | Proxmox | `FUNC.SSH.KEYAUTH` | PASS | PASS | inchange | 1 cle(s) publique(s) autorisee(s) pour root |
| 14 | Proxmox | `FUNC.STORE.ACTIVE` | PASS | PASS | inchange | au moins un depot de stockage est actif |
| 15 | Proxmox | `FUNC.STORE.LIST` | PASS | PASS | inchange | pvesm status : 2 entrepot(s) disponible(s) |
| 16 | Proxmox | `FUNC.SVC.pvedaemon` | PASS | PASS | inchange | pvedaemon actif |
| 17 | Proxmox | `FUNC.SVC.pve-firewall` | PASS | PASS | inchange | pve-firewall actif |
| 18 | Proxmox | `FUNC.SVC.pveproxy` | PASS | PASS | inchange | pveproxy actif |
| 19 | Proxmox | `FUNC.SVC.pvestatd` | PASS | PASS | inchange | pvestatd actif |
| 20 | Proxmox | `FUNC.SVC.ssh` | PASS | PASS | inchange | ssh actif |
| 21 | Proxmox | `FUNC.TASKS.LIST` | PASS | PASS | inchange | liste des taches accessible |
| 22 | Proxmox | `FUNC.TLS.CERT` | PASS | PASS | inchange | certificat TLS valide : /etc/pve/local/pve-ssl.pem |
| 23 | Proxmox | `FUNC.WEB.ACCESSIBLE` | PASS | PASS | inchange | Web UI sur 8006 repond (HTTP 200) |
| 24 | OS | `OS.APPARMOR.LOADED` | PASS | PASS | inchange | 119 profil(s) AppArmor charges |
| 25 | OS | `OS.APPARMOR.MODULE` | PASS | PASS | inchange | module AppArmor charge dans le noyau |
| 26 | OS | `OS.APT.CHECK` | PASS | PASS | inchange | apt-get check : dependances coherentes |
| 27 | OS | `OS.APT.UPDATE` | FAIL | PASS | amelioration | apt-get update operationnel (depot joignable) |
| 28 | OS | `OS.CRON.ALLOW` | PASS | PASS | inchange | aucune restriction /etc/cron.allow pour root |
| 29 | OS | `OS.CRON.CRONTAB` | PASS | PASS | inchange | commande crontab operationnelle |
| 30 | OS | `OS.CRON.DAEMON` | PASS | PASS | inchange | cron actif |
| 31 | OS | `OS.DPKG.CONSISTENT` | PASS | PASS | inchange | aucun paquet en configuration incomplete |
| 32 | OS | `OS.FS.DISK` | PASS | PASS | inchange | espace disque racine : 19% utilise |
| 33 | OS | `OS.FS.INODES` | PASS | PASS | inchange | inodes racine : 4% utilise |
| 34 | OS | `OS.FS.MOUNT` | PASS | PASS | inchange | commande mount operationnelle |
| 35 | OS | `OS.FS.OPTIONS._dev_shm` | PASS | PASS | inchange | /dev/shm options=rw,nosuid,nodev,noexec,inode64 |
| 36 | OS | `OS.FS.OPTIONS._tmp` | PASS | PASS | inchange | /tmp options=rw,nosuid,nodev,nr_inodes=1048576,inode64 |
| 37 | OS | `OS.FS.OPTIONS._var_tmp` | WARN | PASS | amelioration | /var/tmp options=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 38 | OS | `OS.FS.TMP` | PASS | PASS | inchange | /tmp accessible en ecriture |
| 39 | OS | `OS.FS.WRITABLE` | PASS | PASS | inchange | racine accessible en ecriture |
| 40 | OS | `OS.KERNEL.MODULES` | PASS | PASS | inchange | 99 module(s) charge(s) |
| 41 | OS | `OS.KERNEL.PROC` | PASS | PASS | inchange | /proc/sys accessible en lecture |
| 42 | OS | `OS.LIMITS.COREDUMP` | PASS | PASS | inchange | core dump desactive (ulimit -c = 0) |
| 43 | OS | `OS.LIMITS.NOFILE` | PASS | PASS | inchange | ulimit -n = 1024 |
| 44 | OS | `OS.LOCALE` | PASS | PASS | inchange | locale operationnelle (LANG=en_US.UTF-8) |
| 45 | OS | `OS.LOG.AUDITD` | NA | PASS | amelioration | auditd actif |
| 46 | OS | `OS.LOG.JOURNALD.READ` | PASS | PASS | inchange | journald actif et lisible |
| 47 | OS | `OS.LOG.RSYSLOG` | NA | PASS | amelioration | rsyslog actif |
| 48 | OS | `OS.NET.DNS` | WARN | PASS | amelioration | resolution DNS operationnelle |
| 49 | OS | `OS.NET.LOOPBACK` | PASS | PASS | inchange | interface loopback active |
| 50 | OS | `OS.NET.PINGLOCAL` | PASS | PASS | inchange | 127.0.0.1 joignable |
| 51 | OS | `OS.NET.ROUTE` | PASS | PASS | inchange | default via 10.0.2.2 dev vmbr0 proto kernel onlink  |
| 52 | OS | `OS.PAM.CHAINS` | PASS | PASS | inchange | chaines PAM communes presentes |
| 53 | OS | `OS.SUDO.WORK` | NA | PASS | amelioration | sudo operationnel (acces root sans mot de passe) |
| 54 | OS | `OS.SVC.systemd-journald` | PASS | PASS | inchange | systemd-journald actif |
| 55 | OS | `OS.SVC.systemd-logind` | PASS | PASS | inchange | systemd-logind actif |
| 56 | OS | `OS.SVC.TIMESYNC` | PASS | PASS | inchange | chrony actif (service de synchronisation horaire) |
| 57 | OS | `OS.SYSCTL.CONFFILES` | NA | PASS | amelioration | 3 fichier(s) de configuration sysctl |
| 58 | OS | `OS.SYSCTL.FS_PROTECTED_SYMLINKS` | PASS | PASS | inchange | fs.protected_symlinks=1 |
| 59 | OS | `OS.SYSCTL.FS_SUID_DUMPABLE` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 60 | OS | `OS.SYSCTL.KERNEL_DMESG_RESTRICT` | PASS | PASS | inchange | kernel.dmesg_restrict=1 |
| 61 | OS | `OS.SYSCTL.KERNEL_RANDOMIZE_VA_SPACE` | PASS | PASS | inchange | kernel.randomize_va_space=2 |
| 62 | OS | `OS.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE` | PASS | PASS | inchange | kernel.yama.ptrace_scope=1 |
| 63 | OS | `OS.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | WARN | PASS | amelioration | net.ipv4.conf.all.accept_redirects=0 |
| 64 | OS | `OS.SYSCTL.NET_IPV4_ICMP_ECHO_IGNORE_BROADCASTS` | PASS | PASS | inchange | net.ipv4.icmp_echo_ignore_broadcasts=1 |
| 65 | OS | `OS.SYSCTL.NET_IPV4_TCP_SYNCOOKIES` | PASS | PASS | inchange | net.ipv4.tcp_syncookies=1 |
| 66 | OS | `OS.SYSTEMD.NOFAILED` | PASS | PASS | inchange | aucune unite systemd en echec |
| 67 | OS | `OS.SYSTEMD.STATE` | PASS | PASS | inchange | systeme en etat 'running' |
| 68 | OS | `OS.TIME.CLOCK` | PASS | PASS | inchange | date operationnelle (2026-11-12T20:54:51+01:00) |
| 69 | OS | `OS.TIME.SYNC` | PASS | PASS | inchange | horloge synchronisee (NTP) |
| 70 | OS | `OS.TIMEZONE` | PASS | PASS | inchange | fuseau horaire : /usr/share/zoneinfo/Europe/Paris |
| 71 | OS | `OS.USER.NONROOT` | WARN | PASS | amelioration | 1 compte(s) utilisateur(s) avec shell interactif |
| 72 | OS | `OS.USER.ROOT` | PASS | PASS | inchange | compte root present |

## Tests fonctionnels - synthese par suite (non-regression)

| Suite | Tests | PASS av. | PASS ap. | FAIL av. | FAIL ap. | WARN av. | WARN ap. | NA av. | NA ap. | Regression | Controle somme |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Proxmox | 23 | 22 | 22 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | OK (23/23) |
| OS | 49 | 40 | 49 | 1 | 0 | 4 | 0 | 4 | 0 | 0 | OK (49/49) |
| TOTAL | 72 | 62 | 71 | 1 | 0 | 5 | 1 | 4 | 0 | 0 | av.=72/72 ap.=72/72 OK |

## Tests fonctionnels - tests non conformes (WARN / NA) documentes

| # | Suite | Test | Statut avant | Statut apres | Detail (apres) |
|---|---|---|---|---|---|
| 1 | Proxmox | `FUNC.LXC.RUNNING` | WARN | WARN | conteneur LXC 99999 non lance |
| 2 | OS | `OS.APT.UPDATE` | FAIL | PASS | apt-get update operationnel (depot joignable) |
| 3 | OS | `OS.FS.OPTIONS._var_tmp` | WARN | PASS | /var/tmp options=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 4 | OS | `OS.LOG.AUDITD` | NA | PASS | auditd actif |
| 5 | OS | `OS.LOG.RSYSLOG` | NA | PASS | rsyslog actif |
| 6 | OS | `OS.NET.DNS` | WARN | PASS | resolution DNS operationnelle |
| 7 | OS | `OS.SUDO.WORK` | NA | PASS | sudo operationnel (acces root sans mot de passe) |
| 8 | OS | `OS.SYSCTL.CONFFILES` | NA | PASS | 3 fichier(s) de configuration sysctl |
| 9 | OS | `OS.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | WARN | PASS | net.ipv4.conf.all.accept_redirects=0 |
| 10 | OS | `OS.USER.NONROOT` | WARN | PASS | 1 compte(s) utilisateur(s) avec shell interactif |

