# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261112-120257`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-120544`
- **Genere le** : 2026-11-12 12:05:46

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 34 | 85 | +51 |
| Controles en echec (FAIL) | 60 | 10 | (-51) |
| Regressions | - | 0 | |
| Ameliorations | - | 51 | |
| Tests fonctionnels PASS | 19 | 19 | +0 |
| Regressions fonctionnelles | - | 0 | |

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
| `ANS.PASSWORD.AGING` | FAIL | PASS | PASS_MAX_DAYS=90 |
| `ANS.APPARMOR.ENFORCE` | FAIL | PASS | aucun profil en mode complain |
| `ANS.LOGIN.UMASK` | FAIL | PASS | UMASK=027 |
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

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
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
| 3 | `ANS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | aucun profil en mode complain |
| 4 | `ANS.BOOT.PERM` | FAIL | PASS | amelioration | /boot mode=700 |
| 5 | `ANS.CRON.ALLOW` | FAIL | FAIL | inchange | /etc/cron.allow absent (cron non restreint) |
| 6 | `ANS.CTRLALTDEL` | FAIL | PASS | amelioration | ctrl-alt-del.target desactive |
| 7 | `ANS.KERNEL.BPF` | FAIL | PASS | amelioration | unprivileged_bpf_disabled=1 |
| 8 | `ANS.KERNEL.JIT` | FAIL | PASS | amelioration | bpf_jit_harden=2 |
| 9 | `ANS.LOGIN.UMASK` | FAIL | PASS | amelioration | UMASK=027 |
| 10 | `ANS.PASSWORD.AGING` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
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
| 26 | `CIS.3.2.1.1` | FAIL | PASS | amelioration | 12 modules inutilises desactives |
| 27 | `CIS.4.1.1.1` | FAIL | PASS | amelioration | auditd actif avec regles /etc/pve |
| 28 | `CIS.4.1.2.1` | INFO | INFO | inchange | rsyslog : pas de collecteur distant configure (hors perimetre lab) |
| 29 | `CIS.5.3.3.1.1` | FAIL | PASS | amelioration | pam_faillock deny=5 sur /etc/pam.d/common-auth |
| 30 | `CIS.5.3.3.1.2` | FAIL | PASS | amelioration | pam_faillock unlock_time=900 sur /etc/pam.d/common-auth |
| 31 | `CIS.5.3.3.1.3` | FAIL | PASS | amelioration | pam_faillock inclut root sur /etc/pam.d/common-auth |
| 32 | `CIS.5.4.1.1` | FAIL | PASS | amelioration | pam_pwquality utilise dans /etc/pam.d/common-password |
| 33 | `CIS.5.4.1.2` | NA | PASS | amelioration | pam_pwquality retry=3 |
| 34 | `CIS.5.4.1.3` | FAIL | PASS | amelioration | minlen=14 (>= 14) |
| 35 | `CIS.5.4.1.4` | FAIL | PASS | amelioration | minclass=4 (>= 4) |
| 36 | `CIS.5.4.2.1` | FAIL | PASS | amelioration | PASS_MAX_DAYS=90 |
| 37 | `CIS.5.4.2.2` | FAIL | PASS | amelioration | PASS_MIN_DAYS=1 |
| 38 | `CIS.5.4.2.3` | PASS | PASS | inchange | PASS_WARN_AGE=7 |
| 39 | `CIS.5.4.3.1` | FAIL | PASS | amelioration | UMASK=027 |
| 40 | `CIS.6.1.2.1` | PASS | PASS | inchange | /etc/passwd en 644 |
| 41 | `CIS.6.1.2.2` | PASS | PASS | inchange | /etc/shadow en 640 |
| 42 | `CIS.6.1.2.3` | PASS | PASS | inchange | /etc/group en 644 |
| 43 | `CIS.6.1.2.4` | PASS | PASS | inchange | /etc/gshadow en 640 |
| 44 | `CIS.6.1.3.1` | PASS | PASS | inchange | /root en 700 |
| 45 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 46 | `OS.APPARMOR.ENFORCE` | FAIL | PASS | amelioration | 119 profils en enforce, 0 en complain |
| 47 | `OS.AUDITD.ACTIVE` | FAIL | PASS | amelioration | auditd actif |
| 48 | `OS.AUDITD.PVE` | FAIL | PASS | amelioration | regles d'audit sur /etc/pve |
| 49 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 50 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 51 | `OS.CRON.CRONTAB` | FAIL | PASS | amelioration | /etc/crontab en 600 |
| 52 | `OS.CRON.DIR.cron.d` | FAIL | PASS | amelioration | /etc/cron.d en 700 |
| 53 | `OS.CRON.DIR.cron.daily` | FAIL | PASS | amelioration | /etc/cron.daily en 700 |
| 54 | `OS.CRON.DIR.cron.hourly` | FAIL | PASS | amelioration | /etc/cron.hourly en 700 |
| 55 | `OS.CRON.DIR.cron.monthly` | FAIL | PASS | amelioration | /etc/cron.monthly en 700 |
| 56 | `OS.CRON.DIR.cron.weekly` | FAIL | PASS | amelioration | /etc/cron.weekly en 700 |
| 57 | `OS.JOURNALD.Compress` | FAIL | PASS | amelioration | Compress=yes |
| 58 | `OS.JOURNALD.Storage` | FAIL | PASS | amelioration | Storage=persistent |
| 59 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs neutralise |
| 60 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs neutralise |
| 61 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs neutralise |
| 62 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus neutralise |
| 63 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 neutralise |
| 64 | `OS.MOUNT._dev_shm` | FAIL | PASS | amelioration | /dev/shm opts=rw,nosuid,nodev,noexec,inode64 |
| 65 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,nr_inodes=1048576,inode64 |
| 66 | `OS.MOUNT._var_tmp` | FAIL | PASS | amelioration | /var/tmp opts=rw,nosuid,nodev,noexec,relatime,size=524288k,inode64 |
| 67 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm neutralise |
| 68 | `OS.NETMOD.can` | PASS | PASS | inchange | module can neutralise |
| 69 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp neutralise |
| 70 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds neutralise |
| 71 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp neutralise |
| 72 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc neutralise |
| 73 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 74 | `OS.PAM.FAILLOCK` | FAIL | PASS | amelioration | pam_faillock configure |
| 75 | `OS.PAM.FAILLOCK.POLICY` | FAIL | PASS | amelioration | deny=5 unlock_time=900 |
| 76 | `OS.PAM.MINLEN` | FAIL | PASS | amelioration | minlen=14 |
| 77 | `OS.PAM.PWQUALITY` | FAIL | PASS | amelioration | libpam-pwquality / cracklib installe |
| 78 | `OS.ROOTKIT.TOOL` | FAIL | PASS | amelioration | outil de detection de rootkit installe |
| 79 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 80 | `OS.SSHD.ALLOWLIST` | FAIL | PASS | amelioration | AllowUsers=root AllowGroups=none |
| 81 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 82 | `OS.SSHD.CLIENTALIVE` | FAIL | PASS | amelioration | ClientAliveInterval=300 CountMax=2 |
| 83 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 84 | `OS.SSHD.GRACETIME` | FAIL | PASS | amelioration | LoginGraceTime=30 |
| 85 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 86 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 87 | `OS.SSHD.MACS` | FAIL | PASS | amelioration | MACs sans algorithme faible |
| 88 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=4 |
| 89 | `OS.SSHD.PASSWORDAUTH` | FAIL | PASS | amelioration | PasswordAuthentication=no |
| 90 | `OS.SSHD.PERM.sshd_config` | FAIL | PASS | amelioration | /etc/ssh/sshd_config en 600 |
| 91 | `OS.SSHD.PERM.sshd_config.d` | FAIL | PASS | amelioration | /etc/ssh/sshd_config.d en 700 |
| 92 | `OS.SSHD.PERMITROOT` | FAIL | INFO | modifie | PermitRootLogin=without-password (acces root par cle uniquement) |
| 93 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 94 | `OS.SSHD.X11` | FAIL | PASS | amelioration | X11Forwarding=no |
| 95 | `OS.UNATTENDED.ENABLED` | FAIL | PASS | amelioration | mises a jour automatiques activees |
| 96 | `OS.UNATTENDED.PKG` | FAIL | PASS | amelioration | unattended-upgrades installe |
| 97 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 98 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 99 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 100 | `PVE.CRYPT.LUKS` | NA | NA | inchange | chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2) |
| 101 | `PVE.F2B.GUI` | FAIL | PASS | amelioration | fail2ban protege l'interface web Proxmox |
| 102 | `PVE.F2B.PKG` | FAIL | PASS | amelioration | fail2ban installe |
| 103 | `PVE.FW.CLUSTER` | FAIL | PASS | amelioration | /etc/pve/firewall/cluster.fw present |
| 104 | `PVE.FW.FORWARD` | NA | PASS | amelioration | politique INPUT/FORWARD = DROP (enable: 1;policy_in: DROP;policy_out: ACCEPT;) |
| 105 | `PVE.GUI.CERT` | INFO | INFO | inchange | certificat GUI absent ou a renouveler |
| 106 | `PVE.LXC.UNPRIV` | NA | NA | inchange | aucun conteneur LXC |
| 107 | `SYS.01` | INFO | INFO | inchange | Debian=13 PVE=(running |
| 108 | `USR.EMPTY.PASS` | PASS | PASS | inchange | aucun compte sans mot de passe |
| 109 | `USR.HASH` | INFO | INFO | inchange | 1 comptes avec hash yescrypt ($y$) |
| 110 | `USR.SHADOW.PERM` | PASS | PASS | inchange | /etc/shadow en 640 |
| 111 | `USR.UID0` | PASS | PASS | inchange | un seul compte UID 0 |

## Tests fonctionnels - avant / apres durcissement

| # | Test fonctionnel | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `FUNC.FW.API` | PASS | PASS | inchange | options du pare-feu lisibles via l'API |
| 2 | `FUNC.FW.STATUS` | PASS | PASS | inchange | pve-firewall status repond |
| 3 | `FUNC.LOG.JOURNALD` | PASS | PASS | inchange | systemd-journald actif |
| 4 | `FUNC.LXC.CREATE` | NA | NA | inchange | aucun template Debian disponible (pveam update local non execute) |
| 5 | `FUNC.NET.GATEWAY` | PASS | PASS | inchange | passerelle NAT 10.0.2.2 joignable |
| 6 | `FUNC.NET.IFACE` | PASS | PASS | inchange | au moins une interface reseau est UP |
| 7 | `FUNC.NET.VMBR0` | PASS | PASS | inchange | pont vmbr0 present |
| 8 | `FUNC.NODE.ONLINE` | PASS | PASS | inchange | noeud localhost en ligne |
| 9 | `FUNC.PVE.API` | PASS | PASS | inchange | API pvesh fonctionnelle |
| 10 | `FUNC.PVEAM.UPDATE` | PASS | PASS | inchange | pveam update operationnel |
| 11 | `FUNC.SSH.KEYAUTH` | PASS | PASS | inchange | 2 cle(s) publique(s) autorisee(s) pour root |
| 12 | `FUNC.STORE.ACTIVE` | PASS | PASS | inchange | au moins un depot de stockage est actif |
| 13 | `FUNC.STORE.LIST` | PASS | PASS | inchange | pvesm status : 2 entrepot(s) disponible(s) |
| 14 | `FUNC.SVC.pvedaemon` | PASS | PASS | inchange | pvedaemon actif |
| 15 | `FUNC.SVC.pve-firewall` | PASS | PASS | inchange | pve-firewall actif |
| 16 | `FUNC.SVC.pveproxy` | PASS | PASS | inchange | pveproxy actif |
| 17 | `FUNC.SVC.pvestatd` | PASS | PASS | inchange | pvestatd actif |
| 18 | `FUNC.SVC.ssh` | PASS | PASS | inchange | ssh actif |
| 19 | `FUNC.TASKS.LIST` | PASS | PASS | inchange | liste des taches accessible |
| 20 | `FUNC.TLS.CERT` | WARN | WARN | inchange | certificat TLS non trouve |
| 21 | `FUNC.WEB.ACCESSIBLE` | PASS | PASS | inchange | Web UI sur 8006 repond (HTTP 200) |

