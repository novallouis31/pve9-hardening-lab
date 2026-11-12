# CIS Debian 13 Level 2 + guide PVE 9 - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261112-142430`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-142851`
- **Genere le** : 2026-11-12 14:41:40

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 68 | 132 | +64 |
| Controles en echec (FAIL) | 72 | 11 | (-64) |
| Regressions | - | 0 | |
| Ameliorations | - | 64 | |
| Tests fonctionnels PASS | 59 | 63 | +4 |
| Regressions fonctionnelles | - | 2 | |
| Tests fonctionnels Proxmox (PASS / total) | 19 / 21 | 19 / 21 | +0 |
| Tests fonctionnels Proxmox (FAIL) | - | 0 | |
| Tests fonctionnels OS (PASS / total) | 40 / 48 | 44 / 48 | +4 |
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
| `ANS.PASSWORD.AGING` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `ANS.APPARMOR.ENFORCE` | FAIL | PASS | aucun profil en mode complain |
| `ANS.LOGIN.UMASK` | FAIL | PASS | UMASK=027 |
| `ANS.SSH.ROOTLOGIN` | FAIL | PASS | PermitRootLogin=no global, exception restreinte a 10.0.2.0/24 (guide PVE 9 option B) |
| `ANS.SSH.PASSWORDAUTH` | FAIL | PASS | PasswordAuthentication=no |
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
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv4.conf.all.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv4.conf.default.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_ALL_SEND_REDIRECTS` | FAIL | PASS | net.ipv4.conf.all.send_redirects=0 |
| `COMM.SYSCTL.NET_IPV4_CONF_DEFAULT_SEND_REDIRECTS` | FAIL | PASS | net.ipv4.conf.default.send_redirects=0 |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_REDIRECTS` | FAIL | PASS | net.ipv6.conf.all.accept_redirects=0 |
| `COMM.SYSCTL.NET_IPV6_CONF_ALL_ACCEPT_RA` | FAIL | PASS | net.ipv6.conf.all.accept_ra=0 |
| `COMM.SYSCTL.KERNEL_KPTR_RESTRICT` | FAIL | PASS | kernel.kptr_restrict=2 |
| `COMM.JOURNALD.STORAGE` | INFO | PASS | Storage=persistent;Compress=yes; |
| `COMM.CTRLALTDEL` | FAIL | PASS | ctrl-alt-del.target desactive |

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
| `ANS.SESSION.TMOUT` | FAIL | TMOUT=non defini (attendu <= 900) |
| `ANS.AIDE.INSTALLED` | FAIL | aide absent |
| `ANS.AIDE.DB` | FAIL | base AIDE absente (aide --init non lance) |
| `ANS.RSYSLOG.REMOTE` | FAIL | aucun transfert distant (centralisation des journaux non configuree) |
| `ANS.RSYSLOG.ACTIVE` | FAIL | rsyslog absent |
| `ANS.USBSTORAGE` | FAIL | usb-storage non desactive |
| `ANS.CRON.ALLOW` | FAIL | /etc/cron.allow absent (cron non restreint) |
| `CEPH.CONF` | FAIL | /etc/ceph/ceph.conf absent |
| `CEPH.AUTH.CEPHX` | FAIL | cephx non verifiable (conf absente) |
| `CEPH.MSGR2` | FAIL | chiffrement msgr2 non verifiable (conf absente) |
| `CEPH.CONF.PERM` | FAIL | /etc/ceph en 755 (attendu 750/700) |

## Conformite par perimetre de guide

| Perimetre | Controles | PASS avant | PASS apres | Delta | Echecs restants | Conformite apres |
|---|---|---|---|---|---|---|
| ANSSI BP-028 | 32 | 15 | 25 | 10 | 7 | 78.1 % |
| Ceph | 11 | 1 | 1 | 0 | 4 | 20 % |
| CIS Debian 13 | 19 | 6 | 18 | 12 | 0 | 100 % |
| Communautaire (harbian/BP-028) | 31 | 20 | 29 | 9 | 0 | 100 % |
| PVE 9 / OS | 67 | 25 | 58 | 33 | 0 | 100 % |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `ANS.AIDE.DB` | FAIL | FAIL | inchange | base AIDE absente (aide --init non lance) |
| 2 | `ANS.AIDE.INSTALLED` | FAIL | FAIL | inchange | aide absent |
| 3 | `ANS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | aucun profil en mode complain |
| 4 | `ANS.BANNER` | PASS | PASS | inchange | /etc/issue.net present (1 ligne(s)) |
| 5 | `ANS.BOOT.PERM` | FAIL | PASS | amelioration | /boot mode=700 |
| 6 | `ANS.CRON.ALLOW` | FAIL | FAIL | inchange | /etc/cron.allow absent (cron non restreint) |
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
| 19 | `ANS.KERNEL.PTRACE` | PASS | PASS | inchange | ptrace_scope=2 |
| 20 | `ANS.KERNEL.SYMLINK` | PASS | PASS | inchange | protected_symlinks=1 |
| 21 | `ANS.LOGIN.UMASK` | FAIL | PASS | amelioration | UMASK=027 |
| 22 | `ANS.PASSWORD.AGING` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 23 | `ANS.RSYSLOG.ACTIVE` | FAIL | FAIL | inchange | rsyslog absent |
| 24 | `ANS.RSYSLOG.REMOTE` | FAIL | FAIL | inchange | aucun transfert distant (centralisation des journaux non configuree) |
| 25 | `ANS.SERVICES.AVAHI` | PASS | PASS | inchange | avahi-daemon inactif |
| 26 | `ANS.SERVICES.NETWORK` | PASS | PASS | inchange | aucun service reseau legacy actif |
| 27 | `ANS.SESSION.TMOUT` | FAIL | FAIL | inchange | TMOUT=non defini (attendu <= 900) |
| 28 | `ANS.SSH.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 29 | `ANS.SSH.ROOTLOGIN` | FAIL | PASS | amelioration | PermitRootLogin=no global, exception restreinte a 10.0.2.0/24 (guide PVE 9 option B) |
| 30 | `ANS.USBSTORAGE` | FAIL | FAIL | inchange | usb-storage non desactive |
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
| 44 | `CIS.3.2.1.1` | FAIL | PASS | amelioration | 12 modules inutilises desactives |
| 45 | `CIS.4.1.1.1` | FAIL | PASS | amelioration | auditd actif avec regles /etc/pve |
| 46 | `CIS.4.1.2.1` | INFO | INFO | inchange | rsyslog : pas de collecteur distant configure (hors perimetre lab) |
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
| 81 | `COMM.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE` | PASS | PASS | inchange | ptrace_scope=2 (>=1) |
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
| 114 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
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
| 128 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
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
| 4 | Proxmox | `FUNC.LXC.CREATE` | NA | NA | inchange | aucun template Debian disponible (pveam update local non execute) |
| 5 | Proxmox | `FUNC.NET.GATEWAY` | PASS | PASS | inchange | passerelle NAT 10.0.2.2 joignable |
| 6 | Proxmox | `FUNC.NET.IFACE` | PASS | PASS | inchange | au moins une interface reseau est UP |
| 7 | Proxmox | `FUNC.NET.VMBR0` | PASS | PASS | inchange | pont vmbr0 present |
| 8 | Proxmox | `FUNC.NODE.ONLINE` | PASS | PASS | inchange | noeud localhost en ligne |
| 9 | Proxmox | `FUNC.PVE.API` | PASS | PASS | inchange | API pvesh fonctionnelle |
| 10 | Proxmox | `FUNC.PVEAM.UPDATE` | PASS | PASS | inchange | pveam update operationnel |
| 11 | Proxmox | `FUNC.SSH.KEYAUTH` | PASS | PASS | inchange | 2 cle(s) publique(s) autorisee(s) pour root |
| 12 | Proxmox | `FUNC.STORE.ACTIVE` | PASS | PASS | inchange | au moins un depot de stockage est actif |
| 13 | Proxmox | `FUNC.STORE.LIST` | PASS | PASS | inchange | pvesm status : 2 entrepot(s) disponible(s) |
| 14 | Proxmox | `FUNC.SVC.pvedaemon` | PASS | PASS | inchange | pvedaemon actif |
| 15 | Proxmox | `FUNC.SVC.pve-firewall` | PASS | PASS | inchange | pve-firewall actif |
| 16 | Proxmox | `FUNC.SVC.pveproxy` | PASS | PASS | inchange | pveproxy actif |
| 17 | Proxmox | `FUNC.SVC.pvestatd` | PASS | PASS | inchange | pvestatd actif |
| 18 | Proxmox | `FUNC.SVC.ssh` | PASS | PASS | inchange | ssh actif |
| 19 | Proxmox | `FUNC.TASKS.LIST` | PASS | PASS | inchange | liste des taches accessible |
| 20 | Proxmox | `FUNC.TLS.CERT` | WARN | WARN | inchange | certificat TLS non trouve |
| 21 | Proxmox | `FUNC.WEB.ACCESSIBLE` | PASS | PASS | inchange | Web UI sur 8006 repond (HTTP 200) |
| 22 | OS | `OS.APPARMOR.LOADED` | PASS | PASS | inchange | 119 profil(s) AppArmor charges |
| 23 | OS | `OS.APPARMOR.MODULE` | PASS | PASS | inchange | module AppArmor charge dans le noyau |
| 24 | OS | `OS.APT.CHECK` | PASS | PASS | inchange | apt-get check : dependances coherentes |
| 25 | OS | `OS.CRON.ALLOW` | PASS | PASS | inchange | aucune restriction /etc/cron.allow pour root |
| 26 | OS | `OS.CRON.CRONTAB` | PASS | PASS | inchange | commande crontab operationnelle |
| 27 | OS | `OS.CRON.DAEMON` | PASS | PASS | inchange | cron actif |
| 28 | OS | `OS.DPKG.CONSISTENT` | PASS | PASS | inchange | aucun paquet en configuration incomplete |
| 29 | OS | `OS.FS.DISK` | PASS | PASS | inchange | espace disque racine : 18% utilise |
| 30 | OS | `OS.FS.INODES` | PASS | PASS | inchange | inodes racine : 4% utilise |
| 31 | OS | `OS.FS.MOUNT` | PASS | PASS | inchange | commande mount operationnelle |
| 32 | OS | `OS.FS.OPTIONS._dev_shm` | PASS | PASS | inchange | /dev/shm options=rw,nosuid,nodev,noexec,inode64 |
| 33 | OS | `OS.FS.OPTIONS._tmp` | PASS | PASS | inchange | /tmp options=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| 34 | OS | `OS.FS.OPTIONS._var_tmp` | WARN | PASS | amelioration | /var/tmp options=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 35 | OS | `OS.FS.TMP` | PASS | PASS | inchange | /tmp accessible en ecriture |
| 36 | OS | `OS.FS.WRITABLE` | PASS | PASS | inchange | racine accessible en ecriture |
| 37 | OS | `OS.KERNEL.MODULES` | PASS | PASS | inchange | 99 module(s) charge(s) |
| 38 | OS | `OS.KERNEL.PROC` | PASS | PASS | inchange | /proc/sys accessible en lecture |
| 39 | OS | `OS.LIMITS.COREDUMP` | PASS | PASS | inchange | core dump desactive (ulimit -c = 0) |
| 40 | OS | `OS.LIMITS.NOFILE` | PASS | PASS | inchange | ulimit -n = 1024 |
| 41 | OS | `OS.LOCALE` | PASS | PASS | inchange | locale operationnelle (LANG=en_US.UTF-8) |
| 42 | OS | `OS.LOG.AUDITD` | NA | PASS | amelioration | auditd actif |
| 43 | OS | `OS.LOG.JOURNALD.READ` | PASS | PASS | inchange | journald actif et lisible |
| 44 | OS | `OS.LOG.RSYSLOG` | NA | NA | inchange | rsyslog absent |
| 45 | OS | `OS.NET.DNS` | PASS | PASS | inchange | resolution DNS operationnelle |
| 46 | OS | `OS.NET.LOOPBACK` | PASS | PASS | inchange | interface loopback active |
| 47 | OS | `OS.NET.PINGLOCAL` | PASS | PASS | inchange | 127.0.0.1 joignable |
| 48 | OS | `OS.NET.ROUTE` | PASS | PASS | inchange | default via 10.0.2.2 dev vmbr0 proto kernel onlink  |
| 49 | OS | `OS.PAM.CHAINS` | PASS | PASS | inchange | chaines PAM communes presentes |
| 50 | OS | `OS.SUDO.WORK` | NA | PASS | amelioration | sudo operationnel (acces root sans mot de passe) |
| 51 | OS | `OS.SVC.systemd-journald` | PASS | PASS | inchange | systemd-journald actif |
| 52 | OS | `OS.SVC.systemd-logind` | PASS | PASS | inchange | systemd-logind actif |
| 53 | OS | `OS.SVC.systemd-timesyncd` | WARN | WARN | inchange | systemd-timesyncd inactif (chrony/systemd-timesyncd non actif ?) |
| 54 | OS | `OS.SYSCTL.CONFFILES` | NA | PASS | amelioration | 2 fichier(s) de configuration sysctl |
| 55 | OS | `OS.SYSCTL.FS_PROTECTED_SYMLINKS` | PASS | PASS | inchange | fs.protected_symlinks=1 |
| 56 | OS | `OS.SYSCTL.FS_SUID_DUMPABLE` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 57 | OS | `OS.SYSCTL.KERNEL_DMESG_RESTRICT` | PASS | PASS | inchange | kernel.dmesg_restrict=1 |
| 58 | OS | `OS.SYSCTL.KERNEL_RANDOMIZE_VA_SPACE` | PASS | PASS | inchange | kernel.randomize_va_space=2 |
| 59 | OS | `OS.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE` | PASS | WARN | REGRESSION | kernel.yama.ptrace_scope=2 (attendu 1) |
| 60 | OS | `OS.SYSCTL.NET_IPV4_CONF_ALL_ACCEPT_REDIRECTS` | WARN | PASS | amelioration | net.ipv4.conf.all.accept_redirects=0 |
| 61 | OS | `OS.SYSCTL.NET_IPV4_ICMP_ECHO_IGNORE_BROADCASTS` | PASS | PASS | inchange | net.ipv4.icmp_echo_ignore_broadcasts=1 |
| 62 | OS | `OS.SYSCTL.NET_IPV4_TCP_SYNCOOKIES` | PASS | PASS | inchange | net.ipv4.tcp_syncookies=1 |
| 63 | OS | `OS.SYSTEMD.NOFAILED` | PASS | WARN | REGRESSION | 1 unite(s) systemd en echec |
| 64 | OS | `OS.SYSTEMD.STATE` | PASS | PASS | inchange | systeme en etat 'degraded' |
| 65 | OS | `OS.TIME.CLOCK` | PASS | PASS | inchange | date operationnelle (2026-11-12T14:28:32+01:00) |
| 66 | OS | `OS.TIME.SYNC` | PASS | PASS | inchange | horloge synchronisee (NTP) |
| 67 | OS | `OS.TIMEZONE` | PASS | PASS | inchange | fuseau horaire : /usr/share/zoneinfo/Europe/Paris |
| 68 | OS | `OS.USER.NONROOT` | WARN | PASS | amelioration | 1 compte(s) utilisateur(s) avec shell interactif |
| 69 | OS | `OS.USER.ROOT` | PASS | PASS | inchange | compte root present |

## Tests fonctionnels - synthese par suite (non-regression)

| Suite | Tests | PASS avant | PASS apres | FAIL avant | FAIL apres | Regression |
|---|---|---|---|---|---|---|
| Proxmox | 21 | 19 | 19 | 0 | 0 | 0 |
| OS | 48 | 40 | 44 | 0 | 0 | 2 |

