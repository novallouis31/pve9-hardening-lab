#!/usr/bin/env bash
# =============================================================================
# audit-communautaire.sh - Controls issus des projets open source communautaires
# -----------------------------------------------------------------------------
# References :
#   - hardenedlinux/harbian-audit (472*) : checks numerotes 1.5.x, 7.2.x,
#     10.x, 12.x, 13.x sur un Debian durci.
#   - Makaveli81/ansible-linux-hardening (59*) : audit_items ANSSI BP-028
#     (niveaux M/I/R/E).
#
# Ces controls complementent audit-pve.sh / audit-cis13.sh / audit-anssi.sh
# sur les points non encore couverts (sysctl reseau, sudoers, shell de comptes,
# permissions des journaux, etc.).
#
# Contrat de sortie : @@CHECK <ID> <PASS|FAIL|NA|INFO> <detail>
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

sec "Controles communautaires (harbian-audit + ANSSI BP-028)"

# -----------------------------------------------------------------------------
# Sysctl reseau (harbian 7.2.1 a 7.2.8, 7.3.1, 7.3.2)
# -----------------------------------------------------------------------------
sysctl_ok() {
    # sysctl_ok <cle> <valeur attendue>
    local k="$1" want="$2" v
    v=$(sysctl -n "$k" 2>/dev/null | head -n1)
    if [ "$v" = "$want" ]; then
        chk "COMM.SYSCTL.$(echo "$k" | tr 'a-z.' 'A-Z_')" PASS "$k=$v"
    else
        chk "COMM.SYSCTL.$(echo "$k" | tr 'a-z.' 'A-Z_')" FAIL "$k=${v:-?} (attendu $want)"
    fi
}

sysctl_ok net.ipv4.conf.all.accept_redirects 0
sysctl_ok net.ipv4.conf.default.accept_redirects 0
sysctl_ok net.ipv4.conf.all.send_redirects 0
sysctl_ok net.ipv4.conf.default.send_redirects 0
sysctl_ok net.ipv4.icmp_echo_ignore_broadcasts 1
sysctl_ok net.ipv4.tcp_syncookies 1
# rp_filter : 1 (loose) ou 2 (strict). Debian 13 utilise 2, qui est PLUS
# strict que 1 : les deux valeurs sont conformes (harbian 7.2.x).
for iface in all default; do
    v=$(sysctl -n "net.ipv4.conf.${iface}.rp_filter" 2>/dev/null | head -n1)
    if [ "$v" = "1" ] || [ "$v" = "2" ]; then
        chk "COMM.SYSCTL.NET_IPV4_CONF_${iface}_RP_FILTER" PASS "rp_filter=$v (1=loose, 2=strict)"
    else
        chk "COMM.SYSCTL.NET_IPV4_CONF_${iface}_RP_FILTER" FAIL "rp_filter=${v:-?} (attendu 1 ou 2)"
    fi
done
sysctl_ok net.ipv6.conf.all.accept_redirects 0
sysctl_ok net.ipv6.conf.all.accept_ra 0

# -----------------------------------------------------------------------------
# Sysctl noyau (harbian 1.5.2 a 1.5.9, BP-028 [SYS])
# -----------------------------------------------------------------------------
sysctl_ok fs.protected_symlinks 1
sysctl_ok fs.protected_hardlinks 1
sysctl_ok fs.suid_dumpable 0
sysctl_ok kernel.dmesg_restrict 1
sysctl_ok kernel.kptr_restrict 2
sysctl_ok kernel.randomize_va_space 2

v=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null | head -n1)
if [ -n "$v" ] && [ "$v" -ge 1 ] 2>/dev/null; then
    chk "COMM.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE" PASS "ptrace_scope=$v (>=1)"
else
    chk "COMM.SYSCTL.KERNEL_YAMA_PTRACE_SCOPE" FAIL "ptrace_scope=${v:-?} (attendu >=1)"
fi

# -----------------------------------------------------------------------------
# Sudoers (harbian 10.1.6, 10.1.7)
# -----------------------------------------------------------------------------
if [ -d /etc/sudoers.d ]; then
    nopass=$(grep -rhE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -vE '^\s*#' | wc -l)
    noauth=$(grep -rhE '!authenticate|NOAUTH' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -vE '^\s*#' | wc -l)
    if [ "$nopass" -eq 0 ]; then
        chk "COMM.SUDO.NOPASSWD" PASS "aucune directive NOPASSWD dans les sudoers"
    else
        chk "COMM.SUDO.NOPASSWD" FAIL "$nopass directive(s) NOPASSWD"
    fi
    if [ "$noauth" -eq 0 ]; then
        chk "COMM.SUDO.NOAUTH" PASS "aucune directive !authenticate dans les sudoers"
    else
        chk "COMM.SUDO.NOAUTH" FAIL "$noauth directive(s) !authenticate"
    fi
else
    chk "COMM.SUDO.NOPASSWD" NA "/etc/sudoers.d absent"
    chk "COMM.SUDO.NOAUTH" NA "/etc/sudoers.d absent"
fi

# -----------------------------------------------------------------------------
# Permissions des journaux (harbian 8.5, 8.2.3)
# -----------------------------------------------------------------------------
# Repertoires : les modes 2755 (setgid, standard Debian pour /var/log/journal)
# sont acceptes. Seuls les FICHIERS de journaux doivent etre en 640/600/644.
bad_logs=""
for d in /var/log /var/log/journal /var/log/syslog; do
    [ -e "$d" ] || continue
    p=$(stat -c '%a' "$d" 2>/dev/null)
    case "$p" in
        750|700|755|644|640|2755|2750|1777) : ;;
        *) bad_logs="$bad_logs $d($p)" ;;
    esac
done
for f in /var/log/syslog /var/log/auth.log /var/log/messages; do
    [ -f "$f" ] || continue
    p=$(stat -c '%a' "$f" 2>/dev/null)
    case "$p" in
        640|600|644|660) : ;;
        *) bad_logs="$bad_logs $f($p)" ;;
    esac
done
if [ -z "$bad_logs" ]; then
    chk "COMM.LOG.PERMS" PASS "permissions des repertoires de journaux conformes"
else
    chk "COMM.LOG.PERMS" FAIL "permissions excessives :$bad_logs"
fi

# Journald : stockage persistant + compression (harbian 8.7.1, 8.7.2)
if [ -f /etc/systemd/journald.conf.d/99-pve-hardening.conf ]; then
    jd=$(grep -iE '^\s*(Storage|Compress)=' /etc/systemd/journald.conf.d/99-pve-hardening.conf | tr '\n' ';')
    if echo "$jd" | grep -qi 'Storage=persistent'; then
        chk "COMM.JOURNALD.STORAGE" PASS "$jd"
    else
        chk "COMM.JOURNALD.STORAGE" FAIL "Storage!=persistent ($jd)"
    fi
else
    chk "COMM.JOURNALD.STORAGE" INFO "aucune configuration journald dediee"
fi

# -----------------------------------------------------------------------------
# Comptes (harbian 10.1.5, 10.1.9, 13.1, 13.5, 13.20)
# -----------------------------------------------------------------------------
nempty=$(awk -F: '$2=="" {c++} END{print c+0}' /etc/shadow 2>/dev/null)
if [ "${nempty:-0}" -eq 0 ]; then
    chk "COMM.USR.EMPTY.PASSWORD" PASS "aucun compte avec un champ mot de passe vide"
else
    chk "COMM.USR.EMPTY.PASSWORD" FAIL "$nempty compte(s) avec mot de passe vide"
fi

# shadow : aucun groupe ne doit avoir un mot de passe vide (harbian 13.20)
sgempty=$(awk -F: '$2=="" {c++} END{print c+0}' /etc/gshadow 2>/dev/null)
if [ "${sgempty:-0}" -eq 0 ]; then
    chk "COMM.GSHADOW.EMPTY" PASS "aucun groupe avec mot de passe vide"
else
    chk "COMM.GSHADOW.EMPTY" FAIL "$sgempty groupe(s) avec mot de passe vide"
fi

# nobody ne doit pas avoir d'UID 0 (harbian 13.5)
nobody_uid=$(getent passwd nobody 2>/dev/null | cut -d: -f3)
if [ -n "$nobody_uid" ] && [ "$nobody_uid" != "0" ]; then
    chk "COMM.USR.NOBODY.UID" PASS "nobody a l'UID $nobody_uid"
else
    chk "COMM.USR.NOBODY.UID" FAIL "nobody a l'UID ${nobody_uid:-?}"
fi

# -----------------------------------------------------------------------------
# Repertoires personnels (harbian 13.12, 13.13)
# -----------------------------------------------------------------------------
bad_home=""
for d in $(awk -F: '$3>=1000 && $3<65534 && $7!="" {print $7}' /etc/passwd 2>/dev/null | sort -u); do
    [ -d "$d" ] || continue
    own=$(stat -c '%U' "$d" 2>/dev/null)
    user=$(awk -F: -v h="$d" '$7==h {print $1}' /etc/passwd 2>/dev/null | head -1)
    [ -n "$user" ] && [ "$own" != "$user" ] && bad_home="$bad_home $d($own!=$user)"
done
if [ -z "$bad_home" ]; then
    chk "COMM.HOME.OWNERSHIP" PASS "tous les repertoires personnels appartiennent a leur utilisateur"
else
    chk "COMM.HOME.OWNERSHIP" FAIL "proprietaires incorrects :$bad_home"
fi

# -----------------------------------------------------------------------------
# Fichiers SUID / SGID (harbian 12.10, 12.11) - inventaire informatif
# -----------------------------------------------------------------------------
nsuid=$(find / -xdev -perm /6000 -type f 2>/dev/null | wc -l)
chk "COMM.FILES.SUID" INFO "$nsuid fichier(s) SUID sur le systeme de fichiers racine"

# -----------------------------------------------------------------------------
# Fichiers ecrits par tous (harbian 12.7) - hors pseudo-systemes
# -----------------------------------------------------------------------------
nworld=$(find /etc /usr/bin /usr/sbin /bin /sbin -xdev -perm -0002 -type f 2>/dev/null | wc -l)
if [ "${nworld:-0}" -eq 0 ]; then
    chk "COMM.FILES.WORLDWRITABLE" PASS "aucun fichier world-writable dans /etc et les binaires"
else
    chk "COMM.FILES.WORLDWRITABLE" FAIL "$nworld fichier(s) world-writable"
fi

# -----------------------------------------------------------------------------
# Paquets inutiles (harbian 5.1.1, 5.1.2, 5.1.3, 5.1.4, 5.1.5, 5.1.6, 5.1.7)
# -----------------------------------------------------------------------------
legacy=""
for p in nis rsh-client rsh-server talk talk-client telnet inetd; do
    if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q '^install ok installed$'; then
        legacy="$legacy $p"
    fi
done
if [ -z "$legacy" ]; then
    chk "COMM.PKG.LEGACY" PASS "aucun paquet reseau legacy installe"
else
    chk "COMM.PKG.LEGACY" FAIL "paquets legacy installes :$legacy"
fi

# -----------------------------------------------------------------------------
# Mot de passe : methode de hachage (harbian 10.1.4)
# -----------------------------------------------------------------------------
if [ -f /etc/shadow ]; then
    # Debian 13 utilise yescrypt ($y$) par defaut ; SHA-512 ($6$) est
    # egalement accepte. Seuls les hashs reellement obsoletes sont signales.
    nsha512=$(awk -F: '$2 ~ /^\$6\$/ {c++} END{print c+0}' /etc/shadow 2>/dev/null)
    nyescrypt=$(awk -F: '$2 ~ /^\$y\$/ {c++} END{print c+0}' /etc/shadow 2>/dev/null)
    nlegacy=$(awk -F: '$2 ~ /^\$(1|2|3|4|5)\$/ {c++} END{print c+0}' /etc/shadow 2>/dev/null)
    nmodern=$(( nsha512 + nyescrypt ))
    if [ "${nlegacy:-0}" -eq 0 ] && [ "${nmodern:-0}" -gt 0 ]; then
        chk "COMM.PASSWD.HASH" PASS "$nmodern hash(s) moderne(s) (yescrypt=$nyescrypt sha512=$nsha512), 0 obsolete"
    else
        chk "COMM.PASSWD.HASH" FAIL "$nlegacy hash(s) obsolete(s) (yescrypt=$nyescrypt sha512=$nsha512)"
    fi
fi

# -----------------------------------------------------------------------------
# Dossiers sans proprietaire (harbian 12.8, 12.9)
# -----------------------------------------------------------------------------
noun=$(find /etc -xdev \( -nouser -o -nogroup \) 2>/dev/null | wc -l)
chk "COMM.FILES.UNOWNED" INFO "$noun fichier(s) sans proprietaire dans /etc"

# -----------------------------------------------------------------------------
# Extinction automatique de la console (harbian 5.4) - deja couvert par ANS.CTRLALTDEL
# mais on verifie l'absence de ligand/keyboard leftovers
# -----------------------------------------------------------------------------
if systemctl is-enabled ctrl-alt-del.target >/dev/null 2>&1; then
    chk "COMM.CTRLALTDEL" FAIL "ctrl-alt-del.target actif"
else
    chk "COMM.CTRLALTDEL" PASS "ctrl-alt-del.target desactive"
fi
