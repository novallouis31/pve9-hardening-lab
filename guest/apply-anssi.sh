#!/usr/bin/env bash
# =============================================================================
# apply-anssi.sh - Durcissement ANSSI / BP-028 (niveaux 1 a 4)
# -----------------------------------------------------------------------------
# References :
#   - Guide PVE 9 (HomeSecExplorer) : sections 4.x ANSSI
#   - Makaveli81/ansible-linux-hardening : audit_items ANSSI BP-028 (niveaux M/I/R/E)
#   - hardenedlinux/harbian-audit : checks 4.8 (USB), 8.2 (rsyslog), 9.3.8 (root login)
#
# Niveaux :
#   1 = minimal (M)    : socle noyau + comptes
#   2 = intermediaire (I) : mots de passe, integrite, journaux, AppArmor
#   3 = renforce (R)   : USB, cron, SSH restreint
#   4 = eleve (E)      : services non essentiels, umask root
#
# Usage : LEVEL=1..4 bash apply-anssi.sh   (DRY_RUN=1 pour simuler)
# =============================================================================
set -u
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

DRY_RUN="${DRY_RUN:-0}"
LEVEL="${LEVEL:-1}"
# Sous-reseau de management (NAT VirtualBox) : autorise le root SSH par cle.
MGMT_CIDR="${MGMT_CIDR:-10.0.2.0/24}"
# Compte d'administration cree par apply-homesec-core.sh : il doit figurer
# dans AllowUsers, sinon le fichier SSH produit par l'ANSSI priverait ce
# compte de son acces (le contenu doit etre identique a celui du core).
ADMIN_USER="${ADMIN_USER:-pveadmin}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/anssi-backups/$TS"
LOG="/var/log/anssi-$TS.log"
mkdir -p "$BACKUP_DIR"
# Etat des paquets AVANT durcissement (voir apply-homesec-core.sh).
dpkg-query -W -f='${Package}\n' 2>/dev/null | sort > "$BACKUP_DIR/packages.before"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
step() { printf '\n=== %s ===\n' "$*" | tee -a "$LOG"; }
ref()  { printf '    (ANSSI BP-028 : %s)\n' "$*" | tee -a "$LOG"; }
block() { local need="$1" desc="$2"; if [ "$LEVEL" -lt "$need" ]; then printf '\n=== SKIP (niveau %s, LEVEL=%s) : %s ===\n' "$need" "$LEVEL" "$desc" | tee -a "$LOG"; return 1; fi; step "$desc"; return 0; }
exec_cmd() { log "EXEC: $*"; if [ "$DRY_RUN" = "1" ]; then printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"; return 0; fi; eval "$@" >>"$LOG" 2>&1 || { log "ECHEC: $*"; return 1; }; }
backup() { [ -e "$1" ] || return 0; local d="$BACKUP_DIR$(dirname "$1")"; mkdir -p "$d"; local b="$d/$(basename "$1").$(date +%s%N)"; cp -a "$1" "$b"; }
backup_mode() { [ -e "$1" ] || return 0; local d="$BACKUP_DIR$(dirname "$1")"; mkdir -p "$d"; printf '%s %s %s\n' "$(stat -c %a "$1")" "$(stat -c %U "$1")" "$(stat -c %G "$1")" > "$d/$(basename "$1").mode"; }
write_file() { local p="$1" m="$2" c="$3"; backup "$p"; if [ "$DRY_RUN" = "1" ]; then printf '    [DRY-RUN] ecriture %s\n' "$p" | tee -a "$LOG"; return 0; fi; mkdir -p "$(dirname "$p")"; printf '%s\n' "$c" > "$p.tmp"; chmod "$m" "$p.tmp"; mv "$p.tmp" "$p"; }

log "ANSSI hardening LEVEL=$LEVEL DRY_RUN=$DRY_RUN"

# =============================================================================
# NIVEAU 1 - MINIMAL (M)
# =============================================================================

block 1 "ANSSI N1 - permissions /boot et ctrl-alt-del"
ref "harbian 3.1/3.2 + 5.4"
backup_mode /boot
exec_cmd "chmod 700 /boot"
exec_cmd "systemctl disable ctrl-alt-del.target"
exec_cmd "systemctl mask ctrl-alt-del.target"

block 1 "ANSSI N1 - sysctl ANSSI (bpf, jit, ptrace)"
ref "harbian 1.5.3/1.5.5/1.5.8/1.5.9 + BP-028 [SYS]"
write_file /etc/sysctl.d/98-anssi.conf 0644 "\
# Genere par apply-anssi.sh - ANSSI BP-028 niveau M
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.yama.ptrace_scope = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
"
exec_cmd "sysctl --system"

block 1 "ANSSI N1 - UMASK global 027 dans login.defs"
ref "BP-028 [FIC] Umask Global = 027 / harbian 10.4"
if [ "$DRY_RUN" != "1" ]; then
  backup /etc/login.defs
  # login.defs utilise une tabulation comme separateur : on remplace la ligne
  # commentee ET la ligne active pour eviter toute ambiguite.
  python3 - <<'PYUMASK'
import re
p = "/etc/login.defs"
try:
    lines = open(p).read().splitlines()
except OSError:
    lines = []
out = []
done = False
for l in lines:
    s = l.strip()
    if s.startswith("#") and re.match(r"#\s*UMASK\s", s):
        continue  # on retire la ligne commentee
    if re.match(r"^UMASK\s", l):
        out.append("UMASK\t027")
        done = True
        continue
    out.append(l)
if not done:
    out.append("UMASK\t027")
open(p, "w").write("\n".join(out) + "\n")
print("login.defs : UMASK=027")
PYUMASK
fi

block 1 "ANSSI N1 - timeout de session TMOUT (BP-028 [USR])"
ref "BP-028 [USR] TMOUT=900 / harbian 10.5"
write_file /etc/profile.d/tmout.sh 0644 "\
# ANSSI BP-028 - expiration des sessions interactives
TMOUT=900
readonly TMOUT
export TMOUT
"

block 1 "ANSSI N1 - shells de comptes systeme non interactifs"
ref "BP-028 [USR] daemon shell = /usr/sbin/nologin"
# Memorisation des shells d'origine : sans ce fichier, le de-hardening ne
# pourrait pas restaurer les comptes de systeme modifies.
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$BACKUP_DIR/etc"
    : > "$BACKUP_DIR/etc/shells.before"
    for u in daemon bin sys games man lp mail news uucp proxy www-data backup list irc gnats nobody; do
        getent passwd "$u" 2>/dev/null | cut -d: -f1,7 >> "$BACKUP_DIR/etc/shells.before"
    done
fi
for u in daemon bin sys games man lp mail news uucp proxy www-data backup list irc gnats nobody; do
  if getent passwd "$u" >/dev/null 2>&1; then
    sh=$(getent passwd "$u" | cut -d: -f7)
    case "$sh" in
      */nologin|*/false) : ;;
      *) exec_cmd "usermod --shell /usr/sbin/nologin $u" ;;
    esac
  fi
done

# =============================================================================
# NIVEAU 2 - INTERMEDIAIRE (I)
# =============================================================================

block 2 "ANSSI N2 - politique de mots de passe (aging)"
ref "BP-028 / harbian 10.1.1-10.1.3"
if [ "$DRY_RUN" != "1" ]; then
  backup /etc/login.defs
  python3 - <<'PYAGE'
import re
p = "/etc/login.defs"
try:
    lines = open(p).read().splitlines()
except OSError:
    lines = []


def set_param(lines, key, value):
    pat = re.compile(r"^\s*" + re.escape(key) + r"\s")
    out = []
    done = False
    for l in lines:
        if l.strip().startswith("#") and re.match(r"#\s*" + re.escape(key) + r"\s", l):
            continue
        if pat.match(l):
            out.append("{}\t{}".format(key, value))
            done = True
            continue
        out.append(l)
    if not done:
        out.append("{}\t{}".format(key, value))
    return out


lines = set_param(lines, "PASS_MAX_DAYS", "90")
lines = set_param(lines, "PASS_MIN_DAYS", "1")
lines = set_param(lines, "PASS_WARN_AGE", "7")
open(p, "w").write("\n".join(lines) + "\n")
print("login.defs : PASS_MAX_DAYS=90 PASS_MIN_DAYS=1 PASS_WARN_AGE=7")
PYAGE
fi

block 2 "ANSSI N2 - AIDE (integrite fichiers)"
ref "harbian 8.4.1/8.4.2"
# --- DNS joignable via le NAT VirtualBox (cf. apply-homesec-core.sh) ---------
# Sans resolution de nom, apt-get update echoue et aucun paquet ne peut etre
# installe (AIDE, rsyslog, apparmor-utils...) : les controles d'audit
# correspondants echoueraient alors a tort.
DNS_NAT="${DNS_NAT:-10.0.2.3}"
if [ "$DRY_RUN" != "1" ]; then
    # cf. apply-homesec-core.sh : la detection repose sur la resolution ET la
    # joignabilite reelle du depot (le cache DNS peut masquer la panne).
    # Les listes de paquets peuvent avoir ete telechargees a ZERO OCTET
    # lors d'une panne DNS : apt les met en cache et annonce "Hit" ensuite,
    # sans jamais les retelecharger. On les purge pour forcer la reprise.
    find /var/lib/apt/lists -type f -size 0 -name '*_Packages*' -delete 2>/dev/null || true
    rm -f /var/lib/apt/lists/*Partial* 2>/dev/null || true
    if ! getent hosts deb.debian.org >/dev/null 2>&1 || ! timeout 30 apt-get update >/dev/null 2>&1; then
        echo "  [ok] DNS ou depot non fonctionnel : bascule sur le DNS du NAT VirtualBox ($DNS_NAT)"
        cp -a /etc/resolv.conf /etc/resolv.conf.bak-lab 2>/dev/null || true
        printf 'search lab.local\nnameserver %s\n' "$DNS_NAT" > /etc/resolv.conf
    fi
fi
# Les depots enterprise Proxmox (pve + ceph-squid) exigent une licence et
# renvoient 401 : ils cassent apt-get update. On les desactive (inutile en lab).
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
fi
# L'update est indispensable : sans lui, les listes de l'image d'installation
# sont absentes ou perimees et AUCUN paquet ne peut etre installe.
exec_cmd "timeout 180 apt-get update -y"
exec_cmd "timeout 900 apt-get install -y aide aide-common apparmor-utils rsyslog"
if [ "$DRY_RUN" != "1" ] && command -v aideinit >/dev/null 2>&1; then
  # 'aide --init' pose une question [yN] : on repond "yes" et on purge la base
  # existante pour eviter tout blocage interactif du script.
  rm -f /var/lib/aide/aide.db /var/lib/aide/aide.db.new
  yes | timeout 300 aideinit >/dev/null 2>&1 || true
  yes | timeout 300 aide --init >/dev/null 2>&1 || true
  [ -f /var/lib/aide/aide.db.new ] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  [ -f /var/lib/aide/aide.db.gz ] && echo "  [ok] base AIDE initialisee"
fi
# AIDE doit etre execute periodiquement (harbian 8.4.2)
write_file /etc/cron.daily/aide-check 0755 "\
#!/bin/sh
/usr/bin/aide --check >/var/log/aide-check.log 2>&1 || true
"

block 2 "ANSSI N2 - AppArmor en mode enforce"
ref "harbian 4.5 / BP-028"
# apparmor-utils est installe ci-dessus : sans lui, aa-enforce est absent et
# les profils restent en mode complain (controle ANS.APPARMOR.ENFORCE en echec).
if command -v aa-enforce >/dev/null 2>&1; then
  for prof in /etc/apparmor.d/*; do
    [ -f "$prof" ] || continue
    aa-enforce "$prof" >/dev/null 2>&1 || true
  done
  # aa-enforce ecrit /etc/apparmor.d/<profil> en mode enforce : il faut
  # recharger la politique pour que le mode change effectivement.
  apparmor_parser -r /etc/apparmor.d/usr.bin.man 2>/dev/null || true
  systemctl reload apparmor 2>/dev/null || true
  systemctl restart apparmor 2>/dev/null || true
else
  log "  aa-enforce absent : AppArmor enforcement non applique"
fi

block 2 "ANSSI N2 - centralisation des journaux (rsyslog)"
ref "harbian 8.2.1-8.2.4 / BP-028"
# ATTENTION : ne jamais ecrire $LOG_SERVER non echappe dans le corps de
# write_file : bash l'expanserait (set -u => "unbound variable") et le script
# s'arreterait AVANT les blocs N3/N4.
LOG_SERVER="${LOG_SERVER:-}"
if [ "$DRY_RUN" != "1" ]; then
    if [ -n "$LOG_SERVER" ]; then
        write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "\
*.* action(type=\"omfwd\" target=\"$LOG_SERVER\" port=\"514\" protocol=\"tcp\")
& stop
"
    else
        write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "\
# ANSSI BP-028 - centralisation des journaux
# Definir LOG_SERVER=<ip> puis redemarrer rsyslog pour activer le transfert.
*.* action(type=\"omfwd\" target=\"127.0.0.1\" port=\"514\" protocol=\"tcp\")
"
    fi
    exec_cmd "systemctl enable rsyslog"
    exec_cmd "systemctl restart rsyslog"
else
    write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "# DRY-RUN"
fi

block 2 "ANSSI N2 - permissions des fichiers de comptes (harbian 12.1-12.6)"
ref "harbian 12.1/12.2/12.3/12.4/12.5/12.6"
for pf in /etc/passwd /etc/shadow /etc/group /etc/gshadow \
          /etc/passwd- /etc/shadow- /etc/group- /etc/gshadow-; do
    backup_mode "$pf"
done
exec_cmd "chmod 0644 /etc/passwd"
exec_cmd "chmod 0640 /etc/shadow"
exec_cmd "chmod 0644 /etc/group"
exec_cmd "chmod 0640 /etc/gshadow"
exec_cmd "chmod 0600 /etc/passwd-"
exec_cmd "chmod 0600 /etc/shadow-"
exec_cmd "chmod 0600 /etc/group-"
exec_cmd "chmod 0600 /etc/gshadow-"

block 2 "ANSSI N2 - banner de connexion (harbian 11.1)"
ref "harbian 11.1 warning banners"
write_file /etc/issue.net 0644 "\
Acces reserve. Toute activite non autorisee est enregistre et surveille.
"

block 2 "ANSSI N2 - permissions des repertoires cron (harbian 9.1.2-9.1.7)"
ref "harbian 9.1.2 a 9.1.7"
exec_cmd "chmod 0600 /etc/crontab"
exec_cmd "chown root:root /etc/crontab"
exec_cmd "chmod 0700 /etc/cron.d"
exec_cmd "chown root:root /etc/cron.d"
exec_cmd "chmod 0700 /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly"
exec_cmd "chown root:root /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly"

# =============================================================================
# NIVEAU 3 - RENFORCE (R)
# =============================================================================

block 3 "ANSSI N3 - desactivation du stockage USB"
ref "harbian 4.8 disable_usb_devices"
write_file /etc/modprobe.d/99-anssi-usb.conf 0644 "\
install usb-storage /bin/false
blacklist usb-storage
"
exec_cmd "update-initramfs -u"

block 3 "ANSSI N3 - cron restreint (cron.allow)"
ref "harbian 9.1.8 cron_users"
if [ "$DRY_RUN" != "1" ]; then
  echo root > /etc/cron.allow
  chmod 600 /etc/cron.allow
fi

block 3 "ANSSI N3 - root SSH restreint au sous-reseau de management"
ref "Guide PVE 9 option B + harbian 9.3.8 (deviation documentee)"
# Le guide PVE 9 interdit de mettre 'PermitRootLogin no' sur Proxmox (les
# workflows d'administration l'exigent) et recommande l'option B : restreindre
# le root SSH au reseau de management via un bloc Match.
# On applique : PermitRootLogin no global + Match Address <MGMT_CIDR> yes.
# Equivalent de 'no' pour toute autre source, tout en gardant l'acces du lab.
if [ "$DRY_RUN" != "1" ]; then
  SSHD_DROP=/etc/ssh/sshd_config.d/00-pve-hardening.conf
  backup "$SSHD_DROP"
  # Contenu IDENTIQUE a celui d'apply-homesec-core.sh : quel que soit l'ordre
  # d'application des deux scripts, le resultat final est le meme.
  # Liste AllowUsers : on n'annonce que des comptes reellement presents,
# sinon 'sshd -t' echoue et la configuration SSH serait rejetee.
ALLOW_USERS="root"
if getent passwd "$ADMIN_USER" >/dev/null 2>&1; then
    ALLOW_USERS="root $ADMIN_USER"
fi
write_file "$SSHD_DROP" 0600 "\
# Genere par apply-anssi.sh - ANSSI BP-028 niveau R
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
  if sshd -t 2>/dev/null; then
    systemctl restart ssh 2>/dev/null || systemctl reload ssh
    echo "  [ok] root SSH restreint a $MGMT_CIDR"
  else
    log "ERREUR : sshd -t invalide, restauration de la configuration precedente"
    rm -f "$SSHD_DROP"
    systemctl restart ssh 2>/dev/null || true
  fi
fi

# =============================================================================
# NIVEAU 4 - ELEVE (E)
# =============================================================================

block 4 "ANSSI N4 - services non essentiels"
ref "harbian 6.2/6.3/6.9/6.10/6.11/6.12/6.14/6.16"
for svc in avahi-daemon cups bluetooth rsh-server rsh-client talk-server talk-client telnet inetd xinetd nfs-kernel-server samba smbd nmbd snmpd vsftpd proftpd haproxy rsyslog-lm; do
  if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
    exec_cmd "systemctl disable --now $svc"
  fi
done

block 4 "ANSSI N4 - umask 077 pour root"
ref "harbian 10.4 default_umask"
if [ "$DRY_RUN" != "1" ]; then
  backup /root/.bashrc
  grep -q 'umask 077' /root/.bashrc 2>/dev/null || echo 'umask 077' >> /root/.bashrc
fi

block 4 "ANSSI N4 - suppression des comptes et cles autorisees inutiles"
ref "harbian 13.1/13.5/13.14-13.17"
if [ "$DRY_RUN" != "1" ]; then
  # aucun compte hors root ne doit avoir un UID 0
  mkdir -p "$BACKUP_DIR/etc"
  : > "$BACKUP_DIR/etc/locked.before"
  for u in $(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd); do
    getent passwd "$u" 2>/dev/null | cut -d: -f1 >> "$BACKUP_DIR/etc/locked.before"
    exec_cmd "usermod --lock $u"
  done
  # UID/GID dupliques
  dups=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d)
  for d in $dups; do
    log "  [warn] UID duplique : $d"
  done
fi


# --- Verification post-installation des paquets requis ----------------------
# Un echec d'installation (reseau, depot injoignable, conflit) doit etre
# visible IMMEDIATEMENT, et non 12 controles d'audit plus tard.
missing_pkgs=""
for p in aide aide-common apparmor-utils rsyslog; do
    if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
        missing_pkgs="$missing_pkgs $p"
    fi
done
if [ -n "$missing_pkgs" ]; then
    log "ECHEC : paquet(s) requis non installes :$missing_pkgs"
    log "         verifier le depot apt et la resolution DNS (voir /etc/resolv.conf)"
    exit 1
fi

log "ANSSI termine LEVEL=$LEVEL"
exit 0
