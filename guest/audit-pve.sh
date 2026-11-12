#!/usr/bin/env bash
# =============================================================================
# audit-pve.sh - Collecteur d'etat de securite (LECTURE SEULE) pour Proxmox VE 9
# -----------------------------------------------------------------------------
# Objectif : produire un instantane reproductible de la posture de securite d'un
# noeud PVE 9 / Debian 13, afin de comparer l'etat AVANT et APRES hardening.
#
# Contrat de sortie :
#   ## <SECTION>                 en-tete de section
#   $ <commande>                 commande executee
#     <sortie>                   sortie brute (indentation 2 espaces)
#   @@CHECK <ID> <STATUS> <txt>  controle objectif
#                                 STATUS = PASS | FAIL | NA | INFO
#
# Le script ne modifie RIEN sur le systeme : aucune commande de mutation.
# Usage : bash audit-pve.sh [repertoire_de_sortie]
# =============================================================================

set -u
export LC_ALL=C

OUT_DIR="${1:-/tmp/pve-audit}"
mkdir -p "$OUT_DIR" 2>/dev/null || OUT_DIR="/tmp/pve-audit-$$"
mkdir -p "$OUT_DIR"

PASS_COUNT=0; FAIL_COUNT=0; NA_COUNT=0; INFO_COUNT=0
CHECK_LINES="$OUT_DIR/checks.tsv"

# Toute la sortie est capturable dans un fichier ET affichee dans le terminal.
exec > >(tee "$OUT_DIR/audit.txt") 2>&1

sec()  { printf '\n## %s\n' "$*"; }
run()  { printf '$ %s\n' "$*"; eval "$@" 2>&1 | sed 's/^/  /' | head -n 200; }
chk()  {
    local id="$1" status="$2"; shift 2
    printf '@@CHECK %s %s %s\n' "$id" "$status" "$*"
    printf '%s\t%s\t%s\n' "$id" "$status" "$*" >> "$CHECK_LINES"
    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT+1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT+1)) ;;
        NA)   NA_COUNT=$((NA_COUNT+1)) ;;
        *)    INFO_COUNT=$((INFO_COUNT+1)) ;;
    esac
}
perm() { # perm <fichier> -> "mode owner:group"
    if [ -e "$1" ]; then stat -c '%a %U:%G' "$1" 2>/dev/null || echo "?"; else echo "ABSENT"; fi
}
# Verifie qu'un module noyau n'est pas charge ET qu'il est neutralise
module_disabled() {
    local m="$1"
    if lsmod 2>/dev/null | awk '{print $1}' | grep -qx "$m"; then
        echo "CHARGED"; return 1
    fi
    if grep -rqsE "^\s*install\s+${m}\s+/bin/false|^\s*blacklist\s+${m}" \
        /etc/modprobe.d /lib/modprobe.d 2>/dev/null; then
        echo "BLACKLISTED"; return 0
    fi
    echo "NON-CHARGE-NON-BLOQUE"; return 2
}
# Valeur effective d'un parametre sshd
sshd_val() { sshd -T 2>/dev/null | awk -v k="$1" '$1==k { $1=""; sub(/^ /,""); print; exit }'; }
# Valeur sysctl
sysctl_v() { sysctl -n "$1" 2>/dev/null | head -n1; }
# Le fichier contient-il exactement ce motif ?
file_has() { grep -qsE "$2" "$1" 2>/dev/null && echo yes || echo no; }

echo "### audit-pve.sh - debut $(date -Is)"

# =============================================================================
sec "IDENTITE DU SYSTEME"
# =============================================================================
run "cat /etc/os-release"
run "pveversion -v 2>/dev/null || true"
run "uname -a"
run "uptime"
run "systemd-detect-virt 2>/dev/null; dmesg 2>/dev/null | grep -i -m3 'hypervisor' || true"
run "nproc; free -m"
run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null || true"
run "df -hT -x tmpfs -x devtmpfs"

osrel="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-?}")"
pvever="$(pveversion 2>/dev/null | awk '{print $2}' | tr -d ':')"
chk "SYS.01" INFO "Debian=${osrel} PVE=${pvever:-unknown}"

# =============================================================================
sec "1.1 BASE OS - Modules noyau / core dumps / montages"
# =============================================================================
for m in cramfs freevxfs hfs hfsplus jffs2; do
    st=$(module_disabled "$m")
    case "$st" in
        CHARGED) chk "OS.MOD.$m" FAIL "module $m charge (CIS 1.1.1.x)" ;;
        BLACKLISTED) chk "OS.MOD.$m" PASS "module $m neutralise" ;;
        *) chk "OS.MOD.$m" PASS "module $m non charge" ;;
    esac
done
for m in dccp sctp rds tipc atm can; do
    st=$(module_disabled "$m")
    case "$st" in
        CHARGED) chk "OS.NETMOD.$m" FAIL "module $m charge (CIS 3.2.x)" ;;
        BLACKLISTED) chk "OS.NETMOD.$m" PASS "module $m neutralise" ;;
        *) chk "OS.NETMOD.$m" PASS "module $m non charge" ;;
    esac
done

v=$(sysctl_v fs.suid_dumpable)
[ "$v" = "0" ] && chk "OS.COREDUMP.SYSCALL" PASS "fs.suid_dumpable=0" \
                || chk "OS.COREDUMP.SYSCALL" FAIL "fs.suid_dumpable=${v:-inconnu} (attendu 0)"

check_mount() { # check_mount <point> <exiger_noexec:0|1>
    local mp="$1" need_noexec="$2" opts
    opts=$(findmnt -n -o TARGET,OPTIONS --target "$mp" 2>/dev/null | head -n1 | awk '{print $2}')
    if [ -z "$opts" ]; then chk "OS.MOUNT.$(echo "$mp" | tr '/' '_')" NA "$mp non monte"; return; fi
    local bad=""
    echo "$opts" | grep -qw nodev || bad="$bad nodev"
    echo "$opts" | grep -qw nosuid || bad="$bad nosuid"
    [ "$need_noexec" = "1" ] && { echo "$opts" | grep -qw noexec || bad="$bad noexec"; }
    if [ -z "$bad" ]; then
        chk "OS.MOUNT.$(echo "$mp" | tr '/' '_')" PASS "$mp opts=$opts"
    else
        chk "OS.MOUNT.$(echo "$mp" | tr '/' '_')" FAIL "$mp opts=$opts (manquant:$bad )"
    fi
}
check_mount /tmp 0
check_mount /var/tmp 1
check_mount /dev/shm 1

run "cat /etc/fstab"
run "ls -ld /tmp /var/tmp /dev/shm"
run "grep -rE '^\s*\*\s+hard\s+core|^\s*\*\s+soft\s+core' /etc/security/limits.d /etc/security/limits.conf 2>/dev/null || true"
if grep -rqE '(hard|soft)\s+core\s+0' /etc/security/limits.d /etc/security/limits.conf 2>/dev/null; then
    chk "OS.COREDUMP.LIMITS" PASS "limite core dumps a 0"
else
    chk "OS.COREDUMP.LIMITS" FAIL "aucune limite 'core 0' dans /etc/security/limits.d"
fi

# =============================================================================
sec "1.1 BASE OS - Cron / at"
# =============================================================================
run "ls -ld /etc/crontab /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 2>/dev/null"
run "stat -c '%a %U:%G %n' /etc/crontab /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /etc/at.allow /etc/at.deny 2>/dev/null"
p=$(perm /etc/crontab | awk '{print $1}')
[ "$p" = "600" ] && chk "OS.CRON.CRONTAB" PASS "/etc/crontab en 600" \
                 || chk "OS.CRON.CRONTAB" FAIL "/etc/crontab en ${p:-?} (attendu 600)"
for d in /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    p=$(perm "$d" | awk '{print $1}')
    [ "$p" = "700" ] && chk "OS.CRON.DIR.$(basename "$d")" PASS "$d en 700" \
                     || chk "OS.CRON.DIR.$(basename "$d")" FAIL "$d en ${p:-?} (attendu 700)"
done
run "ls -l /etc/cron.d/ 2>/dev/null"

# =============================================================================
sec "1.1 BASE OS - Journald / rsyslog / auditd"
# =============================================================================
run "systemctl is-active systemd-journald rsyslog auditd 2>&1"
run "systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^(Storage|Compress|SystemMaxUse|MaxRetentionSec)' || true"
run "cat /etc/systemd/journald.conf.d/*.conf 2>/dev/null || true"
for kv in "Storage=persistent" "Compress=yes"; do
    k="${kv%%=*}"; val="${kv#*=}"
    if systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -qE "^${k}=${val}"; then
        chk "OS.JOURNALD.${k}" PASS "$k=$val"
    else
        chk "OS.JOURNALD.${k}" FAIL "$k != $val"
    fi
done
if systemctl is-active --quiet auditd 2>/dev/null; then
    chk "OS.AUDITD.ACTIVE" PASS "auditd actif"
else
    chk "OS.AUDITD.ACTIVE" FAIL "auditd inactif ou absent"
fi
run "auditctl -s 2>/dev/null || true"
run "cat /etc/audit/rules.d/*.rules 2>/dev/null || true"
if grep -qs '/etc/pve' /etc/audit/rules.d/*.rules /etc/audit/audit.rules 2>/dev/null; then
    chk "OS.AUDITD.PVE" PASS "regles d'audit sur /etc/pve"
else
    chk "OS.AUDITD.PVE" FAIL "aucune regle d'audit sur /etc/pve"
fi
if systemctl is-active --quiet rsyslog 2>/dev/null; then
    chk "OS.RSYSLOG" PASS "rsyslog actif"
else
    chk "OS.RSYSLOG" INFO "rsyslog inactif (logs locaux uniquement)"
fi

# =============================================================================
sec "1.1 BASE OS - SSH : permissions et configuration effective"
# =============================================================================
run "ls -la /etc/ssh/ /etc/ssh/sshd_config.d/ 2>/dev/null"
run "stat -c '%a %U:%G %n' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null"
run "stat -c '%a %U:%G %n' /etc/ssh/ssh_host_*_key 2>/dev/null"
run "stat -c '%a %U:%G %n' /root/.ssh /root/.ssh/authorized_keys 2>/dev/null"
run "sshd -T 2>/dev/null | sort"

for f in "/etc/ssh/sshd_config:600" "/etc/ssh/sshd_config.d:700"; do
    path="${f%%:*}"; want="${f##*:}"
    p=$(perm "$path" | awk '{print $1}')
    if [ "$p" = "$want" ]; then chk "OS.SSHD.PERM.$(basename "$path")" PASS "$path en $p"
    else chk "OS.SSHD.PERM.$(basename "$path")" FAIL "$path en ${p:-?} (attendu $want)"; fi
done
badkeys=0
for k in /etc/ssh/ssh_host_*_key; do
    [ -e "$k" ] || continue
    p=$(stat -c '%a' "$k")
    [ "$p" = "600" ] || badkeys=1
done
[ "$badkeys" = "0" ] && chk "OS.SSHD.HOSTKEYS" PASS "cles hote en 600" \
                    || chk "OS.SSHD.HOSTKEYS" FAIL "cles hote non 600"

v=$(sshd_val permitrootlogin)
case "$v" in
    no) chk "OS.SSHD.PERMITROOT" PASS "PermitRootLogin=no" ;;
    prohibit-password|without-password) chk "OS.SSHD.PERMITROOT" INFO "PermitRootLogin=$v (acces root par cle uniquement)" ;;
    *) chk "OS.SSHD.PERMITROOT" FAIL "PermitRootLogin=${v:-?} (attendu no/prohibit-password)" ;;
esac
v=$(sshd_val passwordauthentication)
[ "$v" = "no" ] && chk "OS.SSHD.PASSWORDAUTH" PASS "PasswordAuthentication=no" \
                || chk "OS.SSHD.PASSWORDAUTH" FAIL "PasswordAuthentication=${v:-?}"
v=$(sshd_val pubkeyauthentication)
[ "$v" = "yes" ] && chk "OS.SSHD.PUBKEY" PASS "PubkeyAuthentication=yes" \
                || chk "OS.SSHD.PUBKEY" FAIL "PubkeyAuthentication=${v:-?}"
v=$(sshd_val permitemptypasswords)
[ "$v" = "no" ] && chk "OS.SSHD.EMPTYPASS" PASS "PermitEmptyPasswords=no" \
               || chk "OS.SSHD.EMPTYPASS" FAIL "PermitEmptyPasswords=${v:-?}"
v=$(sshd_val x11forwarding)
[ "$v" = "no" ] && chk "OS.SSHD.X11" PASS "X11Forwarding=no" \
               || chk "OS.SSHD.X11" FAIL "X11Forwarding=${v:-?}"
v=$(sshd_val maxauthtries)
[ -n "$v" ] && [ "$v" -le 6 ] 2>/dev/null && chk "OS.SSHD.MAXAUTH" PASS "MaxAuthTries=$v" \
                                  || chk "OS.SSHD.MAXAUTH" FAIL "MaxAuthTries=${v:-?} (>6)"
v=$(sshd_val logingracetime)
[ -n "$v" ] && [ "$v" -le 60 ] 2>/dev/null && chk "OS.SSHD.GRACETIME" PASS "LoginGraceTime=$v" \
                                   || chk "OS.SSHD.GRACETIME" FAIL "LoginGraceTime=${v:-?}"
v=$(sshd_val allowusers); vu=$(sshd_val allowgroups)
if [ -n "$v" ] || [ -n "$vu" ]; then
    chk "OS.SSHD.ALLOWLIST" PASS "AllowUsers=${v:-none} AllowGroups=${vu:-none}"
else
    chk "OS.SSHD.ALLOWLIST" FAIL "aucune restriction AllowUsers/AllowGroups"
fi
v=$(sshd_val clientaliveinterval); vc=$(sshd_val clientalivecountmax)
if [ -n "$v" ] && [ "$v" != "0" ] 2>/dev/null; then
    chk "OS.SSHD.CLIENTALIVE" PASS "ClientAliveInterval=$v CountMax=${vc:-?}"
else
    chk "OS.SSHD.CLIENTALIVE" FAIL "ClientAliveInterval=${v:-0} (non configure)"
fi
# Chiffrement
ciph=$(sshd_val ciphers | tr 'A-Z' 'a-z')
if [ -n "$ciph" ]; then
    weak=$(echo "$ciph" | tr ',' '\n' | grep -E '^(cbc|3des|arcfour|blowfish|des|rc4)' | tr '\n' ' ')
    if [ -z "$weak" ]; then chk "OS.SSHD.CIPHERS" PASS "ciphers sans algorithme faible"
    else chk "OS.SSHD.CIPHERS" FAIL "ciphers faibles presents: $weak"; fi
else
    chk "OS.SSHD.CIPHERS" NA "sshd -T indisponible"
fi
macs=$(sshd_val macs | tr 'A-Z' 'a-z')
if [ -n "$macs" ]; then
    weak=$(echo "$macs" | tr ',' '\n' | grep -E '^(hmac-sha1|hmac-md5|umac)' | tr '\n' ' ')
    if [ -z "$weak" ]; then chk "OS.SSHD.MACS" PASS "MACs sans algorithme faible"
    else chk "OS.SSHD.MACS" FAIL "MACs faibles: $weak"; fi
else chk "OS.SSHD.MACS" NA "sshd -T indisponible"; fi
kex=$(sshd_val kexalgorithms | tr 'A-Z' 'a-z')
if [ -n "$kex" ]; then
    weak=$(echo "$kex" | tr ',' '\n' | grep -E 'group1-sha1|group-exchange-sha1|rsa-sha1|diffie-hellman-group-exchange-sha1' | tr '\n' ' ')
    if [ -z "$weak" ]; then chk "OS.SSHD.KEX" PASS "KexAlgorithms sans algorithme faible"
    else chk "OS.SSHD.KEX" FAIL "KEX faibles: $weak"; fi
else chk "OS.SSHD.KEX" NA "sshd -T indisponible"; fi
run "sshd -T 2>/dev/null | grep -Ei 'banner|maxsessions|maxstartups|loglevel|permitemptypasswords|authenticationmethods'"

# =============================================================================
sec "1.1 BASE OS - PAM : faillock, qualite de mot de passe"
# =============================================================================
run "grep -n 'pam_faillock' /etc/pam.d/common-auth /etc/pam.d/sshd /etc/pam.d/login 2>/dev/null || true"
run "cat /etc/security/faillock.conf 2>/dev/null || true"
if grep -qs 'pam_faillock' /etc/pam.d/common-auth; then
    chk "OS.PAM.FAILLOCK" PASS "pam_faillock configure"
else
    chk "OS.PAM.FAILLOCK" FAIL "pam_faillock absent de /etc/pam.d/common-auth"
fi
if [ -f /etc/security/faillock.conf ]; then
    deny=$(awk -F= '/^[[:space:]]*deny[[:space:]]*=/ {print $2}' /etc/security/faillock.conf | tr -d ' ')
    unlock=$(awk -F= '/^[[:space:]]*unlock_time[[:space:]]*=/ {print $2}' /etc/security/faillock.conf | tr -d ' ')
    if [ -n "$deny" ] && [ "$deny" -le 10 ] 2>/dev/null; then
        chk "OS.PAM.FAILLOCK.POLICY" PASS "deny=$deny unlock_time=${unlock:-?}"
    else
        chk "OS.PAM.FAILLOCK.POLICY" FAIL "deny=${deny:-?}"
    fi
else
    chk "OS.PAM.FAILLOCK.POLICY" FAIL "/etc/security/faillock.conf absent"
fi
run "cat /etc/security/pwquality.conf 2>/dev/null || true"
if dpkg -l 2>/dev/null | grep -qE '^ii[[:space:]]+(libpam-pwquality|cracklib)(:|[[:space:]])'; then
    chk "OS.PAM.PWQUALITY" PASS "libpam-pwquality / cracklib installe"
else
    chk "OS.PAM.PWQUALITY" FAIL "aucun module de qualite de mot de passe installe"
fi
minlen=$(awk -F= '/^[[:space:]]*minlen[[:space:]]*=/ {gsub(/ /,"",$2); print $2}' /etc/security/pwquality.conf 2>/dev/null)
[ -n "$minlen" ] && [ "$minlen" -ge 12 ] 2>/dev/null \
    && chk "OS.PAM.MINLEN" PASS "minlen=$minlen" \
    || chk "OS.PAM.MINLEN" FAIL "minlen=${minlen:-non defini} (attendu >=12)"

# =============================================================================
sec "1.1 BASE OS - AppArmor / updates automatiques / NTP"
# =============================================================================
run "aa-status 2>/dev/null | head -n 8 || systemctl is-active apparmor 2>&1"
if systemctl is-active --quiet apparmor 2>/dev/null; then
    chk "OS.APPARMOR.ACTIVE" PASS "apparmor actif"
    if command -v aa-status >/dev/null 2>&1; then
        # aa-status affiche "X profiles are in complain mode." / "... in enforce mode."
        cc=$(aa-status 2>/dev/null | awk '
            /profiles are in complain mode/ { for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) { c=$i; break } }
            /profiles are in enforce mode/  { for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) { e=$i; break } }
            END { print c+0 " " e+0 }')
        complain=$(echo "$cc" | awk '{print $1}'); enforce=$(echo "$cc" | awk '{print $2}')
        if [ "${complain:-0}" -eq 0 ] && [ "${enforce:-0}" -gt 0 ]; then
            chk "OS.APPARMOR.ENFORCE" PASS "$enforce profils en enforce, 0 en complain"
        else
            chk "OS.APPARMOR.ENFORCE" FAIL "complain=$complain enforce=$enforce"
        fi
    fi
else
    chk "OS.APPARMOR.ACTIVE" FAIL "apparmor inactif"
fi
if dpkg -l 2>/dev/null | grep -qE '^ii[[:space:]]+unattended-upgrades(:|[[:space:]])'; then
    chk "OS.UNATTENDED.PKG" PASS "unattended-upgrades installe"
else
    chk "OS.UNATTENDED.PKG" FAIL "unattended-upgrades absent"
fi
run "cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || true"
if [ -f /etc/apt/apt.conf.d/20auto-upgrades ] && grep -q 'APT::Periodic::Update-Package-Lists "1"' /etc/apt/apt.conf.d/20auto-upgrades; then
    chk "OS.UNATTENDED.ENABLED" PASS "mises a jour automatiques activees"
else
    chk "OS.UNATTENDED.ENABLED" FAIL "mises a jour automatiques non activees"
fi
if command -v chronyd >/dev/null 2>&1 || systemctl is-active --quiet chrony 2>/dev/null || systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
    chk "OS.NTP" PASS "service de synchronisation temps present"
else
    chk "OS.NTP" FAIL "aucun service NTP/chrony actif"
fi
run "timedatectl 2>/dev/null | head -n 12"

# =============================================================================
sec "2.1 UTILISATEURS / PRIVILEGES"
# =============================================================================
run "awk -F: '\$3==0 {print \$1}' /etc/passwd"
run "getent group sudo wheel root admin 2>/dev/null"
run "stat -c '%a %U:%G %n' /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers 2>/dev/null"
run "cat /etc/sudoers 2>/dev/null | grep -vE '^\\s*#|^\\s*$'"
nroot=$(awk -F: '$3==0 {c++} END{print c+0}' /etc/passwd)
[ "$nroot" = "1" ] && chk "USR.UID0" PASS "un seul compte UID 0" \
                  || chk "USR.UID0" FAIL "$nroot comptes UID 0"
p=$(perm /etc/shadow | awk '{print $1}')
[ "$p" = "640" ] || [ "$p" = "600" ] && chk "USR.SHADOW.PERM" PASS "/etc/shadow en $p" \
                                || chk "USR.SHADOW.PERM" FAIL "/etc/shadow en ${p:-?} (attendu 640/600)"
run "awk -F: '\$2!=\"\" && \$2!=\"*\" && \$2!=\"!\" {print \$1}' /etc/shadow"
if [ -f /etc/shadow ]; then
    nhash=$(awk -F: '$2!="" && $2!="*" && $2!="!" {print $2}' /etc/shadow | grep -cE '\$y\$' || true)
    nempty=$(awk -F: '$2=="" {c++} END{print c+0}' /etc/shadow)
    [ "$nempty" = "0" ] && chk "USR.EMPTY.PASS" PASS "aucun compte sans mot de passe" \
                        || chk "USR.EMPTY.PASS" FAIL "$nempty comptes sans mot de passe"
    chk "USR.HASH" INFO "$nhash comptes avec hash yescrypt (\$y\$)"
fi
run "last -n 5 2>/dev/null | head -n 10 || true"

# =============================================================================
sec "2.2 API TOKENS / 2.3 GUI"
# =============================================================================
run "cat /etc/pve/priv/token.cfg 2>/dev/null || echo 'aucun token API'"
ntok=$(grep -c 'token' /etc/pve/priv/token.cfg 2>/dev/null || echo 0)
chk "PVE.API.TOKENS" INFO "$ntok token(s) API dans /etc/pve/priv/token.cfg"
run "ls -l /etc/pve/priv/ 2>/dev/null"
run "ls -l /etc/pve/local/ 2>/dev/null"
run "find /etc/pve -maxdepth 2 -printf '%m %u:%g %p\\n' 2>/dev/null | head -n 40"
run "openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -noout -subject -dates 2>/dev/null || true"
if openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -noout -checkend 2592000 >/dev/null 2>&1; then
    chk "PVE.GUI.CERT" PASS "certificat GUI valide > 30 jours"
else
    chk "PVE.GUI.CERT" INFO "certificat GUI absent ou a renouveler"
fi
if dpkg -l 2>/dev/null | grep -qE '^ii[[:space:]]+fail2ban(:|[[:space:]])'; then
    chk "PVE.F2B.PKG" PASS "fail2ban installe"
    run "fail2ban-client status 2>/dev/null || true"
    run "grep -rsE 'pveproxy|pvedaemon|proxmox' /etc/fail2ban/jail.local /etc/fail2ban/jail.d/ 2>/dev/null || true"
    if grep -qsrE 'pveproxy|pvedaemon|proxmox' /etc/fail2ban/jail.local /etc/fail2ban/jail.d/ 2>/dev/null; then
        chk "PVE.F2B.GUI" PASS "fail2ban protege l'interface web Proxmox"
    else
        chk "PVE.F2B.GUI" FAIL "fail2ban ne protege pas l'interface web Proxmox"
    fi
else
    chk "PVE.F2B.PKG" FAIL "fail2ban absent"
    chk "PVE.F2B.GUI" FAIL "fail2ban absent"
fi

# =============================================================================
sec "1.2 BASE PVE - Pare-feu, cluster, SDN, KSM"
# =============================================================================
run "pve-firewall status 2>&1 || true"
run "ls -la /etc/pve/firewall/ 2>/dev/null"
if [ -f /etc/pve/firewall/cluster.fw ]; then
    chk "PVE.FW.CLUSTER" PASS "/etc/pve/firewall/cluster.fw present"
else
    chk "PVE.FW.CLUSTER" FAIL "/etc/pve/firewall/cluster.fw absent (pare-feu cluster desactive)"
fi
run "cat /etc/pve/firewall/cluster.fw 2>/dev/null"
nodedir=$(ls -d /etc/pve/nodes/*/ 2>/dev/null | head -n1)
if [ -n "$nodedir" ] && [ -f "${nodedir}firewall" ]; then
    # Sur PVE, la politique par defaut est INPUT=DROP : la config peut s'ecrire
    # "policy_in: DROP", "policy: DROP" ou "policy DROP" -> on accepte les 3.
    # Attention : "policy_in" ne matche PAS 'policy\b' (_ est un caractere de mot).
    pol=$(grep -iE '^\s*(policy[_a-z]*|enable)\b' "${nodedir}firewall" 2>/dev/null | tr '\n' ';')
    if echo "$pol" | grep -qiE 'policy(_in)?[[:space:]]*[:=]?[[:space:]]*drop'; then
        chk "PVE.FW.FORWARD" PASS "politique INPUT/FORWARD = DROP ($pol)"
    else
        chk "PVE.FW.FORWARD" FAIL "politique INPUT/FORWARD non DROP ($pol)"
    fi
else
    chk "PVE.FW.FORWARD" NA "pas de configuration firewall par noeud"
fi
run "nft list ruleset 2>/dev/null | head -n 60"
run "iptables-save 2>/dev/null | head -n 40"
run "systemctl is-enabled pve-firewall 2>&1"
run "pvecm status 2>&1 | head -n 25"
run "pvesh get /cluster/firewall/options --output-format json 2>/dev/null || true"
run "pvesh get /cluster/sdn/zones --output-format json 2>/dev/null || true"
run "pvesh get /cluster/sdn/vnets --output-format json 2>/dev/null || true"
run "pvesh get /cluster/options --output-format json 2>/dev/null | head -c 2000 || true"
ksm=$(sysctl_v kernel.ksm)
if [ "$ksm" = "0" ] || [ "$ksm" = "1" ]; then
    chk "PVE.KSM" INFO "kernel.ksm=$ksm"
fi
run "lsmod | grep -E '^ksm' || true"
run "cat /etc/pve/storage.cfg 2>/dev/null"
for f in /etc/pve/datacenter.cfg /etc/pve/cluster/cluster.cfg; do
    [ -f "$f" ] && run "cat $f"
done

# =============================================================================
sec "1.2 BASE PVE - Conteneurs, boot, cryptographie"
# =============================================================================
run "ls -1 /etc/pve/containers/ 2>/dev/null"
unpriv=$(grep -l 'unprivileged' /etc/pve/containers/*.conf 2>/dev/null | wc -l)
total=$(ls -1 /etc/pve/containers/*.conf 2>/dev/null | wc -l)
if [ "$total" = "0" ]; then
    chk "PVE.LXC.UNPRIV" NA "aucun conteneur LXC"
elif [ "$unpriv" = "$total" ]; then
    chk "PVE.LXC.UNPRIV" PASS "$total/$total conteneurs non privilegies"
else
    chk "PVE.LXC.UNPRIV" FAIL "$((total-unpriv))/$total conteneurs privilegies"
fi
run "cat /etc/default/lxc 2>/dev/null || true"
run "grep -R 'unprivileged' /etc/pve/containers/ 2>/dev/null || true"

# Secure Boot / Lockdown
if [ -d /sys/firmware/efi/efivars ]; then
    sb=$(efivarfs 2>/dev/null | grep -i 'SecureBoot' || true)
    if echo "$sb" | grep -q 'SecureBoot=1'; then
        chk "PVE.BOOT.SECUREBOOT" PASS "Secure Boot actif"
    else
        chk "PVE.BOOT.SECUREBOOT" FAIL "Secure Boot inactif"
    fi
else
    chk "PVE.BOOT.SECUREBOOT" NA "demarrage BIOS (pas d'efivarfs) - non applicable en lab VirtualBox"
fi
if [ -r /sys/kernel/security/lockdown ]; then
    lk=$(cat /sys/kernel/security/lockdown)
    case "$lk" in
        none) chk "PVE.BOOT.LOCKDOWN" FAIL "kernel lockdown desactive" ;;
        integrity|confidentiality) chk "PVE.BOOT.LOCKDOWN" PASS "kernel lockdown=$lk" ;;
        *) chk "PVE.BOOT.LOCKDOWN" INFO "kernel lockdown=$lk" ;;
    esac
else
    chk "PVE.BOOT.LOCKDOWN" NA "lockdown non disponible sur ce noyau"
fi
run "lsblk -o NAME,TYPE,FSTYPE 2>/dev/null"
if lsblk -o NAME,FSTYPE 2>/dev/null | grep -q crypto_LUKS; then
    chk "PVE.CRYPT.LUKS" PASS "volume LUKS detecte"
else
    # Le chiffrement de disque se decide a l'installation (ZFS sur LUKS) et n'est
    # pas rattrapable a chaud : hors perimetre des niveaux de durcissement
    # CIS L1/L2 (CIS Debian ne l'exige qu'en niveau eleve / donnee sensible).
    chk "PVE.CRYPT.LUKS" NA "chiffrement de disque non applique (decision d'installation, hors perimetre CIS L1/L2)"
fi
run "dmesg 2>/dev/null | grep -iE 'secure boot|lockdown' | head -n 5 || true"

# =============================================================================
sec "5.x JOURNALISATION / AUDIT / DETECTION ROOTKIT"
# =============================================================================
run "systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{print \$1}'"
run "journalctl --disk-usage 2>/dev/null || true"
run "find /var/log -maxdepth 1 -type f -printf '%m %u:%g %s %p\\n' 2>/dev/null | head -n 30"
if command -v rkhunter >/dev/null 2>&1 || command -v chkrootkit >/dev/null 2>&1; then
    chk "OS.ROOTKIT.TOOL" PASS "outil de detection de rootkit installe"
else
    chk "OS.ROOTKIT.TOOL" FAIL "ni rkhunter ni chkrootkit installes"
fi
run "ls -la /etc/logrotate.d/ 2>/dev/null | head -n 20"

# =============================================================================
sec "RESEAU"
# =============================================================================
run "ip -brief address 2>/dev/null"
run "ip route 2>/dev/null"
run "ss -tulpn 2>/dev/null | head -n 40"
run "cat /etc/network/interfaces 2>/dev/null"
run "cat /etc/hosts 2>/dev/null"

# =============================================================================
sec "PAQUETS INSTALLES (reference securite)"
# =============================================================================
run "dpkg -l 2>/dev/null | grep -E 'auditd|apparmor|fail2ban|unattended|libpam-pwquality|openvpn|chrony|rsyslog|ssh-audit|debsums|rkhunter|chkrootkit|nftables|iptables|dnsmasq' | awk '{print \$1, \$2, \$3}'"

# =============================================================================
# Audits supplementaires (ANSSI, Ceph) selon AUDIT_EXTRA
# =============================================================================
if [ -n "${AUDIT_EXTRA:-}" ]; then
    for extra in $(printf '%s' "$AUDIT_EXTRA" | tr ',' ' '); do
        if [ -f "/root/audit-$extra.sh" ]; then
            . "/root/audit-$extra.sh"
        fi
    done
fi

printf '\n### audit-pve.sh - fin %s\n' "$(date -Is)"
printf '\n## SYNTHESE\n'
printf 'PASS=%d FAIL=%d NA=%d INFO=%d TOTAL=%d\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$NA_COUNT" "$INFO_COUNT" \
    "$((PASS_COUNT+FAIL_COUNT+NA_COUNT+INFO_COUNT))"
printf '@@CHECK __SUMMARY__ PASS PASS=%d FAIL=%d NA=%d INFO=%d\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$NA_COUNT" "$INFO_COUNT"
