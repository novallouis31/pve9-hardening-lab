# Delta CIS L1 vers L2 - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-065646`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-072451`
- **Genere le** : 2026-11-12 07:37:51

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 84 | 84 | +0 |
| Controles en echec (FAIL) | 10 | 11 | +(-0) |
| Regressions | - | 0 | |
| Ameliorations | - | 0 | |

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
| `PVE.FW.FORWARD` | FAIL | politique FORWARD non DROP (enable: 1;) |
| `ANS.AIDE.INSTALLED` | FAIL | aide absent |
| `ANS.AIDE.DB` | FAIL | base AIDE absente (aide --init non lance) |
| `ANS.RSYSLOG.REMOTE` | FAIL | aucun transfert distant (centralisation des journaux non configuree) |
| `ANS.USBSTORAGE` | FAIL | usb-storage non desactive |
| `ANS.SSH.ROOTLOGIN` | FAIL | PermitRootLogin=prohibit-password (ANSSI renforce attend no) |
| `ANS.CRON.ALLOW` | FAIL | /etc/cron.allow absent (cron non restreint) |
| `CEPH.CONF` | FAIL | /etc/ceph/ceph.conf absent |
| `CEPH.AUTH.CEPHX` | FAIL | cephx non verifiable (conf absente) |
| `CEPH.MSGR2` | FAIL | chiffrement msgr2 non verifiable (conf absente) |
| `CEPH.CONF.PERM` | FAIL | /etc/ceph en 755 (attendu 750/700) |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `ANS.AIDE.DB` | FAIL | FAIL | inchange | base AIDE absente (aide --init non lance) |
| 2 | `ANS.AIDE.INSTALLED` | FAIL | FAIL | inchange | aide absent |
| 3 | `ANS.APPARMOR.ENFORCE` | PASS | PASS | inchange | aucun profil en mode complain |
| 4 | `ANS.BOOT.PERM` | PASS | PASS | inchange | /boot mode=700 |
| 5 | `ANS.CRON.ALLOW` | FAIL | FAIL | inchange | /etc/cron.allow absent (cron non restreint) |
| 6 | `ANS.CTRLALTDEL` | PASS | PASS | inchange | ctrl-alt-del.target desactive |
| 7 | `ANS.KERNEL.BPF` | PASS | PASS | inchange | unprivileged_bpf_disabled=1 |
| 8 | `ANS.KERNEL.JIT` | PASS | PASS | inchange | bpf_jit_harden=2 |
| 9 | `ANS.LOGIN.UMASK` | PASS | PASS | inchange | UMASK=027 |
| 10 | `ANS.PASSWORD.AGING` | PASS | PASS | inchange | PASS_MAX_DAYS=90 |
| 11 | `ANS.RSYSLOG.REMOTE` | FAIL | FAIL | inchange | aucun transfert distant (centralisation des journaux non configuree) |
| 12 | `ANS.SERVICES.AVAHI` | PASS | PASS | inchange | avahi-daemon inactif |
| 13 | `ANS.SSH.ROOTLOGIN` | FAIL | FAIL | inchange | PermitRootLogin=prohibit-password (ANSSI renforce attend no) |
| 14 | `ANS.USBSTORAGE` | FAIL | FAIL | inchange | usb-storage non desactive |
| 15 | `CEPH.AUTH.CEPHX` | FAIL | FAIL | inchange | cephx non verifiable (conf absente) |
| 16 | `CEPH.CLUSTER` | NA | NA | inchange | aucun cluster Ceph sur ce noeud (mode client seul) |
| 17 | `CEPH.CONF` | FAIL | FAIL | inchange | /etc/ceph/ceph.conf absent |
| 18 | `CEPH.CONF.PERM` | FAIL | FAIL | inchange | /etc/ceph en 755 (attendu 750/700) |
| 19 | `CEPH.DASHBOARD` | NA | NA | inchange | ceph-dashboard non installe (pas de cluster) |
| 20 | `CEPH.KEYRING.PERM` | NA | NA | inchange | aucun keyring present |
| 21 | `CEPH.MGR.MODULES` | NA | NA | inchange | ceph-mgr inactif |
| 22 | `CEPH.MSGR2` | FAIL | FAIL | inchange | chiffrement msgr2 non verifiable (conf absente) |
| 23 | `CEPH.OSD.ENCRYPT` | NA | NA | inchange | ceph.conf absent |
| 24 | `CEPH.PKG` | PASS | PASS | inchange | client ceph installe |
| 25 | `CEPH.POOL.SIZING` | NA | NA | inchange | cluster Ceph injoignable (pas de pool a verifier) |
| 26 | `CIS.3.2.1.1` | PASS | PASS | inchange | 12 modules inutilises desactives |
| 27 | `CIS.4.1.1.1` | PASS | PASS | inchange | auditd actif avec regles /etc/pve |
| 28 | `CIS.4.1.2.1` | INFO | INFO | inchange | rsyslog : pas de collecteur distant configure (hors perimetre lab) |
| 29 | `CIS.5.3.3.1.1` | PASS | PASS | inchange | pam_faillock deny=5 sur /etc/pam.d/common-auth |
| 30 | `CIS.5.3.3.1.2` | PASS | PASS | inchange | pam_faillock unlock_time=900 sur /etc/pam.d/common-auth |
| 31 | `CIS.5.3.3.1.3` | PASS | PASS | inchange | pam_faillock inclut root sur /etc/pam.d/common-auth |
| 32 | `CIS.5.4.1.1` | PASS | PASS | inchange | pam_pwquality utilise dans /etc/pam.d/common-password |
| 33 | `CIS.5.4.1.2` | PASS | PASS | inchange | pam_pwquality retry=3 |
| 34 | `CIS.5.4.1.3` | PASS | PASS | inchange | minlen=14 (>= 14) |
| 35 | `CIS.5.4.1.4` | PASS | PASS | inchange | minclass=4 (>= 4) |
| 36 | `CIS.5.4.2.1` | PASS | PASS | inchange | PASS_MAX_DAYS=90 |
| 37 | `CIS.5.4.2.2` | PASS | PASS | inchange | PASS_MIN_DAYS=1 |
| 38 | `CIS.5.4.2.3` | PASS | PASS | inchange | PASS_WARN_AGE=7 |
| 39 | `CIS.5.4.3.1` | PASS | PASS | inchange | UMASK=027 |
| 40 | `CIS.6.1.2.1` | PASS | PASS | inchange | /etc/passwd en 644 |
| 41 | `CIS.6.1.2.2` | PASS | PASS | inchange | /etc/shadow en 640 |
| 42 | `CIS.6.1.2.3` | PASS | PASS | inchange | /etc/group en 644 |
| 43 | `CIS.6.1.2.4` | PASS | PASS | inchange | /etc/gshadow en 640 |
| 44 | `CIS.6.1.3.1` | PASS | PASS | inchange | /root en 700 |
| 45 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 46 | `OS.APPARMOR.ENFORCE` | PASS | PASS | inchange | 119 profils en enforce, 0 en complain |
| 47 | `OS.AUDITD.ACTIVE` | PASS | PASS | inchange | auditd actif |
| 48 | `OS.AUDITD.PVE` | PASS | PASS | inchange | regles d'audit sur /etc/pve |
| 49 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 50 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 51 | `OS.CRON.CRONTAB` | PASS | PASS | inchange | /etc/crontab en 600 |
| 52 | `OS.CRON.DIR.cron.d` | PASS | PASS | inchange | /etc/cron.d en 700 |
| 53 | `OS.CRON.DIR.cron.daily` | PASS | PASS | inchange | /etc/cron.daily en 700 |
| 54 | `OS.CRON.DIR.cron.hourly` | PASS | PASS | inchange | /etc/cron.hourly en 700 |
| 55 | `OS.CRON.DIR.cron.monthly` | PASS | PASS | inchange | /etc/cron.monthly en 700 |
| 56 | `OS.CRON.DIR.cron.weekly` | PASS | PASS | inchange | /etc/cron.weekly en 700 |
| 57 | `OS.JOURNALD.Compress` | PASS | PASS | inchange | Compress=yes |
| 58 | `OS.JOURNALD.Storage` | PASS | PASS | inchange | Storage=persistent |
| 59 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 60 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 61 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 62 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 63 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 64 | `OS.MOUNT._dev_shm` | PASS | PASS | inchange | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 65 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,size=4065212k,nr_inodes=1048576,inode64 |
| 66 | `OS.MOUNT._var_tmp` | PASS | PASS | inchange | /var/tmp opts=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 67 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 68 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 69 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 70 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 71 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 72 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 73 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 74 | `OS.PAM.FAILLOCK` | PASS | PASS | inchange | pam_faillock configure |
| 75 | `OS.PAM.FAILLOCK.POLICY` | PASS | PASS | inchange | deny=5 unlock_time=900 |
| 76 | `OS.PAM.MINLEN` | PASS | PASS | inchange | minlen=14 |
| 77 | `OS.PAM.PWQUALITY` | PASS | PASS | inchange | libpam-pwquality / cracklib installe |
| 78 | `OS.ROOTKIT.TOOL` | PASS | PASS | inchange | outil de detection de rootkit installe |
| 79 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 80 | `OS.SSHD.ALLOWLIST` | PASS | PASS | inchange | AllowUsers=root AllowGroups=none |
| 81 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 82 | `OS.SSHD.CLIENTALIVE` | PASS | PASS | inchange | ClientAliveInterval=300 CountMax=2 |
| 83 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 84 | `OS.SSHD.GRACETIME` | PASS | PASS | inchange | LoginGraceTime=30 |
| 85 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 86 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 87 | `OS.SSHD.MACS` | PASS | PASS | inchange | MACs sans algorithme faible |
| 88 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 89 | `OS.SSHD.PASSWORDAUTH` | PASS | PASS | inchange | PasswordAuthentication=no |
| 90 | `OS.SSHD.PERM.sshd_config` | PASS | PASS | inchange | /etc/ssh/sshd_config en 600 |
| 91 | `OS.SSHD.PERM.sshd_config.d` | PASS | PASS | inchange | /etc/ssh/sshd_config.d en 700 |
| 92 | `OS.SSHD.PERMITROOT` | INFO | INFO | inchange | PermitRootLogin=without-password (acces root par cle uniquement) |
| 93 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 94 | `OS.SSHD.X11` | PASS | PASS | inchange | X11Forwarding=no |
| 95 | `OS.UNATTENDED.ENABLED` | PASS | PASS | inchange | mises a jour automatiques activees |
| 96 | `OS.UNATTENDED.PKG` | PASS | PASS | inchange | unattended-upgrades installe |
| 97 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 98 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 99 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 100 | `PVE.CRYPT.LUKS` | NA | NA | inchange | chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2) |
| 101 | `PVE.F2B.GUI` | PASS | PASS | inchange | fail2ban protege l'interface web Proxmox |
| 102 | `PVE.F2B.PKG` | PASS | PASS | inchange | fail2ban installe |
| 103 | `PVE.FW.CLUSTER` | PASS | PASS | inchange | /etc/pve/firewall/cluster.fw present |
| 104 | `PVE.FW.FORWARD` | NA | FAIL | modifie | politique FORWARD non DROP (enable: 1;) |
| 105 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 106 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 107 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 108 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 109 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 110 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 111 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

