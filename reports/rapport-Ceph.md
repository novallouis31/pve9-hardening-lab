# Comparatif de hardening - Proxmox VE 9

- **Avant** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\baseline-20261112-130357`
- **Apres** : `C:\Users\Louis\Documents\Projet par défaut\pve9-hardening-lab\artifacts\after-20261112-130444`
- **Genere le** : 2026-11-12 13:04:46

## Synthese

| Indicateur | Avant | Apres | Delta |
|---|---:|---:|---:|
| Controles conformes (PASS) | 34 | 39 | +5 |
| Controles en echec (FAIL) | 60 | 56 | (-5) |
| Regressions | - | 0 | |
| Ameliorations | - | 5 | |
| Tests fonctionnels PASS | 19 | 19 | +0 |
| Regressions fonctionnelles | - | 0 | |

## Ameliorations

| Controle | Avant | Apres | Detail |
|---|---|---|---|
| `CEPH.CONF` | FAIL | PASS | /etc/ceph/ceph.conf present |
| `CEPH.AUTH.CEPHX` | FAIL | PASS | cephx exige pour client/cluster/service |
| `CEPH.MSGR2` | FAIL | PASS | chiffrement msgr2 actif (bind+encrypt+modes secure) |
| `CEPH.CONF.PERM` | FAIL | PASS | /etc/ceph en 750 |
| `CEPH.OSD.ENCRYPT` | NA | PASS | chiffrement des OSD declare |

## Controles en echec restants (apres)

| Controle | Statut | Detail |
|---|---|---|
| `OS.MOUNT._var_tmp` | FAIL | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| `OS.MOUNT._dev_shm` | FAIL | /dev/shm opts=rw,nosuid,nodev,inode64 (manquant: noexec ) |
| `OS.CRON.CRONTAB` | FAIL | /etc/crontab en 644 (attendu 600) |
| `OS.CRON.DIR.cron.daily` | FAIL | /etc/cron.daily en 755 (attendu 700) |
| `OS.CRON.DIR.cron.hourly` | FAIL | /etc/cron.hourly en 755 (attendu 700) |
| `OS.CRON.DIR.cron.weekly` | FAIL | /etc/cron.weekly en 755 (attendu 700) |
| `OS.CRON.DIR.cron.monthly` | FAIL | /etc/cron.monthly en 755 (attendu 700) |
| `OS.CRON.DIR.cron.d` | FAIL | /etc/cron.d en 755 (attendu 700) |
| `OS.JOURNALD.Storage` | FAIL | Storage != persistent |
| `OS.JOURNALD.Compress` | FAIL | Compress != yes |
| `OS.AUDITD.ACTIVE` | FAIL | auditd inactif ou absent |
| `OS.AUDITD.PVE` | FAIL | aucune regle d'audit sur /etc/pve |
| `OS.SSHD.PERM.sshd_config` | FAIL | /etc/ssh/sshd_config en 644 (attendu 600) |
| `OS.SSHD.PERM.sshd_config.d` | FAIL | /etc/ssh/sshd_config.d en 755 (attendu 700) |
| `OS.SSHD.PERMITROOT` | FAIL | PermitRootLogin=yes (attendu no/prohibit-password) |
| `OS.SSHD.PASSWORDAUTH` | FAIL | PasswordAuthentication=yes |
| `OS.SSHD.X11` | FAIL | X11Forwarding=yes |
| `OS.SSHD.GRACETIME` | FAIL | LoginGraceTime=120 |
| `OS.SSHD.ALLOWLIST` | FAIL | aucune restriction AllowUsers/AllowGroups |
| `OS.SSHD.CLIENTALIVE` | FAIL | ClientAliveInterval=0 (non configure) |
| `OS.SSHD.MACS` | FAIL | MACs faibles: umac-64-etm@openssh.com umac-128-etm@openssh.com hmac-sha1-etm@openssh.com umac-64@openssh.com umac-128@openssh.com hmac-sha1  |
| `OS.PAM.FAILLOCK` | FAIL | pam_faillock absent de /etc/pam.d/common-auth |
| `OS.PAM.FAILLOCK.POLICY` | FAIL | deny=? |
| `OS.PAM.PWQUALITY` | FAIL | aucun module de qualite de mot de passe installe |
| `OS.PAM.MINLEN` | FAIL | minlen=non defini (attendu >=12) |
| `OS.APPARMOR.ENFORCE` | FAIL | complain=23 enforce=20 |
| `OS.UNATTENDED.PKG` | FAIL | unattended-upgrades absent |
| `OS.UNATTENDED.ENABLED` | FAIL | mises a jour automatiques non activees |
| `PVE.F2B.PKG` | FAIL | fail2ban absent |
| `PVE.F2B.GUI` | FAIL | fail2ban absent |
| `PVE.FW.CLUSTER` | FAIL | /etc/pve/firewall/cluster.fw absent (pare-feu cluster desactive) |
| `OS.ROOTKIT.TOOL` | FAIL | ni rkhunter ni chkrootkit installes |
| `ANS.BOOT.PERM` | FAIL | /boot mode=755 (attendu 700) |
| `ANS.CTRLALTDEL` | FAIL | ctrl-alt-del.target actif |
| `ANS.KERNEL.BPF` | FAIL | unprivileged_bpf_disabled=2 (attendu 1) |
| `ANS.KERNEL.JIT` | FAIL | bpf_jit_harden=0 (attendu 2) |
| `ANS.AIDE.INSTALLED` | FAIL | aide absent |
| `ANS.AIDE.DB` | FAIL | base AIDE absente (aide --init non lance) |
| `ANS.PASSWORD.AGING` | FAIL | PASS_MAX_DAYS=99999 (attendu <=90) |
| `ANS.RSYSLOG.REMOTE` | FAIL | aucun transfert distant (centralisation des journaux non configuree) |
| `ANS.APPARMOR.ENFORCE` | FAIL | profils en mode complain presents |
| `ANS.USBSTORAGE` | FAIL | usb-storage non desactive |
| `ANS.SSH.ROOTLOGIN` | FAIL | fichier ssh hardening absent |
| `ANS.CRON.ALLOW` | FAIL | /etc/cron.allow absent (cron non restreint) |
| `ANS.LOGIN.UMASK` | FAIL | UMASK=non defini |
| `CIS.5.3.3.1.1` | FAIL | pam_faillock sans argument deny= dans les fichiers PAM |
| `CIS.5.3.3.1.2` | FAIL | pam_faillock sans argument unlock_time= dans les fichiers PAM |
| `CIS.5.3.3.1.3` | FAIL | pam_faillock n'inclut pas root (even_deny_root / root_unlock_time) |
| `CIS.5.4.1.1` | FAIL | pam_pwquality absent de la chaine password |
| `CIS.5.4.1.3` | FAIL | minlen=non defini (attendu >= 14) |
| `CIS.5.4.1.4` | FAIL | minclass=non defini (attendu >= 4) |
| `CIS.5.4.2.1` | FAIL | PASS_MAX_DAYS=99999 (attendu 1..365) |
| `CIS.5.4.2.2` | FAIL | PASS_MIN_DAYS=0 (attendu >= 1) |
| `CIS.5.4.3.1` | FAIL | UMASK=non defini (attendu 027 ou 077) |
| `CIS.4.1.1.1` | FAIL | auditd inactif |
| `CIS.3.2.1.1` | FAIL | seulement 0 modules inutilises desactives (attendu 12) |

## Recapitulatif complet - tous les controles

| # | Controle | Avant | Apres | Evolution | Detail (apres) |
|---|---|---|---|---|---|
| 1 | `ANS.AIDE.DB` | FAIL | FAIL | inchange | base AIDE absente (aide --init non lance) |
| 2 | `ANS.AIDE.INSTALLED` | FAIL | FAIL | inchange | aide absent |
| 3 | `ANS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | profils en mode complain presents |
| 4 | `ANS.BOOT.PERM` | FAIL | FAIL | inchange | /boot mode=755 (attendu 700) |
| 5 | `ANS.CRON.ALLOW` | FAIL | FAIL | inchange | /etc/cron.allow absent (cron non restreint) |
| 6 | `ANS.CTRLALTDEL` | FAIL | FAIL | inchange | ctrl-alt-del.target actif |
| 7 | `ANS.KERNEL.BPF` | FAIL | FAIL | inchange | unprivileged_bpf_disabled=2 (attendu 1) |
| 8 | `ANS.KERNEL.JIT` | FAIL | FAIL | inchange | bpf_jit_harden=0 (attendu 2) |
| 9 | `ANS.LOGIN.UMASK` | FAIL | FAIL | inchange | UMASK=non defini |
| 10 | `ANS.PASSWORD.AGING` | FAIL | FAIL | inchange | PASS_MAX_DAYS=99999 (attendu <=90) |
| 11 | `ANS.RSYSLOG.REMOTE` | FAIL | FAIL | inchange | aucun transfert distant (centralisation des journaux non configuree) |
| 12 | `ANS.SERVICES.AVAHI` | PASS | PASS | inchange | avahi-daemon inactif |
| 13 | `ANS.SSH.ROOTLOGIN` | FAIL | FAIL | inchange | fichier ssh hardening absent |
| 14 | `ANS.USBSTORAGE` | FAIL | FAIL | inchange | usb-storage non desactive |
| 15 | `CEPH.AUTH.CEPHX` | FAIL | PASS | amelioration | cephx exige pour client/cluster/service |
| 16 | `CEPH.CLUSTER` | NA | NA | inchange | aucun cluster Ceph sur ce noeud (mode client seul) |
| 17 | `CEPH.CONF` | FAIL | PASS | amelioration | /etc/ceph/ceph.conf present |
| 18 | `CEPH.CONF.PERM` | FAIL | PASS | amelioration | /etc/ceph en 750 |
| 19 | `CEPH.DASHBOARD` | NA | NA | inchange | ceph-dashboard non installe (pas de cluster) |
| 20 | `CEPH.KEYRING.PERM` | NA | NA | inchange | aucun keyring present |
| 21 | `CEPH.MGR.MODULES` | NA | NA | inchange | ceph-mgr inactif |
| 22 | `CEPH.MSGR2` | FAIL | PASS | amelioration | chiffrement msgr2 actif (bind+encrypt+modes secure) |
| 23 | `CEPH.OSD.ENCRYPT` | NA | PASS | amelioration | chiffrement des OSD declare |
| 24 | `CEPH.PKG` | PASS | PASS | inchange | client ceph installe |
| 25 | `CEPH.POOL.SIZING` | NA | NA | inchange | cluster Ceph injoignable (pas de pool a verifier) |
| 26 | `CIS.3.2.1.1` | FAIL | FAIL | inchange | seulement 0 modules inutilises desactives (attendu 12) |
| 27 | `CIS.4.1.1.1` | FAIL | FAIL | inchange | auditd inactif |
| 28 | `CIS.4.1.2.1` | INFO | INFO | inchange | rsyslog : pas de collecteur distant configure (hors perimetre lab) |
| 29 | `CIS.5.3.3.1.1` | FAIL | FAIL | inchange | pam_faillock sans argument deny= dans les fichiers PAM |
| 30 | `CIS.5.3.3.1.2` | FAIL | FAIL | inchange | pam_faillock sans argument unlock_time= dans les fichiers PAM |
| 31 | `CIS.5.3.3.1.3` | FAIL | FAIL | inchange | pam_faillock n'inclut pas root (even_deny_root / root_unlock_time) |
| 32 | `CIS.5.4.1.1` | FAIL | FAIL | inchange | pam_pwquality absent de la chaine password |
| 33 | `CIS.5.4.1.2` | NA | NA | inchange | pam_pwquality non configure |
| 34 | `CIS.5.4.1.3` | FAIL | FAIL | inchange | minlen=non defini (attendu >= 14) |
| 35 | `CIS.5.4.1.4` | FAIL | FAIL | inchange | minclass=non defini (attendu >= 4) |
| 36 | `CIS.5.4.2.1` | FAIL | FAIL | inchange | PASS_MAX_DAYS=99999 (attendu 1..365) |
| 37 | `CIS.5.4.2.2` | FAIL | FAIL | inchange | PASS_MIN_DAYS=0 (attendu >= 1) |
| 38 | `CIS.5.4.2.3` | PASS | PASS | inchange | PASS_WARN_AGE=7 |
| 39 | `CIS.5.4.3.1` | FAIL | FAIL | inchange | UMASK=non defini (attendu 027 ou 077) |
| 40 | `CIS.6.1.2.1` | PASS | PASS | inchange | /etc/passwd en 644 |
| 41 | `CIS.6.1.2.2` | PASS | PASS | inchange | /etc/shadow en 640 |
| 42 | `CIS.6.1.2.3` | PASS | PASS | inchange | /etc/group en 644 |
| 43 | `CIS.6.1.2.4` | PASS | PASS | inchange | /etc/gshadow en 640 |
| 44 | `CIS.6.1.3.1` | PASS | PASS | inchange | /root en 700 |
| 45 | `OS.APPARMOR.ACTIVE` | PASS | PASS | inchange | apparmor actif |
| 46 | `OS.APPARMOR.ENFORCE` | FAIL | FAIL | inchange | complain=23 enforce=20 |
| 47 | `OS.AUDITD.ACTIVE` | FAIL | FAIL | inchange | auditd inactif ou absent |
| 48 | `OS.AUDITD.PVE` | FAIL | FAIL | inchange | aucune regle d'audit sur /etc/pve |
| 49 | `OS.COREDUMP.LIMITS` | PASS | PASS | inchange | limite core dumps a 0 |
| 50 | `OS.COREDUMP.SYSCALL` | PASS | PASS | inchange | fs.suid_dumpable=0 |
| 51 | `OS.CRON.CRONTAB` | FAIL | FAIL | inchange | /etc/crontab en 644 (attendu 600) |
| 52 | `OS.CRON.DIR.cron.d` | FAIL | FAIL | inchange | /etc/cron.d en 755 (attendu 700) |
| 53 | `OS.CRON.DIR.cron.daily` | FAIL | FAIL | inchange | /etc/cron.daily en 755 (attendu 700) |
| 54 | `OS.CRON.DIR.cron.hourly` | FAIL | FAIL | inchange | /etc/cron.hourly en 755 (attendu 700) |
| 55 | `OS.CRON.DIR.cron.monthly` | FAIL | FAIL | inchange | /etc/cron.monthly en 755 (attendu 700) |
| 56 | `OS.CRON.DIR.cron.weekly` | FAIL | FAIL | inchange | /etc/cron.weekly en 755 (attendu 700) |
| 57 | `OS.JOURNALD.Compress` | FAIL | FAIL | inchange | Compress != yes |
| 58 | `OS.JOURNALD.Storage` | FAIL | FAIL | inchange | Storage != persistent |
| 59 | `OS.MOD.cramfs` | PASS | PASS | inchange | module cramfs non charge |
| 60 | `OS.MOD.freevxfs` | PASS | PASS | inchange | module freevxfs non charge |
| 61 | `OS.MOD.hfs` | PASS | PASS | inchange | module hfs non charge |
| 62 | `OS.MOD.hfsplus` | PASS | PASS | inchange | module hfsplus non charge |
| 63 | `OS.MOD.jffs2` | PASS | PASS | inchange | module jffs2 non charge |
| 64 | `OS.MOUNT._dev_shm` | FAIL | FAIL | inchange | /dev/shm opts=rw,nosuid,nodev,inode64 (manquant: noexec ) |
| 65 | `OS.MOUNT._tmp` | PASS | PASS | inchange | /tmp opts=rw,nosuid,nodev,nr_inodes=1048576,inode64 |
| 66 | `OS.MOUNT._var_tmp` | FAIL | FAIL | inchange | /var/tmp opts=rw,relatime,errors=remount-ro (manquant: nodev nosuid noexec ) |
| 67 | `OS.NETMOD.atm` | PASS | PASS | inchange | module atm non charge |
| 68 | `OS.NETMOD.can` | PASS | PASS | inchange | module can non charge |
| 69 | `OS.NETMOD.dccp` | PASS | PASS | inchange | module dccp non charge |
| 70 | `OS.NETMOD.rds` | PASS | PASS | inchange | module rds non charge |
| 71 | `OS.NETMOD.sctp` | PASS | PASS | inchange | module sctp non charge |
| 72 | `OS.NETMOD.tipc` | PASS | PASS | inchange | module tipc non charge |
| 73 | `OS.NTP` | PASS | PASS | inchange | service de synchronisation temps present |
| 74 | `OS.PAM.FAILLOCK` | FAIL | FAIL | inchange | pam_faillock absent de /etc/pam.d/common-auth |
| 75 | `OS.PAM.FAILLOCK.POLICY` | FAIL | FAIL | inchange | deny=? |
| 76 | `OS.PAM.MINLEN` | FAIL | FAIL | inchange | minlen=non defini (attendu >=12) |
| 77 | `OS.PAM.PWQUALITY` | FAIL | FAIL | inchange | aucun module de qualite de mot de passe installe |
| 78 | `OS.ROOTKIT.TOOL` | FAIL | FAIL | inchange | ni rkhunter ni chkrootkit installes |
| 79 | `OS.RSYSLOG` | INFO | INFO | inchange | rsyslog inactif (logs locaux uniquement) |
| 80 | `OS.SSHD.ALLOWLIST` | FAIL | FAIL | inchange | aucune restriction AllowUsers/AllowGroups |
| 81 | `OS.SSHD.CIPHERS` | PASS | PASS | inchange | ciphers sans algorithme faible |
| 82 | `OS.SSHD.CLIENTALIVE` | FAIL | FAIL | inchange | ClientAliveInterval=0 (non configure) |
| 83 | `OS.SSHD.EMPTYPASS` | PASS | PASS | inchange | PermitEmptyPasswords=no |
| 84 | `OS.SSHD.GRACETIME` | FAIL | FAIL | inchange | LoginGraceTime=120 |
| 85 | `OS.SSHD.HOSTKEYS` | PASS | PASS | inchange | cles hote en 600 |
| 86 | `OS.SSHD.KEX` | PASS | PASS | inchange | KexAlgorithms sans algorithme faible |
| 87 | `OS.SSHD.MACS` | FAIL | FAIL | inchange | MACs faibles: umac-64-etm@openssh.com umac-128-etm@openssh.com hmac-sha1-etm@openssh.com umac-64@openssh.com umac-128@openssh.com hmac-sha1  |
| 88 | `OS.SSHD.MAXAUTH` | PASS | PASS | inchange | MaxAuthTries=6 |
| 89 | `OS.SSHD.PASSWORDAUTH` | FAIL | FAIL | inchange | PasswordAuthentication=yes |
| 90 | `OS.SSHD.PERM.sshd_config` | FAIL | FAIL | inchange | /etc/ssh/sshd_config en 644 (attendu 600) |
| 91 | `OS.SSHD.PERM.sshd_config.d` | FAIL | FAIL | inchange | /etc/ssh/sshd_config.d en 755 (attendu 700) |
| 92 | `OS.SSHD.PERMITROOT` | FAIL | FAIL | inchange | PermitRootLogin=yes (attendu no/prohibit-password) |
| 93 | `OS.SSHD.PUBKEY` | PASS | PASS | inchange | PubkeyAuthentication=yes |
| 94 | `OS.SSHD.X11` | FAIL | FAIL | inchange | X11Forwarding=yes |
| 95 | `OS.UNATTENDED.ENABLED` | FAIL | FAIL | inchange | mises a jour automatiques non activees |
| 96 | `OS.UNATTENDED.PKG` | FAIL | FAIL | inchange | unattended-upgrades absent |
| 97 | `PVE.API.TOKENS` | INFO | INFO | inchange | 0 token(s) API dans /etc/pve/priv/token.cfg |
| 98 | `PVE.BOOT.LOCKDOWN` | INFO | INFO | inchange | kernel lockdown=[none] integrity confidentiality |
| 99 | `PVE.BOOT.SECUREBOOT` | NA | NA | inchange | demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox |
| 100 | `PVE.CRYPT.LUKS` | NA | NA | inchange | chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2) |
| 101 | `PVE.F2B.GUI` | FAIL | FAIL | inchange | fail2ban absent |
| 102 | `PVE.F2B.PKG` | FAIL | FAIL | inchange | fail2ban absent |
| 103 | `PVE.FW.CLUSTER` | FAIL | FAIL | inchange | /etc/pve/firewall/cluster.fw absent (pare-feu cluster desactive) |
| 104 | `PVE.FW.FORWARD` | NA | NA | inchange | pas de configuration firewall par noeud |
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

