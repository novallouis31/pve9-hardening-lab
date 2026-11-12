#!/usr/bin/env bash
# audit-anssi.sh - controles ANSSI / BP-028
# Source par audit-pve.sh si AUDIT_EXTRA contient anssi.
# Variables attendues : OUT_DIR, PASS_COUNT, FAIL_COUNT, NA_COUNT, INFO_COUNT,
# CHECK_LINES, et les fonctions sec/run/chk.
#
# References :
#   - Guide PVE 9 (HomeSecExplorer) : sections 4.x, option B pour le root SSH
#   - Makaveli81/ansible-linux-hardening : audit_items ANSSI BP-028 (M/I/R/E)
#   - hardenedlinux/harbian-audit : checks numerotes (1.5.x, 9.3.x, 12.x...)

sec "ANSSI - BP-028 (niveaux minimal / intermediaire / renforce / eleve)"

# ---------------------------------------------------------------------------
# Niveau M - socle
# ---------------------------------------------------------------------------

# ANS.BOOT.PERM : /boot reserve a root
if [ -d /boot ]; then
    p=$(stat -c '%a' /boot 2>/dev/null)
    if [ "$p" = "700" ]; then
        chk ANS.BOOT.PERM PASS "/boot mode=$p"
    else
        chk ANS.BOOT.PERM FAIL "/boot mode=${p:-?} (attendu 700)"
    fi
else
    chk ANS.BOOT.PERM NA "/boot absent"
fi

# ANS.CTRLALTDEL : desactivation de Ctrl-Alt-Del (harbian 5.4)
if systemctl is-enabled ctrl-alt-del.target >/dev/null 2>&1; then
    chk ANS.CTRLALTDEL FAIL "ctrl-alt-del.target actif"
else
    chk ANS.CTRLALTDEL PASS "ctrl-alt-del.target desactive"
fi

# ANS.KERNEL.BPF (harbian 1.5.x / BP-028 [SYS])
v=$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null)
if [ "$v" = "1" ]; then chk ANS.KERNEL.BPF PASS "unprivileged_bpf_disabled=$v"; else chk ANS.KERNEL.BPF FAIL "unprivileged_bpf_disabled=${v:-?} (attendu 1)"; fi

# ANS.KERNEL.JIT (BP-028 [SYS])
v=$(sysctl -n net.core.bpf_jit_harden 2>/dev/null)
if [ "$v" = "2" ]; then chk ANS.KERNEL.JIT PASS "bpf_jit_harden=$v"; else chk ANS.KERNEL.JIT FAIL "bpf_jit_harden=${v:-?} (attendu 2)"; fi

# ANS.KERNEL.DMESG (harbian 1.5.5 / BP-028 [SYS] dmesg_restrict=1)
v=$(sysctl -n kernel.dmesg_restrict 2>/dev/null)
if [ "$v" = "1" ]; then chk ANS.KERNEL.DMESG PASS "dmesg_restrict=$v"; else chk ANS.KERNEL.DMESG FAIL "dmesg_restrict=${v:-?} (attendu 1)"; fi

# ANS.KERNEL.KPTR (harbian 1.5.8 / BP-028 [SYS] kptr_restrict=2)
v=$(sysctl -n kernel.kptr_restrict 2>/dev/null)
if [ "$v" = "2" ]; then chk ANS.KERNEL.KPTR PASS "kptr_restrict=$v"; else chk ANS.KERNEL.KPTR FAIL "kptr_restrict=${v:-?} (attendu 2)"; fi

# ANS.KERNEL.ASLR (harbian 1.5.9 / BP-028 [SYS] randomize_va_space=2)
v=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
if [ "$v" = "2" ]; then chk ANS.KERNEL.ASLR PASS "randomize_va_space=$v"; else chk ANS.KERNEL.ASLR FAIL "randomize_va_space=${v:-?} (attendu 2)"; fi

# ANS.KERNEL.PTRACE (harbian 1.5.3 / BP-028 [SYS] ptrace_scope>=1)
v=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)
if [ -n "$v" ] && [ "$v" -ge 1 ] 2>/dev/null; then chk ANS.KERNEL.PTRACE PASS "ptrace_scope=$v"; else chk ANS.KERNEL.PTRACE FAIL "ptrace_scope=${v:-?} (attendu >= 1)"; fi

# ANS.KERNEL.SYMLINK (harbian 1.5.2 / BP-028 [FIC] protected_symlinks=1)
v=$(sysctl -n fs.protected_symlinks 2>/dev/null)
if [ "$v" = "1" ]; then chk ANS.KERNEL.SYMLINK PASS "protected_symlinks=$v"; else chk ANS.KERNEL.SYMLINK FAIL "protected_symlinks=${v:-?} (attendu 1)"; fi

# ANS.SESSION.TMOUT (BP-028 [USR] TMOUT=900 / harbian 10.5)
v=$(grep -rhoE '^[[:space:]]*TMOUT=[0-9]+' /etc/profile.d/ /etc/profile 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -n "$v" ] && [ "$v" -le 900 ] 2>/dev/null; then
    chk ANS.SESSION.TMOUT PASS "TMOUT=$v"
else
    chk ANS.SESSION.TMOUT FAIL "TMOUT=${v:-non defini} (attendu <= 900)"
fi

# ANS.USR.NOLOGIN : les comptes systeme ont un shell non interactif
bad_shell=""
for u in daemon bin sys games man lp mail news uucp proxy www-data backup list irc nobody; do
    getent passwd "$u" >/dev/null 2>&1 || continue
    sh=$(getent passwd "$u" | cut -d: -f7)
    case "$sh" in
        */nologin|*/false) : ;;
        *) bad_shell="$bad_shell $u($sh)" ;;
    esac
done
if [ -z "$bad_shell" ]; then
    chk ANS.USR.NOLOGIN PASS "comptes systeme sans shell interactif"
else
    chk ANS.USR.NOLOGIN FAIL "shell interactif pour :$bad_shell"
fi

# ANS.FIC.PASSWD.PERM (harbian 12.1-12.6 / BP-028 [FIC])
p=$(stat -c '%a %U %G' /etc/passwd 2>/dev/null)
if [ "$p" = "644 root root" ]; then chk ANS.FIC.PASSWD.PERM PASS "/etc/passwd $p"; else chk ANS.FIC.PASSWD.PERM FAIL "/etc/passwd ${p:-?} (attendu 644 root root)"; fi
p=$(stat -c '%a %U %G' /etc/shadow 2>/dev/null)
if [ "$p" = "640 root shadow" ]; then chk ANS.FIC.SHADOW.PERM PASS "/etc/shadow $p"; else chk ANS.FIC.SHADOW.PERM FAIL "/etc/shadow ${p:-?} (attendu 640 root shadow)"; fi
p=$(stat -c '%a' /etc/group 2>/dev/null)
if [ "$p" = "644" ]; then chk ANS.FIC.GROUP.PERM PASS "/etc/group $p"; else chk ANS.FIC.GROUP.PERM FAIL "/etc/group ${p:-?} (attendu 644)"; fi
p=$(stat -c '%a' /etc/gshadow 2>/dev/null)
if [ "$p" = "640" ]; then chk ANS.FIC.GSHADOW.PERM PASS "/etc/gshadow $p"; else chk ANS.FIC.GSHADOW.PERM FAIL "/etc/gshadow ${p:-?} (attendu 640)"; fi

# ---------------------------------------------------------------------------
# Niveau I - intermediaire
# ---------------------------------------------------------------------------

# ANS.AIDE.INSTALLED (harbian 8.4.1)
if command -v aide >/dev/null 2>&1; then chk ANS.AIDE.INSTALLED PASS "aide installe"; else chk ANS.AIDE.INSTALLED FAIL "aide absent"; fi

# ANS.AIDE.DB
if [ -f /var/lib/aide/aide.db ] || [ -f /var/lib/aide/aide.db.gz ]; then
    chk ANS.AIDE.DB PASS "base AIDE presente"
else
    chk ANS.AIDE.DB FAIL "base AIDE absente (aide --init non lance)"
fi

# ANS.PASSWORD.AGING (harbian 10.1.1-10.1.3)
maxdays=$(grep -E '^\s*PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}')
if [ -n "$maxdays" ] && [ "$maxdays" -le 90 ] 2>/dev/null; then
    chk ANS.PASSWORD.AGING PASS "PASS_MAX_DAYS=$maxdays"
else
    chk ANS.PASSWORD.AGING FAIL "PASS_MAX_DAYS=${maxdays:-non defini} (attendu <=90)"
fi

# ANS.RSYSLOG.REMOTE (harbian 8.2.4 / BP-028) : regle omfwd presente
if grep -rEq '^\s*\*\.?\*?\s+.*action\(type="omfwd"' /etc/rsyslog.conf /etc/rsyslog.d 2>/dev/null; then
    chk ANS.RSYSLOG.REMOTE PASS "transfert distant configure (omfwd)"
elif grep -rEq 'action\(type="omfwd"' /etc/rsyslog.d 2>/dev/null; then
    chk ANS.RSYSLOG.REMOTE PASS "transfert distant prepare (omfwd, variable LOG_SERVER a definir)"
else
    chk ANS.RSYSLOG.REMOTE FAIL "aucun transfert distant (centralisation des journaux non configuree)"
fi

# ANS.RSYSLOG.ACTIVE : le service rsyslog tourne (harbian 8.2.2)
if systemctl is-active --quiet rsyslog 2>/dev/null; then
    chk ANS.RSYSLOG.ACTIVE PASS "rsyslog actif"
elif command -v rsyslogd >/dev/null 2>&1; then
    chk ANS.RSYSLOG.ACTIVE FAIL "rsyslog installe mais inactif"
else
    chk ANS.RSYSLOG.ACTIVE FAIL "rsyslog absent"
fi

# ANS.APPARMOR.ENFORCE (harbian 4.5)
if command -v aa-status >/dev/null 2>&1; then
    complain=$(aa-status 2>/dev/null | grep -i 'complain' | head -1)
    if echo "$complain" | grep -q '0 profiles'; then
        chk ANS.APPARMOR.ENFORCE PASS "aucun profil en mode complain"
    else
        chk ANS.APPARMOR.ENFORCE FAIL "profils en mode complain presents"
    fi
else
    chk ANS.APPARMOR.ENFORCE NA "apparmor non installe"
fi

# ANS.BANNER (harbian 11.1) : banniere de connexion informative
if [ -f /etc/issue.net ] && [ -s /etc/issue.net ]; then
    chk ANS.BANNER PASS "/etc/issue.net present ($(wc -l < /etc/issue.net) ligne(s))"
else
    chk ANS.BANNER FAIL "/etc/issue.net absent ou vide"
fi

# ANS.CRON.PERM (harbian 9.1.2-9.1.7)
p=$(stat -c '%a' /etc/crontab 2>/dev/null)
if [ "$p" = "600" ] || [ "$p" = "644" ]; then chk ANS.CRON.PERM PASS "/etc/crontab en $p"; else chk ANS.CRON.PERM FAIL "/etc/crontab en ${p:-?} (attendu 600/644)"; fi
p=$(stat -c '%a' /etc/cron.d 2>/dev/null)
if [ "$p" = "700" ] || [ "$p" = "755" ]; then chk ANS.CRON.DIR.PERM PASS "/etc/cron.d en $p"; else chk ANS.CRON.DIR.PERM FAIL "/etc/cron.d en ${p:-?} (attendu 700/755)"; fi

# ---------------------------------------------------------------------------
# Niveau R - renforce
# ---------------------------------------------------------------------------

# ANS.USBSTORAGE (harbian 4.8 disable_usb_devices)
if grep -rq 'blacklist usb-storage\|install usb-storage /bin/false' /etc/modprobe.d 2>/dev/null; then
    chk ANS.USBSTORAGE PASS "usb-storage desactive"
else
    chk ANS.USBSTORAGE FAIL "usb-storage non desactive"
fi

# ANS.CRON.ALLOW (harbian 9.1.8 cron_users)
if [ -f /etc/cron.allow ]; then
    chk ANS.CRON.ALLOW PASS "/etc/cron.allow present"
else
    chk ANS.CRON.ALLOW FAIL "/etc/cron.allow absent (cron non restreint)"
fi

# ANS.LOGIN.UMASK (harbian 10.4 / BP-028 [FIC] Umask Global = 027)
v=$(grep -E '^[[:space:]]*UMASK[[:space:]]' /etc/login.defs 2>/dev/null | grep -v '^#' | awk '{print $2}')
if [ "$v" = "027" ] || [ "$v" = "077" ]; then chk ANS.LOGIN.UMASK PASS "UMASK=$v"; else chk ANS.LOGIN.UMASK FAIL "UMASK=${v:-non defini} (attendu 027 ou 077)"; fi

# ANS.SSH.ROOTLOGIN : le root SSH doit etre restreint.
# Modele applique = guide PVE 9 option B : 'PermitRootLogin no' global
# + bloc 'Match Address <CIDR de management>' autorisant le root par cle.
# L'auditeur verifie donc les DEUX conditions (et non un simple grep).
sshd_drop=/etc/ssh/sshd_config.d/00-pve-hardening.conf
if [ ! -f "$sshd_drop" ]; then
    chk ANS.SSH.ROOTLOGIN FAIL "fichier ssh hardening absent ($sshd_drop)"
else
    root_global=$(awk '/^[[:space:]]*PermitRootLogin/ && !/^[[:space:]]*#/ {print $2; exit}' "$sshd_drop")
    # Adresse du client autorisee (bloc Match)
    match_cidr=$(awk '/^[[:space:]]*Match[[:space:]]+Address/ {print $3; exit}' "$sshd_drop")
    if [ "$root_global" = "no" ] && [ -n "$match_cidr" ]; then
        chk ANS.SSH.ROOTLOGIN PASS "PermitRootLogin=no global, exception restreinte a $match_cidr (guide PVE 9 option B)"
    elif [ "$root_global" = "no" ]; then
        chk ANS.SSH.ROOTLOGIN FAIL "PermitRootLogin=no sans exception : acces SSH du lab coupe"
    elif [ "$root_global" = "prohibit-password" ]; then
        chk ANS.SSH.ROOTLOGIN FAIL "PermitRootLogin=prohibit-password (ANSSI renforce attend no + restriction reseau)"
    else
        chk ANS.SSH.ROOTLOGIN FAIL "PermitRootLogin=${root_global:-?}"
    fi
fi

# ANS.SSH.PASSWORDAUTH : l'authentification par mot de passe doit etre off
v=$(awk '/^[[:space:]]*PasswordAuthentication/ && !/^[[:space:]]*#/ {print $2; exit}' "$sshd_drop" 2>/dev/null)
if [ "$v" = "no" ]; then
    chk ANS.SSH.PASSWORDAUTH PASS "PasswordAuthentication=no"
elif [ -z "$v" ]; then
    chk ANS.SSH.PASSWORDAUTH FAIL "PasswordAuthentication non defini (attendu no)"
else
    chk ANS.SSH.PASSWORDAUTH FAIL "PasswordAuthentication=$v (attendu no)"
fi

# ---------------------------------------------------------------------------
# Niveau E - eleve
# ---------------------------------------------------------------------------

# ANS.SERVICES.AVAHI (harbian 6.2)
if systemctl is-active avahi-daemon >/dev/null 2>&1; then
    chk ANS.SERVICES.AVAHI FAIL "avahi-daemon actif"
else
    chk ANS.SERVICES.AVAHI PASS "avahi-daemon inactif"
fi

# ANS.SERVICES.NETWORK : les services reseau legacy doivent etre absents
bad_svc=""
for svc in rsh-server talk-server telnet inetd xinetd nfs-kernel-server samba smbd snmpd vsftpd proftpd; do
    if systemctl is-active "$svc" >/dev/null 2>&1; then bad_svc="$bad_svc $svc"; fi
done
if [ -z "$bad_svc" ]; then
    chk ANS.SERVICES.NETWORK PASS "aucun service reseau legacy actif"
else
    chk ANS.SERVICES.NETWORK FAIL "services actifs :$bad_svc"
fi

# ANS.USR.UID0 : aucun compte autre que root ne doit avoir l'UID 0
uids=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')
if [ -z "$uids" ]; then
    chk ANS.USR.UID0 PASS "root est le seul compte UID 0"
else
    chk ANS.USR.UID0 FAIL "comptes UID 0 supplementaires :$uids"
fi
