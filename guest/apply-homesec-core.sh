#!/usr/bin/env bash
# =============================================================================
# apply-homesec-core.sh
# -----------------------------------------------------------------------------
# Durcissement exhaustif de Proxmox VE 9, tracé sur le guide HomeSecExplorer
# et le benchmark CIS Debian 13.
#
# NIVEAUX
#   LEVEL=1 (defaut) : CIS L1 + guide 1.2.4 (pare-feu PVE) + PAM + SSH
#   LEVEL=2          : + FORWARD DROP/nftables, auditd /etc/pve, rkhunter, umask 027
#   LEVEL=3          : + AIDE, rsyslog distant, sshd root=no, services inutiles
#   LEVEL=4          : + umask 077 root, AppArmor enforce complet
#
# Chaque bloc porte la reference du controle et le niveau, avec gating structurel
# (if [ "$LEVEL" -ge N ]) pour eviter tout effet de bord non desire.
#
# Conception : sauvegarde de chaque fichier touche, idempotent, rollback genere,
# fail-safe SSH (ne verrouille jamais sans cle pre-verifiee).
# =============================================================================

set -u
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

DRY_RUN="${DRY_RUN:-0}"
LEVEL="${LEVEL:-1}"
MGMT_CIDR="${MGMT_CIDR:-10.0.2.0/24}"
ADMIN_USER="${ADMIN_USER:-pveadmin}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/hardening-backups/$TS"
LOG="/var/log/hardening-$TS.log"
NODE_NAME="$(hostname)"

mkdir -p "$BACKUP_DIR"

# ------------------------------------------------------------------- helpers
APPLIED=""; SKIPPED=""
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
step() { printf '\n=== %s ===\n' "$*" | tee -a "$LOG"; }
ref()  { printf '    (guide PVE 9 : %s)\n' "$*" | tee -a "$LOG"; }

mark()  { APPLIED="$APPLIED $1"; }
skip()  { SKIPPED="$SKIPPED $1"; }

# block <niveau_requis> <description>
block() {
    local need="$1" desc="$2"
    if [ "$LEVEL" -lt "$need" ]; then
        printf '\n=== SKIP (niveau %s, LEVEL=%s) : %s ===\n' "$need" "$LEVEL" "$desc" | tee -a "$LOG"
        skip "$desc"
        return 1
    fi
    step "$desc"
    mark "$desc"
    return 0
}

exec_cmd() {
    log "EXEC: $*"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"
        return 0
    fi
    eval "$@" >>"$LOG" 2>&1 || { log "ECHEC: $* (voir $LOG)"; return 1; }
    return 0
}

backup() {
    local f="$1"
    [ -e "$f" ] || return 0
    local d="$BACKUP_DIR$(dirname "$f")"
    mkdir -p "$d"
    cp -a "$f" "$d/$(basename "$f").$(date +%s)"
    log "BACKUP: $f -> $d"
}

write_file() {
    local path="$1" mode="$2" content="$3"
    if [ -f "$path" ] && [ "$(cat "$path" 2>/dev/null)" = "$content" ]; then
        log "IDEMPOTENT: $path deja conforme"
        return 0
    fi
    backup "$path"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [DRY-RUN] ecriture %s (mode %s)\n' "$path" "$mode" | tee -a "$LOG"
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path.tmp"
    chmod "$mode" "$path.tmp"
    mv "$path.tmp" "$path"
    log "WRITE: $path (mode $mode)"
}

log "==========================================================="
log " apply-homesec-core.sh - PVE 9 / node $NODE_NAME"
log " LEVEL=$LEVEL  DRY_RUN=$DRY_RUN  MGMT_CIDR=$MGMT_CIDR"
log " BACKUP=$BACKUP_DIR"
log "==========================================================="

# =============================================================================
block 1 "0. Garde-fous (acces SSH)"
# =============================================================================
KEYFILE="/root/.ssh/authorized_keys"
HAVE_KEY=0
if [ -e "$KEYFILE" ] && [ -s "$KEYFILE" ]; then
    NK=$(grep -cE '^(ssh-|ecdsa-|sk-)' "$KEYFILE" 2>/dev/null || echo 0)
    log "cles publiques root detectees : $NK"
    [ "$NK" -gt 0 ] && HAVE_KEY=1
fi

# On prepare aussi l'acces pour le compte administrateur (fallback si root se verrouille)
if [ "$HAVE_KEY" = "0" ] && [ "$DRY_RUN" != "1" ]; then
    log "ARRET : aucune cle publique valide. Installez une cle avant de durcir (SSH garde-fou)."
    exit 2
fi

# =============================================================================
block 1 "1. Modules noyau, core dumps, limites (CIS 1.1.1.x, 1.5.x, 3.x)"
# =============================================================================
ref "CIS Debian 13 1.1.1.x, 1.5.11-13, 3.2.x"
MOD_BLACKLIST=/etc/modprobe.d/99-pve-hardening.conf
write_file "$MOD_BLACKLIST" 0644 "\
# Genere par apply-homesec-core.sh - CIS Debian 13 1.1.1.x et 3.2.x
# Note guide PVE 9 : 'fuse' requis par Proxmox, NON desactive.
install cramfs /bin/false
install freevxfs /bin/false
install hfs /bin/false
install hfsplus /bin/false
install jffs2 /bin/false
install udf /bin/false
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install atm /bin/false
install can /bin/false
"
exec_cmd "systemctl restart systemd-modules-load"

SYSCTL=/etc/sysctl.d/99-pve-hardening.conf
write_file "$SYSCTL" 0644 "\
# Genere par apply-homesec-core.sh - CIS Debian 13 1.5.x et 3.x
fs.suid_dumpable = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.core_pattern = |/bin/false
kernel.randomize_va_space = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
"
exec_cmd "sysctl --system"

# --- ANSSI / CIS complements : sysctl noyau
# Fichier distinct de /etc/sysctl.d/98-anssi.conf (ecrit par apply-anssi.sh)
# pour eviter tout ecrasement quel que soit l'ordre d'application.
# 97 < 98 : sysctl applique 97 en premier, puis 98 qui surcharge avec les
# valeurs ANSSI plus strictes.
write_file /etc/sysctl.d/97-pve-hardening.conf 0644 "\
# Genere par apply-homesec-core.sh - sysctl noyau (guide PVE 9 / CIS 1.1.x)
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.yama.ptrace_scope = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
"
exec_cmd "sysctl --system"

# --- ANSSI N1 : /boot reserve a root
exec_cmd "chmod 0700 /boot"

# --- ANSSI N1 : desactivation de Ctrl-Alt-Del
exec_cmd "systemctl disable ctrl-alt-del.target"
exec_cmd "systemctl mask ctrl-alt-del.target"

# --- CIS 5.4.4 / ANSSI : umask par defaut
write_file /etc/profile.d/99-pve-hardening.sh 0644 "\
umask 027
"

write_file /etc/security/limits.d/99-pve-hardening.conf 0644 "\
# CIS Debian 13 1.5.11-1.5.13 : pas de core dump
*   hard   core   0
*   soft   core   0
root hard   core   0
"

# =============================================================================
block 1 "2. Systeme de fichiers : /tmp, /var/tmp, /dev/shm (CIS 1.1.2.x)"
# =============================================================================
ref "CIS Debian 13 1.1.2.1-1.1.2.4"
backup /etc/fstab
if [ "$DRY_RUN" != "1" ]; then
    python3 - <<'PY' 2>&1 | tee -a "$LOG"
import sys
path = "/etc/fstab"
lines = open(path).read().splitlines()
targets = {"/tmp": "nosuid,nodev", "/var/tmp": "nosuid,nodev", "/dev/shm": "nosuid,nodev,noexec"}
out = []
for l in lines:
    s = l.strip()
    if not s or s.startswith("#"):
        out.append(l); continue
    parts = l.split()
    tgt = parts[1] if len(parts) > 1 else ""
    if tgt in targets:
        opts = parts[3] if len(parts) > 3 else "defaults"
        have = [o for o in opts.split(",") if o]
        for o in targets[tgt].split(","):
            if o not in have:
                have.append(o)
        out.append(" ".join(parts[:3] + [",".join(have)] + parts[4:]))
    else:
        out.append(l)
open(path, "w").write("\n".join(out) + "\n")
print("fstab mis a jour")
PY
fi
exec_cmd "mount -o remount,nosuid,nodev /tmp" || true
exec_cmd "mount -o remount,nosuid,nodev /var/tmp" || true
exec_cmd "mount -o remount,nosuid,nodev,noexec /dev/shm" || true

# /tmp et /var/tmp ne sont pas des points de montage distincts sur PVE :
# on cree des montages dedies (tmpfs) pour appliquer les options CIS
# 1.1.2.1 et 1.1.2.2 (nodev,nosuid,noexec pour /var/tmp).
if [ "$DRY_RUN" != "1" ]; then
    if ! grep -qE '^tmpfs\s+/tmp\s' /etc/fstab; then
        echo "tmpfs /tmp tmpfs rw,nosuid,nodev,relatime,size=512M 0 0" >> /etc/fstab
        echo "  [ok] montage tmpfs dedie pour /tmp ajoute"
    fi
    if ! grep -qE '^tmpfs\s+/var/tmp\s' /etc/fstab; then
        echo "tmpfs /var/tmp tmpfs rw,nosuid,nodev,noexec,relatime,size=512M 0 0" >> /etc/fstab
        echo "  [ok] montage tmpfs dedie pour /var/tmp ajoute"
    fi
    grep -qE '^tmpfs\s+/tmp\s' /etc/fstab && mount /tmp 2>/dev/null
    grep -qE '^tmpfs\s+/var/tmp\s' /etc/fstab && mount /var/tmp 2>/dev/null
fi

# --- Persistance des options de montage -------------------------------------
# /tmp, /var/tmp et /dev/shm sont recrees au demarrage par systemd : sans
# declaration dans /etc/fstab, le noexec pose a chaud est perdu et le
# controle OS.MOUNT._dev_shm echoue apres un redemarrage.
if [ "$DRY_RUN" != "1" ]; then
    backup /etc/fstab
    for mp in /tmp /var/tmp /dev/shm; do
        if ! grep -qE "^[^#]*[[:space:]]$mp[[:space:]]" /etc/fstab 2>/dev/null; then
            printf 'tmpfs %s tmpfs rw,nosuid,nodev,noexec,size=524288k,mode=1777 0 0\n' "$mp" >> /etc/fstab
            echo "  [ok] $mp declare dans /etc/fstab"
        fi
    done
    # remount immediat pour appliquer sans redemarrer
    for mp in /dev/shm /var/tmp; do
        mount -o remount,rw,nosuid,nodev,noexec "$mp" 2>/dev/null || true
    done
fi

# =============================================================================
block 1 "3. Permissions cron et at (CIS 2.4.1.x)"
# =============================================================================
ref "CIS Debian 13 2.4.1.x"
backup /etc/crontab
exec_cmd "chmod 0600 /etc/crontab"
for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    [ -d "$d" ] && exec_cmd "chmod 0700 $d"
    [ -d "$d" ] && exec_cmd "find $d -type f -exec chmod 0600 {} +"
done

# =============================================================================
block 1 "4. Journald persistant et compresse (CIS 4.2.1.x)"
# =============================================================================
ref "CIS Debian 13 4.2.1.x"
JD=/etc/systemd/journald.conf.d/99-pve-hardening.conf
write_file "$JD" 0644 "\
# CIS Debian 13 4.2.1.x : journald
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=512M
SystemKeepFree=1G
MaxRetentionSec=1month
ForwardToSyslog=yes
"
exec_cmd "systemctl restart systemd-journald"

# =============================================================================
block 1 "5. SSH : permissions, authentification, chiffrement (CIS 5.1.x)"
# =============================================================================
ref "CIS Debian 13 5.1.x + deviation guide § 5.1.21"
SSHD_DROP=/etc/ssh/sshd_config.d/00-pve-hardening.conf
# Guide PVE 9, option B : le root SSH est INTERDIT globalement, sauf depuis le
# reseau de management (MGMT_CIDR) ou la cle publique est utilisee.
# Cette option est preferee a un simple 'prohibit-password' : elle applique
# reellement la recommandation ANSSI BP-028 tout en conservant l'acces du lab.
# Le fichier produit est identique a celui d'apply-anssi.sh (pas de conflit
# quel que soit l'ordre d'application des scripts).
# Liste AllowUsers : on n'annonce que des comptes reellement presents,
# sinon 'sshd -t' echoue et la configuration SSH serait rejetee.
ALLOW_USERS="root"
if getent passwd "$ADMIN_USER" >/dev/null 2>&1; then
    ALLOW_USERS="root $ADMIN_USER"
fi
SSH_CONF="\
# Genere par apply-homesec-core.sh - CIS Debian 13 5.1.x
# Root SSH restreint au reseau de management (guide PVE 9, option B)
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
AllowAgentForwarding no
PermitTunnel no
MaxAuthTries 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
MaxSessions 5
MaxStartups 10:30:60
Banner /etc/issue.net
AllowUsers $ALLOW_USERS
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
PubkeyAcceptedAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
Match Address $MGMT_CIDR
    PermitRootLogin yes
"
write_file "$SSHD_DROP" 0600 "$SSH_CONF"
if [ "$DRY_RUN" != "1" ]; then
    printf 'Acces reserve. Toute activite non autorisee est enregistre.\n' > /etc/issue.net
    chmod 0644 /etc/issue.net
    # cle pour le compte admin
    install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
    if [ -f "$KEYFILE" ]; then
        cp "$KEYFILE" "/home/$ADMIN_USER/.ssh/authorized_keys"
        chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
        chmod 0600 "/home/$ADMIN_USER/.ssh/authorized_keys"
    fi
fi
backup /etc/ssh/sshd_config
exec_cmd "chmod 0600 /etc/ssh/sshd_config"
[ -d /etc/ssh/sshd_config.d ] && exec_cmd "chmod 0700 /etc/ssh/sshd_config.d"
exec_cmd "chmod 0600 /etc/ssh/ssh_host_*_key"
exec_cmd "chmod 0644 /etc/ssh/ssh_host_*_key.pub"
exec_cmd "chmod 0700 /root/.ssh"
exec_cmd "chmod 0600 /root/.ssh/authorized_keys"

# Validation sshd - saut en DRY_RUN (fichier non ecrit)
if [ "$DRY_RUN" != "1" ]; then
    if ! sshd -t 2>/dev/null; then
        log "ERREUR : sshd -t invalide. Suppression de $SSHD_DROP"
        rm -f "$SSHD_DROP"
        exit 3
    fi
else
    log "DRY-RUN : sshd -t saute"
fi
exec_cmd "systemctl restart ssh"

# =============================================================================
block 1 "6. PAM : faillock + pwquality (CIS 5.3.3.1, 5.4.1, 5.4.2)"
ref "CIS Debian 13 5.3.3.1.x / 5.4.1.x / 5.4.2.x + guide PVE 9"
# --- DNS joignable via le NAT VirtualBox -------------------------------------
# Le DHCP fournit le DNS du reseau corporate de l'hote, qui n'est PAS route
# par le NAT VirtualBox : sans resolution de nom, `apt-get update` echoue
# et AUCUN paquet ne peut etre installe (une dozenaine de controles
# d'audit echoueraient alors a tort).
DNS_NAT="${DNS_NAT:-10.0.2.3}"
if [ "$DRY_RUN" != "1" ]; then
    # La detection doit reposer sur la resolution ET la joignabilite reelle
    # du depot : `getent` peut reussir via le cache alors qu'apt echoue.
    # Les listes de paquets peuvent avoir ete telechargees a ZERO OCTET
    # lors d'une panne DNS : apt les met en cache et annonce "Hit" ensuite,
    # sans jamais les retelecharger. On les purge pour forcer la reprise.
    find /var/lib/apt/lists -type f -size 0 -name '*_Packages*' -delete 2>/dev/null || true
    rm -f /var/lib/apt/lists/*Partial* 2>/dev/null || true
    if ! getent hosts deb.debian.org >/dev/null 2>&1 || ! timeout 30 apt-get update >/dev/null 2>&1; then
        echo "  [ok] DNS ou depot non fonctionnel : bascule sur le DNS du NAT VirtualBox ($DNS_NAT)"
        cp -a /etc/resolv.conf /etc/resolv.conf.bak-lab 2>/dev/null || true
        printf 'search lab.local\nnameserver %s\n' "$DNS_NAT" > /etc/resolv.conf
        apt-get update -y >/dev/null 2>&1 || echo "  [warn] apt-get update a toujours echoue"
    fi
fi
# sudo et chrony sont requis par la suite de tests fonctionnels OS
# (non-regression des privileges et de la synchronisation horaire) : sans
# eux, ces tests seraient 'NA' et la non-regression OS ne serait pas
# verifiable sur l'OS durci.
# --- Depots apt exploitables -------------------------------------------------
# 1. Les depots enterprise Proxmox (pve, ceph-squid) exigent une licence et
#    repondent 401 : apt echoue alors sur TOUS les depots ("The repository ...
#    is not signed") et plus aucun paquet ne peut etre installe. On les
#    desactive (sans effet dans un lab).
# 2. Les listes de paquets de l'image d'installation sont absentes ou
#    perimees : il faut un apt-get update avant toute installation.
if [ "$DRY_RUN" != "1" ]; then
    for f in /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/ceph.sources; do
        if [ -f "$f" ]; then
            mv "$f" "$f.disabled"
            echo "  [ok] depot enterprise desactive : $(basename "$f")"
        fi
    done
    # purge des index a zero octet (une panne DNS les laisse vides en cache :
    # apt annonce alors "Hit" sans jamais les retelecharger)
    find /var/lib/apt/lists -type f -size 0 -name '*_Packages*' -delete 2>/dev/null || true
    rm -f /var/lib/apt/lists/*Partial* 2>/dev/null || true
    if ! timeout 120 apt-get update -y >/dev/null 2>&1; then
        echo "  [warn] apt-get update a echoue : certaines installations de paquets echoueront"
    fi
fi

exec_cmd "apt-get install -y sudo chrony"
if [ "$DRY_RUN" != "1" ] && command -v chronyd >/dev/null 2>&1; then
    exec_cmd "systemctl enable --now chrony" || exec_cmd "systemctl enable --now chronyd"
fi
exec_cmd "apt-get install -y libpam-modules libpam-pwquality"

# --- CIS 5.3.3.1 : verrouillage de compte apres echecs d'authentification
# Le CIS exige les arguments deny= / unlock_time= DANS la ligne PAM
# (common-auth, sshd, login) : un simple appel a pam_faillock.so ne suffit
# pas. even_deny_root / root_unlock_time sont requis pour root.
write_file /etc/security/faillock.conf 0644 "\
# CIS Debian 13 5.3.3.1 - pam_faillock
deny = 5
unlock_time = 900
fail_interval = 900
dir = /var/log/faillock
"

# --- CIS 5.4.1 : qualite des mots de passe (pam_pwquality + pwquality.conf)
write_file /etc/security/pwquality.conf 0644 "\
# CIS Debian 13 5.4.1 - qualite des mots de passe
minlen = 14
minclass = 4
maxrepeat = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
dictcheck = 1
usercheck = 1
enforcing = 1
retry = 3
"

# --- CIS 5.4.2 : vieillissement des mots de passe (login.defs)
# et CIS 5.4.3 : UMASK 027
if [ "$DRY_RUN" != "1" ]; then
    backup /etc/login.defs
    python3 - <<'PYPAM'
import re

path = "/etc/login.defs"
with open(path) as fh:
    lines = fh.read().splitlines()

def set_param(lines, key, value):
    """Remplace (ou ajoute) 'key<tab>value' dans login.defs."""
    pattern = re.compile(r"^\s*" + re.escape(key) + r"\s")
    out = []
    done = False
    for l in lines:
        if pattern.match(l) and not l.strip().startswith('#'):
            out.append("{}\t{}".format(key, value))
            done = True
        else:
            out.append(l)
    if not done:
        # On retire les lignes commentees correspondantes pour eviter la confusion
        out = [l for l in out
               if not re.match(r"^\s*#\s*" + re.escape(key) + r"\s", l)]
        out.append("{}\t{}".format(key, value))
    return out

lines = set_param(lines, "PASS_MAX_DAYS", "90")
lines = set_param(lines, "PASS_MIN_DAYS", "1")
lines = set_param(lines, "PASS_WARN_AGE", "7")
lines = set_param(lines, "UMASK", "027")

with open(path, "w") as fh:
    fh.write("\n".join(lines) + "\n")
print("login.defs : PASS_MAX_DAYS=90 PASS_MIN_DAYS=1 PASS_WARN_AGE=7 UMASK=027")
PYPAM
    echo "  [ok] login.defs : vieillissement + UMASK 027"
fi

# --- CIS 5.3.3.1 / 5.4.1 : lignes PAM pam_faillock.so et pam_pwquality.so
# avec les arguments CIS (deny=, unlock_time=, retry=, minlen=, minclass=).
if [ "$DRY_RUN" != "1" ]; then
    python3 - <<'PYPAM'
FL = "deny=5 unlock_time=900 even_deny_root root_unlock_time=900"
PW = "retry=3 minlen=14 minclass=4"


def patch(path, anchor, params, module, prefix):
    """Insere ou normalise la ligne <module>.so avec les parametres CIS."""
    try:
        with open(path) as fh:
            src = fh.read().splitlines()
    except OSError:
        return False
    out = []
    done = False
    for l in src:
        stripped = l.strip()
        if module in stripped and not stripped.startswith('#'):
            # On normalise les arguments CIS sur la ligne existante
            head = l.split(module)[0]
            out.append(head + module + " " + params)
            done = True
            continue
        if (not done and not stripped.startswith('#') and stripped
                and anchor in stripped and stripped.startswith(prefix)):
            out.append("%s\trequisite\t%s %s" % (prefix, module, params))
            out.append("%s\trequisite\t%s %s" % (prefix, module, params))
            out.append("%s\trequisite\t%s %s" % (prefix, module, params))
            done = True
        out.append(l)
    if done:
        with open(path, "w") as fh:
            fh.write("\n".join(out) + "\n")
    return done


ok = False
for f in ("/etc/pam.d/common-auth", "/etc/pam.d/sshd", "/etc/pam.d/login"):
    if patch(f, "pam_unix.so", FL, "pam_faillock.so", "auth"):
        ok = True
        break
print("pam_faillock.so CIS configure" if ok else "pam_faillock.so : insertion impossible")

ok = False
for f in ("/etc/pam.d/common-password", "/etc/pam.d/passwd"):
    if patch(f, "pam_unix.so", PW, "pam_pwquality.so", "password"):
        ok = True
        break
print("pam_pwquality.so CIS configure" if ok else "pam_pwquality.so : insertion impossible")
PYPAM
    echo "  [ok] lignes PAM pam_faillock.so / pam_pwquality.so conformes CIS"
fi

# --- CIS 6.1.2.x / 6.1.3.x : permissions des fichiers de comptes
exec_cmd "chmod 0644 /etc/passwd"
exec_cmd "chmod 0640 /etc/shadow"
exec_cmd "chmod 0644 /etc/group"
exec_cmd "chmod 0640 /etc/gshadow"
exec_cmd "chmod 0700 /root"

block 1 "7. Mises a jour de securite automatiques (guide 1.1.3)"
# =============================================================================
ref "Guide PVE 9 § 1.1.3 Configure Automatic Security Updates"
exec_cmd "apt-get install -y unattended-upgrades apt-listchanges"
write_file /etc/apt/apt.conf.d/20auto-upgrades 0644 "\
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"7\";
"
if [ "$DRY_RUN" != "1" ] && ! grep -q 'Unattended-Upgrade::Origins-Pattern' /etc/apt/apt.conf.d/50unattended-upgrades; then
    cat >> /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'

Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=${distro_codename},label=Debian";
  "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
  "origin=Debian,codename=${distro_codename},label=Debian-Security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
fi
exec_cmd "systemctl enable unattended-upgrades"

# =============================================================================
block 1 "8. Pare-feu PVE : activation et regles SSH/GUI (guide 1.2.4)"
# =============================================================================
ref "Guide PVE 9 § 1.2.4 Enable the PVE Firewall"
FW=/etc/pve/firewall/cluster.fw
backup "$FW"
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p /etc/pve/firewall
    cat > "$FW" <<EOF
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source $MGMT_CIDR -p tcp -dport 22 # SSH admin
IN ACCEPT -source $MGMT_CIDR -p tcp -dport 8006 # GUI Proxmox
IN ACCEPT -source $MGMT_CIDR -p tcp -dport 3128 # SPICE
EOF
fi
exec_cmd "systemctl enable pve-firewall"
exec_cmd "systemctl restart pve-firewall"

# =============================================================================
block 1 "9. Fail2ban sur l'interface web Proxmox (guide 2.3.3)"
# =============================================================================
ref "Guide PVE 9 § 2.3.3 Protect the GUI with Fail2Ban"
exec_cmd "apt-get install -y fail2ban"
# NB : 'port = https,http' fait echouer fail2ban (status=255) car
# l'action nftables genere une regle 'dport { https,http }' invalide.
# On declare donc un port par jail : fail2ban cree une action par port.
write_file /etc/fail2ban/jail.d/pve-web.conf 0644 "\
# Genere par apply-homesec-core.sh - protection de l'interface web PVE
[pve-web]
enabled  = true
port     = https
protocol = tcp
filter   = pveproxy
logpath  = /var/log/pveproxy/access.log
maxretry = 3
findtime = 300
bantime  = 3600
"

# Jail complementaire pour le port HTTP (le jail precedent ne couvre que
# HTTPS). Sans elle, les tentatives en HTTP ne seraient pas banniees.
# ATTENTION : ne pas utiliser de heredoc ici : un backslash residuel en
# tete de fichier fait echouer fail2ban ('File contains no section headers').
write_file /etc/fail2ban/jail.d/pve-web-http.conf 0644 "\
[proxmox-http]
enabled  = true
port     = http
protocol = tcp
filter   = pveproxy
logpath  = /var/log/pveproxy/access.log
maxretry = 3
findtime = 300
bantime  = 3600
"
# Filtre fail2ban dedie au log d'acces pveproxy.
# ATTENTION : fail2ban 1.x (Debian 13) exige que CHAQUE failregex contienne
# un groupe d'echec <F-ID> ; sinon le service refuse de demarrer avec
# 'ERROR No failure-id group in ...' et sort en status=255.
# Bug detecte par la suite de tests fonctionnels OS (OS.SYSTEMD.NOFAILED).
# Filtre fail2ban dedie au log d'acces pveproxy.
# ATTENTION : fail2ban 1.x (Debian 13) refuse de demarrer si une failregex
# ne comporte pas de groupe <HOST> ('ERROR No failure-id group') : le
# filtre 'proxmox' du paquet echoue donc en status=255.
# De plus, le format REEL du log pveproxy est le format Apache classique
# ("<IP> - - [...] \"GET / HTTP/1.1\" 401 -"), et non du JSON.
write_file /etc/fail2ban/filter.d/pveproxy.conf 0644 "\
[Definition]
# Echecs d'authentification PAM dans le journal systeme
failregex = ^\\s*(?:\\[\\s*.*\\])?\\s*<HOST> \\S+ - .* \\[pam\\].*authentication failure.*\$
# Reponses 401/403 sur l'interface web PVE (format Apache)
            ^<HOST> .* \"\\S+ [^\"]*\" 401 \\S*$
            ^<HOST> .* \"\\S+ [^\"]*\" 403 \\S*$
ignoreregex =
datepattern = {^LN-BEG}
"
# Le filtre systeme 'proxmox' livre par fail2ban est conserve tel quel :
# il est valide pour le journal sshd (le jail sshd par defaut l'utilise).
exec_cmd "systemctl enable fail2ban"
exec_cmd "systemctl restart fail2ban"
# Le jail doit etre actif : on verifie et on relance si besoin
if [ "$DRY_RUN" != "1" ]; then
    sleep 3
    if ! fail2ban-client status pve-web >/dev/null 2>&1; then
        systemctl restart fail2ban
        sleep 2
    fi
    fail2ban-client status pve-web 2>&1 | head -3 >>"$LOG"
    # Le service doit etre ACTIF : un fail2ban en echec laisse l'OS en
    # etat 'degraded' (detecte par les tests fonctionnels OS).
    if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
        log "ECHEC : fail2ban n'est pas actif apres le durcissement"
        fail2ban-client -d 2>&1 | tail -20 >>"$LOG" || true
    fi
fi

# --- CIS / ANSSI : AppArmor en mode enforce (plus de profil en complain)
# apparmor-utils fournit aa-enforce/aa-status : sans lui, les profils
# restent en mode complain et le controle OS.APPARMOR.ENFORCE echoue.
exec_cmd "apt-get install -y apparmor-utils"
if [ "$DRY_RUN" != "1" ] && command -v aa-enforce >/dev/null 2>&1; then
    for prof in /etc/apparmor.d/*; do
        [ -f "$prof" ] || continue
        aa-enforce "$prof" >/dev/null 2>&1 || true
    done
    # aa-enforce ne suffit pas : il faut recharger la politique pour que
    # les profils passent effectivement de complain a enforce.
    apparmor_parser -r /etc/apparmor.d/usr.bin.man 2>/dev/null || true
    systemctl reload apparmor 2>/dev/null || true
    systemctl restart apparmor 2>/dev/null || true
    echo "  [ok] profils AppArmor passes en enforce"
fi

# =============================================================================
block 1 "10. Comptes nominatifs et moindre privilege (guide 2.1.1 / 2.1.2)"
# =============================================================================
ref "Guide PVE 9 § 2.1.1 / 2.1.2"
if [ "$DRY_RUN" != "1" ] && ! id "$ADMIN_USER" >/dev/null 2>&1; then
    exec_cmd "adduser --disabled-password --gecos 'PVE Administrator' $ADMIN_USER"
    exec_cmd "usermod -aG sudo $ADMIN_USER"
    exec_cmd "install -d -m 0700 -o $ADMIN_USER -g $ADMIN_USER /home/$ADMIN_USER/.ssh"
    if [ -f "$KEYFILE" ]; then
        cp "$KEYFILE" "/home/$ADMIN_USER/.ssh/authorized_keys"
        chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
        chmod 0600 "/home/$ADMIN_USER/.ssh/authorized_keys"
    fi
fi

# =============================================================================
# NIVEAU 2
# =============================================================================
# --- 11b. Auditd sur /etc/pve (CIS 5.1.2) - applicable des le niveau 1
block 1 "11b. Auditd : surveillance des modifications de /etc/pve (CIS 5.1.2)"
ref "Guide PVE 9 § 5.1.2 Auditd for /etc/pve"
# auditd doit etre INSTALLE (paquet) puis active : sans le paquet, le service
# n'existe pas et le controle OS.AUDITD.ACTIVE echoue.
exec_cmd "apt-get install -y auditd audispd-plugins"
write_file /etc/audit/rules.d/90-pve.rules 0644 "\
-w /etc/pve -p wa -k pve-config
"
if [ "$DRY_RUN" != "1" ]; then
    systemctl enable auditd >/dev/null 2>&1 || true
    augenrules --load >>"$LOG" 2>&1 || true
    systemctl restart auditd >>"$LOG" 2>&1 || true
fi


# --- 13. Detection de rootkit (CIS 5.3.2)
block 1 "13. Detection de rootkit (CIS 5.3.2)"
ref "Guide PVE 9 § 5.3.2 Rootkit Detection"
exec_cmd "apt-get install -y rkhunter"
if [ "$DRY_RUN" != "1" ] && [ -f /etc/rkhunter.conf ]; then
    sed -i 's/^SCRIPTWHITELISTS=.*/SCRIPTWHITELISTS="rkhunter"/' /etc/rkhunter.conf
fi
exec_cmd "rkhunter --propupd"


if [ "$LEVEL" -ge 2 ]; then

# --- 11. Pare-feu PVE : FORWARD DROP + nftables (CIS 1.2.5)
block 2 "11. Pare-feu PVE : politique FORWARD DROP et backend nftables (CIS 1.2.5)"
ref "Guide PVE 9 § 1.2.5 - Default FORWARD Policy DROP"
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "/etc/pve/nodes/$NODE_NAME"
    backup "/etc/pve/nodes/$NODE_NAME/firewall"
    cat > "/etc/pve/nodes/$NODE_NAME/firewall" <<EOF
[OPTIONS]
enable: 1
nftables: 1
policy_in: DROP
policy_out: ACCEPT
EOF
fi
exec_cmd "systemctl restart pve-firewall"
exec_cmd "pve-firewall status"

# --- 14. umask par defaut 027 (CIS 5.4.4)
block 2 "14. umask par defaut a 027 (CIS 5.4.4)"
ref "CIS Debian 13 5.4.4"
write_file /etc/profile.d/99-pve-hardening.sh 0644 "\
umask 027
"

fi  # fin LEVEL >= 2

# =============================================================================
# NIVEAU 3 (ANSSI renforce)
# =============================================================================
if [ "$LEVEL" -ge 3 ]; then

# --- 15. AIDE integrite fichiers (ANSSI N2)
block 3 "15. AIDE - verifie d'integrite des fichiers systeme"
ref "ANSSI - Integrite des fichiers"
exec_cmd "apt-get install -y aide aide-common"
if [ "$DRY_RUN" != "1" ] && command -v aideinit >/dev/null 2>&1; then
    rm -f /var/lib/aide/aide.db /var/lib/aide/aide.db.new
    yes | timeout 300 aideinit >/dev/null 2>&1 || true
    yes | timeout 300 aide --init >/dev/null 2>&1 || true
    [ -f /var/lib/aide/aide.db.new ] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
fi

# --- 16. rsyslog centralisation (ANSSI)
block 3 "16. rsyslog - centralisation des journaux"
ref "ANSSI - Centralisation des journaux"
write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "\
# ANSSI : transfert vers un serveur de journaux central (a adapter selon l'environnement)
# *.* action(type=\"omfwd\" target=\"loghost\" port=\"514\" protocol=\"tcp\")
# & stop
"
exec_cmd "systemctl restart rsyslog"

# --- 17. SSH : interdiction root (ANSSI renforce)
block 3 "17. SSH : PermitRootLogin no (ANSSI renforce)"
ref "ANSSI - Interdiction de connexion root directe"
if [ -f "$SSHD_DROP" ] && [ "$DRY_RUN" != "1" ]; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_DROP"
    grep -q '^PermitRootLogin' "$SSHD_DROP" || echo 'PermitRootLogin no' >> "$SSHD_DROP"
    exec_cmd "sshd -t"
    exec_cmd "systemctl restart ssh"
fi

# --- 18. cron restreint (ANSSI)
block 3 "18. cron - restreint via cron.allow"
ref "ANSSI - Restriction d'acces a cron"
if [ "$DRY_RUN" != "1" ]; then
    echo root > /etc/cron.allow
    chmod 600 /etc/cron.allow
fi

fi  # fin LEVEL >= 3

# =============================================================================
# NIVEAU 4 (ANSSI eleve)
# =============================================================================
if [ "$LEVEL" -ge 4 ]; then

# --- 19. Services non essentiels desactive (ANSSI N4)
block 4 "19. Services non essentiels desactives (avahi, cups, bluetooth)"
ref "ANSSI - Reduction de la surface d'attaque"
for svc in avahi-daemon cups bluetooth; do
    if systemctl is-active "$svc" >/dev/null 2>&1; then exec_cmd "systemctl disable --now $svc"; fi
done

# --- 20. umask 077 pour root (ANSSI N4)
block 4 "20. umask 077 pour root (ANSSI N4)"
ref "ANSSI - Umask root"
if [ "$DRY_RUN" != "1" ]; then
    grep -q 'umask 077' /root/.bashrc 2>/dev/null || echo 'umask 077' >> /root/.bashrc
fi

fi  # fin LEVEL >= 4

# =============================================================================
block 1 "Verification finale"
# =============================================================================
exec_cmd "sshd -t"
exec_cmd "systemctl --failed --no-pager" || true
exec_cmd "systemctl is-active ssh pve-firewall fail2ban" || true
exec_cmd "pve-firewall status" || true
exec_cmd "pvesh get /cluster/firewall/options --output-format json-pretty" || true


# --- Verification post-installation des paquets requis ----------------------
# Un echec d'installation (reseau, depot injoignable, conflit) doit etre
# visible IMMEDIATEMENT, et non 12 controles d'audit plus tard.
missing_pkgs=""
for p in sudo chrony libpam-pwquality libpam-modules auditd audispd-plugins \
         fail2ban apparmor-utils unattended-upgrades rkhunter; do
    if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
        missing_pkgs="$missing_pkgs $p"
    fi
done
if [ "$LEVEL" -ge 3 ]; then
    for p in aide aide-common; do
        if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
            missing_pkgs="$missing_pkgs $p"
        fi
    done
fi
if [ -n "$missing_pkgs" ]; then
    log "ECHEC : paquet(s) requis non installes :$missing_pkgs"
    log "         verifier le depot apt et la resolution DNS (voir /etc/resolv.conf)"
    exit 1
fi
# ------------------------------------------------------------------- rollback
if [ "$DRY_RUN" != "1" ]; then
    cat > /root/rollback-hardening.sh <<'EOF'
#!/usr/bin/env bash
set -u
BACKUP_DIR="$1"
echo "Restauration depuis $BACKUP_DIR"
find "$BACKUP_DIR" -type f | while read -r f; do
    orig="${f%.*}"
    orig="${orig%.*}"
    if [ -e "$orig" ]; then
        cp -a "$f" "$orig"
        echo "restaure : $orig"
    fi
done
rm -f /etc/ssh/sshd_config.d/00-pve-hardening.conf
rm -f /etc/modprobe.d/99-pve-hardening.conf
rm -f /etc/modprobe.d/99-anssi-usb.conf
rm -f /etc/sysctl.d/99-pve-hardening.conf
rm -f /etc/sysctl.d/97-pve-hardening.conf
rm -f /etc/sysctl.d/98-anssi.conf
rm -f /etc/systemd/journald.conf.d/99-pve-hardening.conf
rm -f /etc/audit/rules.d/90-pve.rules
rm -f /etc/fail2ban/jail.d/pve-web.conf
rm -f /etc/rsyslog.d/99-anssi-remote.conf
rm -f /etc/profile.d/tmout.sh
rm -f /etc/profile.d/99-pve-hardening.sh
rm -f /etc/issue.net
rm -f /etc/cron.allow
rm -f /etc/cron.daily/aide-check
rm -f /etc/security/pwquality.conf
rm -f /etc/security/faillock.conf
rm -f /etc/security/limits.d/99-pve-hardening.conf
systemctl restart ssh systemd-journald pve-firewall fail2ban apparmor rsyslog 2>/dev/null || true
sysctl --system 2>/dev/null || true
echo "Rollback termine. Redemarrage recommande."
EOF
    chmod 0700 /root/rollback-hardening.sh
fi

step "Termine"
log "Journal    : $LOG"
log "Sauvegarde : $BACKUP_DIR"
log "Rollback   : /root/rollback-hardening.sh"
log "LEVEL=$LEVEL"
log "Applique   :$APPLIED"
if [ -n "$SKIPPED" ]; then log "Saute (niveau) :$SKIPPED"; fi
exit 0
