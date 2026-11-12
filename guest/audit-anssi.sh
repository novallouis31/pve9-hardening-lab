#!/usr/bin/env bash
# audit-anssi.sh - controles ANSSI (source par audit-pve.sh si AUDIT_EXTRA contient anssi)
# Variables attendues : OUT_DIR, PASS_COUNT, FAIL_COUNT, NA_COUNT, INFO_COUNT, CHECK_LINES, et les fonctions sec/run/chk.

sec "ANSSI - Guide de durcissement (niveaux minimal/intermediaire/renforce/elevel)"

# ANS.BOOT.PERM : /boot reserve a root
if [ -d /boot ]; then
    p=$(stat -c '%a' /boot 2>/dev/null)
    if [ "$p" = "700" ] || [ "$p" = "750" ] || [ "$p" = "755" ]; then
        # ANSSI recommande 700 ; 755 tolere si boot public (grub)
        if [ "$p" = "700" ]; then chk ANS.BOOT.PERM PASS "/boot mode=$p"; else chk ANS.BOOT.PERM FAIL "/boot mode=$p (attendu 700)"; fi
    else
        chk ANS.BOOT.PERM FAIL "/boot mode=$p"
    fi
else
    chk ANS.BOOT.PERM NA "/boot absent"
fi

# ANS.CTRLALTDEL : desactivation de Ctrl-Alt-Del
if systemctl is-enabled ctrl-alt-del.target >/dev/null 2>&1; then
    chk ANS.CTRLALTDEL FAIL "ctrl-alt-del.target actif"
else
    chk ANS.CTRLALTDEL PASS "ctrl-alt-del.target desactive"
fi

# ANS.KERNEL.BPF
v=$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null)
if [ "$v" = "1" ]; then chk ANS.KERNEL.BPF PASS "unprivileged_bpf_disabled=$v"; else chk ANS.KERNEL.BPF FAIL "unprivileged_bpf_disabled=$v (attendu 1)"; fi

# ANS.KERNEL.JIT
v=$(sysctl -n net.core.bpf_jit_harden 2>/dev/null)
if [ "$v" = "2" ]; then chk ANS.KERNEL.JIT PASS "bpf_jit_harden=$v"; else chk ANS.KERNEL.JIT FAIL "bpf_jit_harden=$v (attendu 2)"; fi

# ANS.AIDE.INSTALLED
if command -v aide >/dev/null 2>&1; then chk ANS.AIDE.INSTALLED PASS "aide installe"; else chk ANS.AIDE.INSTALLED FAIL "aide absent"; fi

# ANS.AIDE.DB
if [ -f /var/lib/aide/aide.db ] || [ -f /var/lib/aide/aide.db.gz ]; then
    chk ANS.AIDE.DB PASS "base AIDE presente"
else
    chk ANS.AIDE.DB FAIL "base AIDE absente (aide --init non lance)"
fi

# ANS.PASSWORD.AGING
maxdays=$(grep -E '^\s*PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}')
if [ -n "$maxdays" ] && [ "$maxdays" -le 90 ] 2>/dev/null; then
    chk ANS.PASSWORD.AGING PASS "PASS_MAX_DAYS=$maxdays"
else
    chk ANS.PASSWORD.AGING FAIL "PASS_MAX_DAYS=${maxdays:-non defini} (attendu <=90)"
fi

# ANS.RSYSLOG.REMOTE : au moins une regle de transfert distant (active ou template)
if grep -rEq '^\s*\*\.?\*?\s+.*action\(type="omfwd"' /etc/rsyslog.conf /etc/rsyslog.d 2>/dev/null; then
    chk ANS.RSYSLOG.REMOTE PASS "transfert distant configure (omfwd)"
elif grep -rEq 'action\(type="omfwd"' /etc/rsyslog.d 2>/dev/null; then
    chk ANS.RSYSLOG.REMOTE PASS "transfert distant prepare (omfwd, variable LOG_SERVER a definir)"
else
    chk ANS.RSYSLOG.REMOTE FAIL "aucun transfert distant (centralisation des journaux non configuree)"
fi

# ANS.APPARMOR.ENFORCE
if command -v aa-status >/dev/null 2>&1; then
    complain=$(aa-status 2>/dev/null | grep -i 'complain' | head -1)
    enforce=$(aa-status 2>/dev/null | grep -i 'enforce' | head -1)
    if echo "$complain" | grep -q '0 profiles'; then
        chk ANS.APPARMOR.ENFORCE PASS "aucun profil en mode complain"
    else
        chk ANS.APPARMOR.ENFORCE FAIL "profils en mode complain presents"
    fi
else
    chk ANS.APPARMOR.ENFORCE NA "apparmor non installe"
fi

# ANS.USBSTORAGE : blacklist usb-storage
if grep -rq 'blacklist usb-storage\|install usb-storage /bin/false' /etc/modprobe.d 2>/dev/null; then
    chk ANS.USBSTORAGE PASS "usb-storage desactive"
else
    chk ANS.USBSTORAGE FAIL "usb-storage non desactive"
fi

# ANS.SSH.ROOTLOGIN : PermitRootLogin no (ANSSI renforce)
if [ -f /etc/ssh/sshd_config.d/00-pve-hardening.conf ]; then
    v=$(grep -E '^\s*PermitRootLogin' /etc/ssh/sshd_config.d/00-pve-hardening.conf | awk '{print $2}')
    if [ "$v" = "no" ]; then chk ANS.SSH.ROOTLOGIN PASS "PermitRootLogin=$v"; else chk ANS.SSH.ROOTLOGIN FAIL "PermitRootLogin=$v (ANSSI renforce attend no)"; fi
else
    chk ANS.SSH.ROOTLOGIN FAIL "fichier ssh hardening absent"
fi

# ANS.SERVICES.AVAHI
if systemctl is-active avahi-daemon >/dev/null 2>&1; then
    chk ANS.SERVICES.AVAHI FAIL "avahi-daemon actif"
else
    chk ANS.SERVICES.AVAHI PASS "avahi-daemon inactif"
fi

# ANS.CRON.ALLOW
if [ -f /etc/cron.allow ]; then
    chk ANS.CRON.ALLOW PASS "/etc/cron.allow present"
else
    chk ANS.CRON.ALLOW FAIL "/etc/cron.allow absent (cron non restreint)"
fi

# ANS.LOGIN.DEFS : umask 027
v=$(grep -E '^\s*ERASECHAR|^\s*UMASK' /etc/login.defs 2>/dev/null | grep UMASK | awk '{print $2}')
if [ "$v" = "027" ] || [ "$v" = "077" ]; then chk ANS.LOGIN.UMASK PASS "UMASK=$v"; else chk ANS.LOGIN.UMASK FAIL "UMASK=${v:-non defini}"; fi