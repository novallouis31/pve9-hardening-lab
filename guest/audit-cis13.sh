#!/usr/bin/env bash
# =============================================================================
# audit-cis13.sh - Controles CIS Debian 13 officiels (niveau 1) complementaires
# -----------------------------------------------------------------------------
# Reference : ansible-lockdown/DEBIAN13-CIS (taks/section_*), IDs CIS officiels.
# Ces controles complent audit-pve.sh sur les points ou le CIS Debian 13 est
# plus exigeant que le guide PVE 9 (PAM faillock en ligne PAM, umask login.defs,
# permissions de /etc/passwd et shadow, etc.).
#
# Contrat de sortie : @@CHECK <ID> <PASS|FAIL|NA|INFO> <detail>
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

sec "CIS Debian 13 - controles officiels complementaires"

# -----------------------------------------------------------------------------
# 5.3.3.1.x - Verrouillage de compte apres echecs d'authentification
# Le CIS exige que pam_faillock soit configure DANS la ligne PAM (arguments
# deny=/unlock_time=) et non via un fichier de configuration separe.
# -----------------------------------------------------------------------------
PAM_FILES="/etc/pam.d/common-auth /etc/pam.d/sshd /etc/pam.d/login"

# 5.3.3.1.1 : deny configure sur la ligne PAM
fl_deny=""
for f in $PAM_FILES; do
    [ -f "$f" ] || continue
    v=$(grep -Pl -- '\bpam_faillock\.so\h+([^#\n\r]+\h+)?deny\b' "$f" 2>/dev/null | head -1)
    [ -n "$v" ] && fl_deny="$f" && break
done
if [ -n "$fl_deny" ]; then
    d=$(grep -oE 'deny=[0-9]+' "$fl_deny" | head -1 | cut -d= -f2)
    chk "CIS.5.3.3.1.1" PASS "pam_faillock deny=${d:-?} sur $fl_deny"
else
    chk "CIS.5.3.3.1.1" FAIL "pam_faillock sans argument deny= dans les fichiers PAM"
fi

# 5.3.3.1.2 : unlock_time configure sur la ligne PAM
fl_unlock=""
for f in $PAM_FILES; do
    [ -f "$f" ] || continue
    v=$(grep -Pl -- '\bpam_faillock\.so\h+([^#\n\r]+\h+)?unlock_time\b' "$f" 2>/dev/null | head -1)
    [ -n "$v" ] && fl_unlock="$f" && break
done
if [ -n "$fl_unlock" ]; then
    u=$(grep -oE 'unlock_time=[0-9]+' "$fl_unlock" | head -1 | cut -d= -f2)
    chk "CIS.5.3.3.1.2" PASS "pam_faillock unlock_time=${u:-?} sur $fl_unlock"
else
    chk "CIS.5.3.3.1.2" FAIL "pam_faillock sans argument unlock_time= dans les fichiers PAM"
fi

# 5.3.3.1.3 : le verrouillage inclut root (even_deny_root ou root_unlock_time)
fl_root=""
for f in $PAM_FILES; do
    [ -f "$f" ] || continue
    v=$(grep -Pl -- '\bpam_faillock\.so\h+([^#\n\r]+\h+)?(even_deny_root\b|root_unlock_time\s*=\s*[0-9]+\b)' "$f" 2>/dev/null | head -1)
    [ -n "$v" ] && fl_root="$f" && break
done
if [ -n "$fl_root" ]; then
    chk "CIS.5.3.3.1.3" PASS "pam_faillock inclut root sur $fl_root"
else
    chk "CIS.5.3.3.1.3" FAIL "pam_faillock n'inclut pas root (even_deny_root / root_unlock_time)"
fi

# -----------------------------------------------------------------------------
# 5.4.1.x - Qualite des mots de passe (pam_pwquality + pwquality.conf)
# -----------------------------------------------------------------------------
# 5.4.1.1 : pam_pwquality utilise dans la chaine password
pw_pam=""
for f in /etc/pam.d/common-password /etc/pam.d/passwd; do
    [ -f "$f" ] || continue
    grep -q 'pam_pwquality\.so' "$f" 2>/dev/null && pw_pam="$f" && break
done
if [ -n "$pw_pam" ]; then
    chk "CIS.5.4.1.1" PASS "pam_pwquality utilise dans $pw_pam"
else
    chk "CIS.5.4.1.1" FAIL "pam_pwquality absent de la chaine password"
fi

# 5.4.1.2 : retries configure sur pam_pwquality
if [ -n "$pw_pam" ]; then
    if grep -qE 'pam_pwquality\.so.*retry=' "$pw_pam"; then
        r=$(grep -oE 'retry=[0-9]+' "$pw_pam" | head -1)
        chk "CIS.5.4.1.2" PASS "pam_pwquality $r"
    else
        chk "CIS.5.4.1.2" FAIL "pam_pwquality sans parametre retry="
    fi
else
    chk "CIS.5.4.1.2" NA "pam_pwquality non configure"
fi

# 5.4.1.3 : minlen >= 14 dans pwquality.conf
minlen=$(awk -F= '/^[[:space:]]*minlen[[:space:]]*=/ {gsub(/[[:space:]]/,"",$2); print $2}' /etc/security/pwquality.conf 2>/dev/null)
if [ -n "$minlen" ] && [ "$minlen" -ge 14 ] 2>/dev/null; then
    chk "CIS.5.4.1.3" PASS "minlen=$minlen (>= 14)"
else
    chk "CIS.5.4.1.3" FAIL "minlen=${minlen:-non defini} (attendu >= 14)"
fi

# 5.4.1.4 : les 4 classes de caracteres sont exigees
classes=$(awk -F= '/^[[:space:]]*minclass[[:space:]]*=/ {gsub(/[[:space:]]/,"",$2); print $2}' /etc/security/pwquality.conf 2>/dev/null)
if [ -n "$classes" ] && [ "$classes" -ge 4 ] 2>/dev/null; then
    chk "CIS.5.4.1.4" PASS "minclass=$classes (>= 4)"
else
    chk "CIS.5.4.1.4" FAIL "minclass=${classes:-non defini} (attendu >= 4)"
fi

# -----------------------------------------------------------------------------
# 5.4.2.x - Vieillissement des mots de passe (login.defs)
# -----------------------------------------------------------------------------
maxd=$(awk '/^[[:space:]]*PASS_MAX_DAYS[[:space:]]/ {print $2}' /etc/login.defs 2>/dev/null)
mind=$(awk '/^[[:space:]]*PASS_MIN_DAYS[[:space:]]/ {print $2}' /etc/login.defs 2>/dev/null)
warnd=$(awk '/^[[:space:]]*PASS_WARN_AGE[[:space:]]/ {print $2}' /etc/login.defs 2>/dev/null)
if [ -n "$maxd" ] && [ "$maxd" -le 365 ] 2>/dev/null && [ "$maxd" -gt 0 ]; then
    chk "CIS.5.4.2.1" PASS "PASS_MAX_DAYS=$maxd"
else
    chk "CIS.5.4.2.1" FAIL "PASS_MAX_DAYS=${maxd:-non defini} (attendu 1..365)"
fi
if [ -n "$mind" ] && [ "$mind" -ge 1 ] 2>/dev/null; then
    chk "CIS.5.4.2.2" PASS "PASS_MIN_DAYS=$mind"
else
    chk "CIS.5.4.2.2" FAIL "PASS_MIN_DAYS=${mind:-non defini} (attendu >= 1)"
fi
if [ -n "$warnd" ] && [ "$warnd" -ge 1 ] 2>/dev/null; then
    chk "CIS.5.4.2.3" PASS "PASS_WARN_AGE=$warnd"
else
    chk "CIS.5.4.2.3" FAIL "PASS_WARN_AGE=${warnd:-non defini} (attendu >= 1)"
fi

# -----------------------------------------------------------------------------
# 5.4.3.x - UMASK
# -----------------------------------------------------------------------------
umask_v=$(awk '/^[[:space:]]*UMASK[[:space:]]/ {print $2}' /etc/login.defs 2>/dev/null)
if [ -n "$umask_v" ] && [ "$umask_v" = "027" ] || [ "$umask_v" = "077" ]; then
    chk "CIS.5.4.3.1" PASS "UMASK=$umask_v"
else
    chk "CIS.5.4.3.1" FAIL "UMASK=${umask_v:-non defini} (attendu 027 ou 077)"
fi

# -----------------------------------------------------------------------------
# 6.1.2.x - Permissions et proprietaires des fichiers de comptes
# -----------------------------------------------------------------------------
p=$(stat -c '%a' /etc/passwd 2>/dev/null)
[ "$p" = "644" ] && chk "CIS.6.1.2.1" PASS "/etc/passwd en 644" || chk "CIS.6.1.2.1" FAIL "/etc/passwd en ${p:-?} (attendu 644)"
p=$(stat -c '%a' /etc/shadow 2>/dev/null)
[ "$p" = "640" ] || [ "$p" = "640" ] && chk "CIS.6.1.2.2" PASS "/etc/shadow en $p" || chk "CIS.6.1.2.2" FAIL "/etc/shadow en ${p:-?} (attendu 640)"
p=$(stat -c '%a' /etc/group 2>/dev/null)
[ "$p" = "644" ] && chk "CIS.6.1.2.3" PASS "/etc/group en 644" || chk "CIS.6.1.2.3" FAIL "/etc/group en ${p:-?} (attendu 644)"
p=$(stat -c '%a' /etc/gshadow 2>/dev/null)
[ "$p" = "640" ] && chk "CIS.6.1.2.4" PASS "/etc/gshadow en 640" || chk "CIS.6.1.2.4" FAIL "/etc/gshadow en ${p:-?} (attendu 640)"

# -----------------------------------------------------------------------------
# 6.1.3.x - Restriction des acces root
# -----------------------------------------------------------------------------
p=$(stat -c '%a' /root 2>/dev/null)
[ "$p" = "700" ] || [ "$p" = "750" ] && chk "CIS.6.1.3.1" PASS "/root en $p" || chk "CIS.6.1.3.1" FAIL "/root en ${p:-?} (attendu 700 ou 750)"

# -----------------------------------------------------------------------------
# 4.1.1.x - Les evenements d'audit sont collectes
# -----------------------------------------------------------------------------
if systemctl is-active --quiet auditd 2>/dev/null && [ -f /etc/audit/rules.d/90-pve.rules ]; then
    chk "CIS.4.1.1.1" PASS "auditd actif avec regles /etc/pve"
elif systemctl is-active --quiet auditd 2>/dev/null; then
    chk "CIS.4.1.1.1" FAIL "auditd actif mais aucune regle sur /etc/pve"
else
    chk "CIS.4.1.1.1" FAIL "auditd inactif"
fi

# -----------------------------------------------------------------------------
# 3.2.x - Modules noyau : les modules inutilises sont desactives
# -----------------------------------------------------------------------------
unused=""
for m in cramfs freevxfs hfs hfsplus jffs2 udf dccp sctp rds tipc atm can; do
    if grep -qrE "install[[:space:]]+$m[[:space:]]+/bin/false" /etc/modprobe.d/ 2>/dev/null; then
        unused="$unused $m"
    fi
done
n_unused=$(echo $unused | wc -w)
if [ "$n_unused" -ge 12 ]; then
    chk "CIS.3.2.1.1" PASS "$n_unused modules inutilises desactives"
else
    chk "CIS.3.2.1.1" FAIL "seulement $n_unused modules inutilises desactives (attendu 12)"
fi

# -----------------------------------------------------------------------------
# 4.1.2.x - Journalisation vers un collecteur distant (facultatif, adapte au lab)
# -----------------------------------------------------------------------------
if grep -rqsE 'action\(type="omfwd"' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
    chk "CIS.4.1.2.1" PASS "rsyslog transfere vers un collecteur distant"
else
    chk "CIS.4.1.2.1" INFO "rsyslog : pas de collecteur distant configure (hors perimetre lab)"
fi

# (pas de 'exit' : ce fichier est SOURCЕ par audit-pve.sh, un exit tuerait le script parent)
