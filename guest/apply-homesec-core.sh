#!/usr/bin/env bash
# =============================================================================
# apply-homesec-core.sh
# -----------------------------------------------------------------------------
# Automatisation tracable du guide PVE 9 de HomeSecExplorer/Proxmox-Hardening-Guide
# (release 0.9.2), calee sur le profil CIS Debian 13 Benchmark.
#
# NIVEAU DE DURCISSEMENT
#   LEVEL=1 (defaut) : CIS Debian 13 Level 1 + guide 1.2.4 (pare-feu PVE)
#   LEVEL=2          : + auditd /etc/pve, FORWARD DROP, profil ssh-audit,
#                      rkhunter, umask 027
#
# Chaque bloc porte la reference du controle dans le guide (ex: "1.2.4") et son
# niveau CIS, ce qui permet de remonter de la modification machine jusqu'a la
# recommandation, et d'expliquer ce qui n'est PAS applique a LEVEL=1.
#
# Conception orientee "test de hardening" :
#   - sauvegarde complete et restaurable de chaque fichier touche
#   - script de rollback genere : /root/rollback-hardening.sh
#   - idempotent : peut etre rejoue sans effet de bord
#   - "fail-safe" : ne coupe jamais l'acces SSH sans cle pre-verifiee
#   - DRY_RUN=1 pour rejouer sans rien modifier
#
# Usage :  LEVEL=1 bash apply-homesec-core.sh
#          DRY_RUN=1 bash apply-homesec-core.sh
# =============================================================================

set -u
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

DRY_RUN="${DRY_RUN:-0}"
LEVEL="${LEVEL:-1}"
# Sous-reseau autorise a joindre la GUI (8006) et SSH (22) via le pare-feu PVE.
# En NAT VirtualBox, l'hote se presente depuis la passerelle 10.0.2.2 -> 10.0.2.0/24.
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

# block <niveau_requis> <description> : garde l'execution ou la saute
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

# execute : modifie si DRY_RUN != 1
exec_cmd() {
    log "EXEC: $*"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"
        return 0
    fi
    eval "$@" >>"$LOG" 2>&1 || { log "ECHEC: $* (voir $LOG)"; return 1; }
    return 0
}

# backup <fichier> : conserve l'original horodate dans BACKUP_DIR
backup() {
    local f="$1"
    [ -e "$f" ] || return 0
    local d="$BACKUP_DIR$(dirname "$f")"
    mkdir -p "$d"
    cp -a "$f" "$d/$(basename "$f").$(date +%s)"
    log "BACKUP: $f -> $d"
}

# write_file <chemin> <mode> <contenu> : ecrit de façon atomique et idempotente
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

log "=========================================================="
log " apply-homesec-core.sh - PVE 9 / node $NODE_NAME"
log " LEVEL=$LEVEL  DRY_RUN=$DRY_RUN  MGMT_CIDR=$MGMT_CIDR"
log " BACKUP=$BACKUP_DIR"
log "=========================================================="

# =============================================================================
block 1 "0. Garde-fous (acces SSH)"
# =============================================================================
# On refuse de desactiver l'authentification par mot de passe tant qu'aucune
# cle publique n'est installee : sinon la VM devient inaccessible a distance.
KEYFILE="/root/.ssh/authorized_keys"
if [ -e "$KEYFILE" ] && [ -s "$KEYFILE" ]; then
    NK=$(grep -cE '^(ssh-|ecdsa-|sk-)' "$KEYFILE" 2>/dev/null || echo 0)
    log "cles publiques root detectees : $NK"
    HAVE_KEY=1
else
    HAVE_KEY=0
    log "AUCUNE cle publique root trouvee dans $KEYFILE"
fi

if [ "$HAVE_KEY" = "0" ] && [ "$DRY_RUN" != "1" ]; then
    log "ARRET : installez une cle SSH valide avant de lancer ce script."
    log "        (Web UI -> Noeud -> Shell -> collez la commande de bootstrap)"
    exit 2
fi

# =============================================================================
block 1 "1.1.1 / CIS L1 - Modules noyau, core dumps, limites"
# =============================================================================
ref "1.1.1 Apply Debian 13 CIS Level 1 (CIS 1.1.1.x, 1.5.11-13, 3.2.x)"

# --- 1.1.1.x : modules de systeme de fichiers et protocoles inutilises
#     Le guide precise de NE PAS desactiver 'fuse' (requis par PVE) ni 'ceph'.
MOD_BLACKLIST=/etc/modprobe.d/99-pve-hardening.conf
write_file "$MOD_BLACKLIST" 0644 "\
# Genere par apply-homesec-core.sh - CIS Debian 13 1.1.1.x et 3.2.x
# Note guide PVE 9 : 'fuse' est requis par Proxmox, il n'est PAS desactive.
install cramfs /bin/false
install freevxfs /bin/false
install hfs /bin/false
install hfsplus /bin/false
install jffs2 /bin/false
install udf /bin/false
# CIS 3.2.x : protocoles reseau inutilises
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install atm /bin/false
install can /bin/false
"
exec_cmd "systemctl restart systemd-modules-load"

# --- 1.5.11-13 + CIS 3.x : core dumps et sysctl
SYSCTL_DROP=/etc/sysctl.d/99-pve-hardening.conf
write_file "$SYSCTL_DROP" 0644 "\
# Genere par apply-homesec-core.sh - CIS Debian 13 1.5.x et 3.x
# CIS 1.5.11-1.5.13 : desactiver les core dumps
fs.suid_dumpable = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.core_pattern = |/bin/false
kernel.randomize_va_space = 2
# CIS 3.2.x : durcissement reseau IPv4/IPv6
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

write_file /etc/security/limits.d/99-pve-hardening.conf 0644 "\
# CIS Debian 13 1.5.11-1.5.13 : pas de core dump
*   hard   core   0
*   soft   core   0
root hard   core   0
"

# =============================================================================
block 1 "1.1.1 / CIS L1 - Options de montage temporaires"
# =============================================================================
ref "1.1.1 (CIS 1.1.2.1-1.1.2.4 : /tmp, /var/tmp, /dev/shm)"
backup /etc/fstab
if [ "$DRY_RUN" != "1" ]; then
    python3 - <<'PY' 2>&1 | tee -a "$LOG"
import sys
path = "/etc/fstab"
lines = open(path).read().splitlines()
targets = {"/tmp": "nosuid,nodev", "/var/tmp": "nosuid,nodev", "/dev/shm": "nosuid,nodev,noexec"}
out = []
changed = []
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
        new = " ".join(parts[:3] + [",".join(have)] + parts[4:])
        if new != l:
            changed.append(f"{tgt}: {opts} -> {','.join(have)}")
        out.append(new)
    else:
        out.append(l)
open(path, "w").write("\n".join(out) + "\n")
print("fstab mis a jour :", changed if changed else "aucun changement")
PY
fi
exec_cmd "mount -o remount,nosuid,nodev /tmp"
exec_cmd "mount -o remount,nosuid,nodev /var/tmp"
exec_cmd "mount -o remount,nosuid,nodev,noexec /dev/shm"

# =============================================================================
block 1 "2.4.1 / CIS L1 - Permissions cron et at"
# =============================================================================
ref "1.1.1 (CIS 2.4.1.x : cron, at)"
backup /etc/crontab
exec_cmd "chmod 0600 /etc/crontab"
for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    [ -d "$d" ] && exec_cmd "chmod 0700 $d"
done
for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    [ -d "$d" ] && exec_cmd "find $d -type f -exec chmod 0600 {} +"
done

# =============================================================================
block 1 "4.2.1 / CIS L1 - Journald persistant et compresse"
# =============================================================================
ref "1.1.1 (CIS 4.2.1.x : journald)"
JOURNALD_DROP=/etc/systemd/journald.conf.d/99-pve-hardening.conf
write_file "$JOURNALD_DROP" 0644 "\
# CIS Debian 13 4.2.1.x : journald persistant et compresse
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
block 1 "5.1.1-5.1.22 / CIS L1 - SSH : permissions, authentification, chiffrement"
# =============================================================================
ref "1.1.1 (CIS 5.1.x) + deviation guide § 5.1.21"
# IMPORTANT Debian 13 : sshd_config commence par 'Include /etc/ssh/sshd_config.d/*.conf'
# et OpenSSH conserve la PREMIERE valeur rencontree. Le fichier doit donc etre
# nomme '00-*' pour passer devant un éventuel '50-cloud-init.conf'.
SSHD_DROP=/etc/ssh/sshd_config.d/00-pve-hardening.conf
if [ "$LEVEL" -ge 2 ]; then
    # Profil ssh-audit Debian 13 (guide 1.1.4) : au-dela de CIS
    SSH_CONF="\
# Genere par apply-homesec-core.sh - profil ssh-audit Debian 13 (guide 1.1.4)
PermitRootLogin prohibit-password
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
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group16-sha512,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
PubkeyAcceptedAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
"
else
    # CIS Debian 13 Level 1 (5.1.4-5.1.22) : les algorithmes recommandes par CIS
    SSH_CONF="\
# Genere par apply-homesec-core.sh - CIS Debian 13 Level 1 (5.1.4-5.1.22)
# Deviation guide PVE 9 § 5.1.21 : ne PAS desactiver root sur un cluster,
# on passe en prohibit-password (acces root par cle uniquement).
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
MaxSessions 5
MaxStartups 10:30:60
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
"
fi
write_file "$SSHD_DROP" 0644 "$SSH_CONF"
if [ "$DRY_RUN" != "1" ]; then
    printf 'Acces reserve. Toute activite non autorisee est enregistree.\n' > /etc/issue.net
    chmod 0644 /etc/issue.net
fi
backup /etc/ssh/sshd_config
exec_cmd "chmod 0600 /etc/ssh/sshd_config"
[ -d /etc/ssh/sshd_config.d ] && exec_cmd "chmod 0700 /etc/ssh/sshd_config.d"
exec_cmd "chmod 0600 /etc/ssh/ssh_host_*_key"
exec_cmd "chmod 0644 /etc/ssh/ssh_host_*_key.pub"
exec_cmd "chmod 0700 /root/.ssh"
exec_cmd "chmod 0600 /root/.ssh/authorized_keys"
# Guide PVE 9 : on ne desactive PAS DisableForwarding (migration live).
# En DRY_RUN le fichier n'est pas ecrit : la validation sshd -t n'a pas de sens.
if [ "$DRY_RUN" != "1" ]; then
    if ! sshd -t 2>/dev/null; then
        log "ERREUR : 'sshd -t' signale une config invalide. Suppression de $SSHD_DROP"
        rm -f "$SSHD_DROP"
        exit 3
    fi
else
    log "DRY-RUN : validation 'sshd -t' ignoree"
fi
exec_cmd "systemctl restart ssh"

# =============================================================================
block 1 "5.3.3 / CIS L1 - PAM : faillock et qualite de mot de passe"
# =============================================================================
ref "1.1.1 (CIS 5.3.3.1, 5.4.1)"
exec_cmd "apt-get update -y"
exec_cmd "apt-get install -y auditd audispd-plugins libpam-pwquality cron"
write_file /etc/security/faillock.conf 0644 "\
# CIS Debian 13 5.3.3.1 - pam_faillock
deny = 5
unlock_time = 900
fail_interval = 900
dir = /var/log/faillock
"
backup /etc/pam.d/common-auth
if [ "$DRY_RUN" != "1" ]; then
    if ! grep -q 'pam_faillock' /etc/pam.d/common-auth; then
        sed -i 's/^\(auth\s*requisite\s*pam_unix\.so\)/auth\trequisite\tpam_faillock.so pre_auth silent\nauth\trequisite\tpam_faillock.so auth_fail\nauth\trequisite\tpam_faillock.so auth_succ\n\1/' /etc/pam.d/common-auth
        grep -q 'pam_faillock' /etc/pam.d/common-auth && \
            sed -i 's/^auth\s*required\s*pam_deny\.so/auth\trequisite\tpam_faillock.so auth_fail\nauth\toptional\tpam_faillock.so auth_succ\n&/' /etc/pam.d/common-auth
    fi
fi
write_file /etc/security/pwquality.conf 0644 "\
# CIS Debian 13 5.4.1 - qualite des mots de passe
minlen = 14
minclass = 3
maxrepeat = 3
dictcheck = 1
usercheck = 1
enforcing = 1
retry = 3
"

# =============================================================================
block 1 "1.1.3 - Mises a jour de securite automatiques"
# =============================================================================
ref "1.1.3 Configure Automatic Security Updates"
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
block 1 "1.2.4 - Pare-feu PVE : activation et regles SSH/GUI"
# =============================================================================
ref "1.2.4 Enable the PVE Firewall (INPUT=DROP, OUTPUT=ACCEPT)"
# Format attendu par PVE pour /etc/pve/firewall/cluster.fw : sections [OPTIONS]
# et [RULES] avec la syntaxe 'IN ACCEPT -source x -p tcp -dport n'.
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
block 1 "2.3.3 - fail2ban sur l'interface web Proxmox"
# =============================================================================
ref "2.3.3 Protect the GUI with Fail2Ban"
exec_cmd "apt-get install -y fail2ban"
write_file /etc/fail2ban/jail.d/pve-web.conf 0644 "\
# Genere par apply-homesec-core.sh - protection de l'interface web PVE
[pve-web]
enabled  = true
port     = https,http
filter   = proxmox
logpath  = /var/log/pveproxy/access.log
maxretry = 3
findtime = 300
bantime  = 3600
"
if [ "$DRY_RUN" != "1" ]; then
    if [ ! -f /etc/fail2ban/filter.d/proxmox.conf ]; then
        cat > /etc/fail2ban/filter.d/proxmox.conf <<'EOF'
[Definition]
failregex = ^\s*(?:\s*\[.*\])?\s*<HOST> \S+ - .* \[pam\].*authentication failure.*$
            ^.* "user":".*","useragent.*","realm":.*,"status":401.*$
ignoreregex =
EOF
    fi
fi
exec_cmd "systemctl enable fail2ban"
exec_cmd "systemctl restart fail2ban"

# =============================================================================
block 1 "2.1 - Comptes nominatifs et moindre privilege"
# =============================================================================
ref "2.1.1 Use Personalized Accounts / 2.1.2 Grant Least Privilege"
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
# Blocs CIS LEVEL 2 - executes uniquement si LEVEL >= 2
# (le gating est structurel : un return dans block() n'interrompt pas le script)
# =============================================================================
if [ "$LEVEL" -ge 2 ]; then

# =============================================================================
block 2 "1.2.5 - Pare-feu PVE : politique FORWARD DROP et backend nftables"
# =============================================================================
ref "1.2.5 PVE Firewall - Default FORWARD Policy DROP (backend nftables, tech preview)"
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

# =============================================================================
block 2 "5.1.2 - Auditd sur /etc/pve"
# =============================================================================
ref "5.1.2 Auditd for /etc/pve"
write_file /etc/audit/rules.d/90-pve.rules 0644 "\
-w /etc/pve -p wa -k pve-config
"
exec_cmd "systemctl enable auditd"
exec_cmd "augenrules --load"
exec_cmd "systemctl restart auditd"

# =============================================================================
block 2 "5.3.2 - Detection de rootkit"
# =============================================================================
ref "5.3.2 Rootkit Detection"
exec_cmd "apt-get install -y rkhunter"
if [ "$DRY_RUN" != "1" ] && [ -f /etc/rkhunter.conf ]; then
    sed -i 's/^SCRIPTWHITELISTS=.*/SCRIPTWHITELISTS="rkhunter"/' /etc/rkhunter.conf
fi
exec_cmd "rkhunter --propupd"

# =============================================================================
block 2 "CIS L2 - umask par defaut a 027"
# =============================================================================
ref "CIS Debian 13 5.4.4"
write_file /etc/profile.d/99-pve-hardening.sh 0644 "\
umask 027
"

fi  # fin des blocs LEVEL >= 2

# =============================================================================
block 1 "Verification finale"
# =============================================================================
exec_cmd "sshd -t"
exec_cmd "systemctl --failed --no-pager"
exec_cmd "systemctl is-active ssh pve-firewall auditd fail2ban"
exec_cmd "pve-firewall status"
exec_cmd "pvesh get /cluster/firewall/options --output-format json-pretty"

# ------------------------------------------------------------------- rollback
if [ "$DRY_RUN" != "1" ]; then
    cat > /root/rollback-hardening.sh <<EOF
#!/usr/bin/env bash
# Restaure la configuration d'origine sauvegardee par apply-homesec-core.sh
set -u
BACKUP_DIR="$BACKUP_DIR"
echo "Restauration depuis \$BACKUP_DIR"
find "\$BACKUP_DIR" -type f | while read -r f; do
    orig="\${f%.*}"
    if [ -e "\$orig" ]; then
        cp -a "\$orig" "\${orig%.*.*}"
        echo "restaure : \$orig"
    fi
done
rm -f /etc/ssh/sshd_config.d/00-pve-hardening.conf
rm -f /etc/modprobe.d/99-pve-hardening.conf
rm -f /etc/sysctl.d/99-pve-hardening.conf
rm -f /etc/systemd/journald.conf.d/99-pve-hardening.conf
rm -f /etc/audit/rules.d/90-pve.rules
rm -f /etc/fail2ban/jail.d/pve-web.conf
systemctl restart ssh systemd-journald pve-firewall
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
