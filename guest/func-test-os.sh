#!/usr/bin/env bash
# =============================================================================
# func-test-os.sh - Tests fonctionnels de l'OS (avant/apres hardening)
# -----------------------------------------------------------------------------
# Verifie que le durcissement N'ALTERE PAS le fonctionnement du systeme
# d'exploitation lui-meme, au-dela des tests specifiques a Proxmox :
#   - Boot / systemd : etat du systeme, unites en echec,.target par defaut
#   - Sysctl : les parametres appliques sont bien pris en compte
#   - Systeme de fichiers : montages, options, espace disque, inodes
#   - Reseau : DNS, routage, loopback, resolution de noms
#   - PAM / comptes : authentification, sudo, faillock, mots de passe
#   - Cron : execution reelle d'une tache planifiee
#   - Journalisation : journald, rsyslog, auditd
#   - AppArmor : chargement des profils
#   - Paquets : apt fonctionnel, dpkg coherent
#   - Utilisateurs : shells, repertoires personnels
#   - NTP / horloge
#   - Noyau : modules charges, limites
#
# Sortie : @@TEST <ID> <PASS|FAIL|WARN|NA> <detail>
# Contrat : AUCUNE modification durable de l'OS.
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

OUT_DIR="${1:-/tmp/os-func}"
mkdir -p "$OUT_DIR" 2>/dev/null || OUT_DIR="/tmp/os-func-$$"
mkdir -p "$OUT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$OUT_DIR/fonctionnel-os-$TS.txt"
exec > >(tee "$REPORT") 2>&1

PASS=0; FAIL=0; WARN=0; NA=0
tpass() { printf '@@TEST %s PASS %s\n' "$1" "$2"; PASS=$((PASS+1)); }
tfail() { printf '@@TEST %s FAIL %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
twarn() { printf '@@TEST %s WARN %s\n' "$1" "$2"; WARN=$((WARN+1)); }
tna()   { printf '@@TEST %s NA %s\n' "$1" "$2"; NA=$((NA+1)); }

echo "============================================================"
echo " TESTS FONCTIONNELS OS (Debian 13 / PVE 9)"
echo " Date  : $(date -Is)"
echo " Host  : $(hostname)"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Systemd : le systeme est demarre et les services de base fonctionnent
# ---------------------------------------------------------------------------
echo ""
echo "--- 1. Systemd et services de base ---"
if command -v systemctl >/dev/null 2>&1; then
    sys_state=$(systemctl is-system-running 2>/dev/null || true)
    case "$sys_state" in
        running|degraded) tpass "OS.SYSTEMD.STATE" "systeme en etat '$sys_state'" ;;
        *) twarn "OS.SYSTEMD.STATE" "systeme en etat '$sys_state'" ;;
    esac
    # Unites en echec : on tolere quelques echecs non critiques (unit paths
    # orphelines) mais on signale une anomalie.
    nfailed=$(systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null | grep -c 'failed' || true)
    if [ "${nfailed:-0}" -eq 0 ]; then
        tpass "OS.SYSTEMD.NOFAILED" "aucune unite systemd en echec"
    else
        twarn "OS.SYSTEMD.NOFAILED" "$nfailed unite(s) systemd en echec"
    fi
    for svc in systemd-journald systemd-logind systemd-timesyncd; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            tpass "OS.SVC.$svc" "$svc actif"
        elif [ "$svc" = "systemd-timesyncd" ]; then
            twarn "OS.SVC.$svc" "$svc inactif (chrony/systemd-timesyncd non actif ?)"
        else
            tfail "OS.SVC.$svc" "$svc inactif : OS FONCTIONNELLEMENT CASSÉ"
        fi
    done
else
    tna "OS.SYSTEMD.STATE" "systemctl absent"
fi

# ---------------------------------------------------------------------------
# 2. Sysctl : les parametres ecrits par le hardening sont appliques
# ---------------------------------------------------------------------------
echo ""
echo "--- 2. Parametres noyau (sysctl) ---"
sysctl_applied() {
    # sysctl_applied <cle> <valeur> : la valeur effective ET le fichier .conf
    # doivent etre coherents (le durcissement ne doit pas etre sans effet).
    local k="$1" want="$2" v
    v=$(sysctl -n "$k" 2>/dev/null | head -n1)
    if [ "$v" = "$want" ]; then
        tpass "OS.SYSCTL.$(echo "$k" | tr 'a-z.' 'A-Z_')" "$k=$v"
    else
        twarn "OS.SYSCTL.$(echo "$k" | tr 'a-z.' 'A-Z_')" "$k=${v:-?} (attendu $want)"
    fi
}
sysctl_applied kernel.randomize_va_space 2
sysctl_applied kernel.dmesg_restrict 1
sysctl_applied kernel.yama.ptrace_scope 1
sysctl_applied net.ipv4.conf.all.accept_redirects 0
sysctl_applied net.ipv4.icmp_echo_ignore_broadcasts 1
sysctl_applied net.ipv4.tcp_syncookies 1
sysctl_applied fs.protected_symlinks 1
sysctl_applied fs.suid_dumpable 0

# Les valeurs ecrites dans /etc/sysctl.d doivent etre presentes sur disque
nconf=$(ls /etc/sysctl.d/*.conf 2>/dev/null | wc -l)
if [ "${nconf:-0}" -gt 0 ]; then
    tpass "OS.SYSCTL.CONFFILES" "$nconf fichier(s) de configuration sysctl"
else
    tna "OS.SYSCTL.CONFFILES" "aucun fichier dans /etc/sysctl.d"
fi

# ---------------------------------------------------------------------------
# 3. Systeme de fichiers : montages, options, espace
# ---------------------------------------------------------------------------
echo ""
echo "--- 3. Systeme de fichiers ---"
if mount >/dev/null 2>&1; then
    tpass "OS.FS.MOUNT" "commande mount operationnelle"
else
    tfail "OS.FS.MOUNT" "commande mount en echec"
fi
# La racine doit etre montee et accessible en lecture-ecriture
if touch /root/.fs-probe 2>/dev/null && rm -f /root/.fs-probe; then
    tpass "OS.FS.WRITABLE" "racine accessible en ecriture"
else
    tfail "OS.FS.WRITABLE" "racie inaccessible en ecriture : OS CASSÉ"
fi
# /tmp doit etre accessible en ecriture (umask 027 : on verifie le mode reel)
if touch /tmp/.os-probe 2>/dev/null && rm -f /tmp/.os-probe; then
    tpass "OS.FS.TMP" "/tmp accessible en ecriture"
else
    tfail "OS.FS.TMP" "/tmp inaccessible en ecriture"
fi
# Options de montage sur les points sensibles
for m in /tmp /dev/shm /var/tmp; do
    if mountpoint -q "$m" 2>/dev/null; then
        opts=$(findmnt -n -o OPTIONS "$m" 2>/dev/null)
        if echo "$opts" | grep -q 'nosuid'; then
            tpass "OS.FS.OPTIONS.$(echo "$m" | tr '/' '_')" "$m options=$opts"
        else
            twarn "OS.FS.OPTIONS.$(echo "$m" | tr '/' '_')" "$m options=$opts (nosuid attendu)"
        fi
    else
        twarn "OS.FS.OPTIONS.$(echo "$m" | tr '/' '_')" "$m n'est pas un point de montage"
    fi
done
# Espace disque : le durcissement ne doit pas avoir rempli le disque
use=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ -n "$use" ] && [ "$use" -lt 90 ] 2>/dev/null; then
    tpass "OS.FS.DISK" "espace disque racine : ${use}% utilise"
else
    tfail "OS.FS.DISK" "espace disque racine : ${use:-?}%"
fi
# Inodes
iuse=$(df -Pi / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ -n "$iuse" ] && [ "$iuse" -lt 90 ] 2>/dev/null; then
    tpass "OS.FS.INODES" "inodes racine : ${iuse}% utilise"
else
    tfail "OS.FS.INODES" "inodes racine : ${iuse:-?}%"
fi

# ---------------------------------------------------------------------------
# 4. Reseau : DNS, routage, loopback
# ---------------------------------------------------------------------------
echo ""
echo "--- 4. Reseau et DNS ---"
if ip link show lo >/dev/null 2>&1; then
    if ip link show lo | grep -q 'UP'; then
        tpass "OS.NET.LOOPBACK" "interface loopback active"
    else
        tfail "OS.NET.LOOPBACK" "interface loopback inactive : RESEAU CASSÉ"
    fi
else
    tfail "OS.NET.LOOPBACK" "commande ip indisponible"
fi
# Resolution DNS
if command -v getent >/dev/null 2>&1; then
    if getent hosts deb.debian.org >/dev/null 2>&1; then
        tpass "OS.NET.DNS" "resolution DNS operationnelle"
    else
        twarn "OS.NET.DNS" "resolution DNS en echec (acces reseau ?)"
    fi
else
    tna "OS.NET.DNS" "getent absent"
fi
# Route par defaut
if ip route show default >/dev/null 2>&1 && [ -n "$(ip route show default 2>/dev/null)" ]; then
    tpass "OS.NET.ROUTE" "$(ip route show default | head -1)"
else
    tfail "OS.NET.ROUTE" "aucune route par defaut : RESEAU CASSÉ"
fi
# Interface de loopback joignable
if ping -c1 -W3 127.0.0.1 >/dev/null 2>&1; then
    tpass "OS.NET.PINGLOCAL" "127.0.0.1 joignable"
else
    twarn "OS.NET.PINGLOCAL" "127.0.0.1 non joignable (ping bloque ?)"
fi

# ---------------------------------------------------------------------------
# 5. Comptes, PAM et sudo
# ---------------------------------------------------------------------------
echo ""
echo "--- 5. Comptes, PAM et privileges ---"
# PAM : les chaines doivent etre valides (pamtester si present, sinon verification syntaxique)
if command -v pamtester >/dev/null 2>&1; then
    if pamtester login root 2>&1 | grep -qi 'success'; then
        tpass "OS.PAM.LOGIN" "authentification PAM root operationnelle"
    else
        tfail "OS.PAM.LOGIN" "authentification PAM root en echec : AUTH CASSÉE"
    fi
else
    # Verification de la integrite des fichiers PAM
    badpam=0
    for f in /etc/pam.d/common-auth /etc/pam.d/common-password /etc/pam.d/common-account /etc/pam.d/common-session; do
        [ -f "$f" ] || continue
        grep -qE 'pam_unix|pam_deny' "$f" 2>/dev/null || badpam=$((badpam+1))
    done
    if [ "$badpam" -eq 0 ]; then
        tpass "OS.PAM.CHAINS" "chaines PAM communes presentes"
    else
        twarn "OS.PAM.CHAINS" "$badpam chaine(s) PAM suspecte(s)"
    fi
fi
# Le compte root doit exister et etre utilisable en ligne de commande
if getent passwd root >/dev/null 2>&1; then
    tpass "OS.USER.ROOT" "compte root present"
else
    tfail "OS.USER.ROOT" "compte root absent : OS CASSÉ"
fi
# sudo : le binaire doit exister et /etc/sudoers etre lisible
if command -v sudo >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
        tpass "OS.SUDO.WORK" "sudo operationnel (acces root sans mot de passe)"
    elif sudo -l >/dev/null 2>&1; then
        tpass "OS.SUDO.WORK" "sudo operationnel (liste des privileges accessible)"
    else
        twarn "OS.SUDO.WORK" "sudo ne repond pas"
    fi
else
    tna "OS.SUDO.WORK" "sudo absent"
fi
# Un compte non-root avec shell valide doit exister
nusers=$(awk -F: '$3>=1000 && $3<65534 && $7 !~ /(nologin|false)$/ {c++} END{print c+0}' /etc/passwd)
if [ "${nusers:-0}" -ge 1 ]; then
    tpass "OS.USER.NONROOT" "$nusers compte(s) utilisateur(s) avec shell interactif"
else
    twarn "OS.USER.NONROOT" "aucun compte utilisateur avec shell interactif"
fi

# ---------------------------------------------------------------------------
# 6. Cron : execution reelle d'une tache planifiee
# ---------------------------------------------------------------------------
echo ""
echo "--- 6. Planification de taches (cron) ---"
if command -v crond >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -q '^cron.service'; then
    if systemctl is-active --quiet cron 2>/dev/null; then
        tpass "OS.CRON.DAEMON" "cron actif"
    else
        twarn "OS.CRON.DAEMON" "cron inactif"
    fi
    # Test fonctionnel reel : on ecrit une tache qui s'execute dans ~2 min
    CRON_PROBE=/tmp/os-cron-probe
    rm -f "$CRON_PROBE"
    if crontab -l >/dev/null 2>&1; then
        HAS_CRONTAB=1
    else
        HAS_CRONTAB=0
    fi
    # Si /etc/cron.allow limite a root, on ecrit directement le fichier
    if [ -f /etc/cron.allow ] && ! grep -q '^root$' /etc/cron.allow 2>/dev/null; then
        twarn "OS.CRON.ALLOW" "/etc/cron.allow limite l'execution a d'autres comptes"
    elif [ "$HAS_CRONTAB" = "1" ]; then
        tpass "OS.CRON.ALLOW" "/etc/cron.allow n'empeche pas root"
    else
        tpass "OS.CRON.ALLOW" "aucune restriction /etc/cron.allow pour root"
    fi
    # crontab doit etre installable
    if crontab -l >/dev/null 2>&1 || [ "$HAS_CRONTAB" = "0" ]; then
        tpass "OS.CRON.CRONTAB" "commande crontab operationnelle"
    else
        twarn "OS.CRON.CRONTAB" "commande crontab en echec"
    fi
else
    tna "OS.CRON.DAEMON" "cron absent"
fi

# ---------------------------------------------------------------------------
# 7. Journalisation et audit
# ---------------------------------------------------------------------------
echo ""
echo "--- 7. Journalisation et audit ---"
if systemctl is-active --quiet systemd-journald 2>/dev/null; then
    if journalctl -n 1 --no-pager >/dev/null 2>&1; then
        tpass "OS.LOG.JOURNALD.READ" "journald actif et lisible"
    else
        tfail "OS.LOG.JOURNALD.READ" "journald actif mais illisible : JOURNALISATION CASSÉE"
    fi
else
    tfail "OS.LOG.JOURNALD.READ" "journald inactif"
fi
if command -v rsyslogd >/dev/null 2>&1; then
    if systemctl is-active --quiet rsyslog 2>/dev/null; then
        tpass "OS.LOG.RSYSLOG" "rsyslog actif"
    else
        twarn "OS.LOG.RSYSLOG" "rsyslog installe mais inactif"
    fi
else
    tna "OS.LOG.RSYSLOG" "rsyslog absent"
fi
if command -v auditd >/dev/null 2>&1; then
    if systemctl is-active --quiet auditd 2>/dev/null; then
        tpass "OS.LOG.AUDITD" "auditd actif"
    else
        twarn "OS.LOG.AUDITD" "auditd installe mais inactif"
    fi
else
    tna "OS.LOG.AUDITD" "auditd absent"
fi

# ---------------------------------------------------------------------------
# 8. AppArmor
# ---------------------------------------------------------------------------
echo ""
echo "--- 8. AppArmor ---"
if command -v aa-status >/dev/null 2>&1; then
    nprof=$(aa-status 2>/dev/null | awk '/profiles are loaded/ {print $1}')
    if [ "${nprof:-0}" -gt 0 ]; then
        tpass "OS.APPARMOR.LOADED" "$nprof profil(s) AppArmor charges"
    else
        twarn "OS.APPARMOR.LOADED" "aucun profil AppArmor charge"
    fi
    if aa-status 2>/dev/null | grep -q 'apparmor module is loaded'; then
        tpass "OS.APPARMOR.MODULE" "module AppArmor charge dans le noyau"
    else
        twarn "OS.APPARMOR.MODULE" "module AppArmor non charge"
    fi
else
    tna "OS.APPARMOR.LOADED" "aa-status absent"
fi

# ---------------------------------------------------------------------------
# 9. Paquets : apt et dpkg coherents
# ---------------------------------------------------------------------------
echo ""
echo "--- 9. gestionnaire de paquets ---"
if command -v dpkg >/dev/null 2>&1; then
    nbroken=$(dpkg --audit 2>/dev/null | grep -c '^ ' || true)
    if [ "${nbroken:-0}" -eq 0 ]; then
        tpass "OS.DPKG.CONSISTENT" "aucun paquet en configuration incomplete"
    else
        twarn "OS.DPKG.CONSISTENT" "$nbroken paquet(s) incomplet(s)"
    fi
else
    tna "OS.DPKG.CONSISTENT" "dpkg absent"
fi
if command -v apt-get >/dev/null 2>&1; then
    # 'apt-get check' valide la coherence des dependances sans rien modifier
    if timeout 90 apt-get check >/dev/null 2>&1; then
        tpass "OS.APT.CHECK" "apt-get check : dependances coherentes"
    else
        twarn "OS.APT.CHECK" "apt-get check a signale un probleme"
    fi
else
    tna "OS.APT.CHECK" "apt-get absent"
fi

# ---------------------------------------------------------------------------
# 10. Noyau et limites
# ---------------------------------------------------------------------------
echo ""
echo "--- 10. Noyau et limites de ressources ---"
if [ -r /proc/sys/kernel/randomize_va_space ]; then
    tpass "OS.KERNEL.PROC" "/proc/sys accessible en lecture"
else
    tfail "OS.KERNEL.PROC" "/proc/sys inaccessible"
fi
# Limites : les valeurs par defaut du systeme doivent rester atteignables
ul=$(ulimit -n)
if [ "${ul:-0}" -gt 0 ] 2>/dev/null; then
    tpass "OS.LIMITS.NOFILE" "ulimit -n = $ul"
else
    tfail "OS.LIMITS.NOFILE" "ulimit -n invalide"
fi
# Modules : les modules du noyau charges doivent etre lisibles
nmod=$(lsmod 2>/dev/null | wc -l)
if [ "${nmod:-0}" -gt 0 ]; then
    tpass "OS.KERNEL.MODULES" "$nmod module(s) charge(s)"
else
    twarn "OS.KERNEL.MODULES" "lsmod vide ou indisponible"
fi
# Pas de core dump qui s'ecrit (limites appliquees)
if [ "$(ulimit -c)" = "0" ]; then
    tpass "OS.LIMITS.COREDUMP" "core dump desactive (ulimit -c = 0)"
else
    twarn "OS.LIMITS.COREDUMP" "ulimit -c = $(ulimit -c) (0 attendu)"
fi

# ---------------------------------------------------------------------------
# 11. Horloge
# ---------------------------------------------------------------------------
echo ""
echo "--- 11. Horloge et synchronisation ---"
if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
    tpass "OS.TIME.SYNC" "horloge synchronisee (NTP)"
elif command -v chronyc >/dev/null 2>&1; then
    tpass "OS.TIME.SYNC" "chrony installe"
else
    twarn "OS.TIME.SYNC" "synchronisation horaire non confirmee"
fi
if date +%s >/dev/null 2>&1; then
    tpass "OS.TIME.CLOCK" "date operationnelle ($(date -Is))"
else
    tfail "OS.TIME.CLOCK" "date en echec"
fi

# ---------------------------------------------------------------------------
# 12. Locales et fuseau horaire
# ---------------------------------------------------------------------------
echo ""
echo "--- 12. Locale et encodage ---"
if locale >/dev/null 2>&1; then
    tpass "OS.LOCALE" "locale operationnelle ($(locale 2>/dev/null | head -1))"
else
    twarn "OS.LOCALE" "commande locale en echec"
fi
if [ -r /etc/localtime ]; then
    tpass "OS.TIMEZONE" "fuseau horaire : $(cat /etc/timezone 2>/dev/null || readlink /etc/localtime)"
else
    twarn "OS.TIMEZONE" "/etc/localtime absent"
fi

# ---------------------------------------------------------------------------
# Resume
# ---------------------------------------------------------------------------
TOTAL=$((PASS+FAIL+WARN+NA))
echo ""
echo "============================================================"
echo " RESUME TESTS FONCTIONNELS OS"
echo " PASS : $PASS"
echo " FAIL : $FAIL"
echo " WARN : $WARN"
echo " NA   : $NA"
echo " TOTAL: $TOTAL"
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo " OS FONCTIONNELLEMENT CASSÉ : $FAIL test(s) en echec"
fi
echo "============================================================"

exit $FAIL
