#!/usr/bin/env bash
# apply-anssi.sh - durcissement ANSSI (niveaux 1..4)
# Usage : LEVEL=1..4 bash apply-anssi.sh   (DRY_RUN=1 pour simuler)
set -u
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
DRY_RUN="${DRY_RUN:-0}"
LEVEL="${LEVEL:-1}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/anssi-backups/$TS"
LOG="/var/log/anssi-$TS.log"
mkdir -p "$BACKUP_DIR"
log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
step() { printf '\n=== %s ===\n' "$*" | tee -a "$LOG"; }
block() { local need="$1" desc="$2"; if [ "$LEVEL" -lt "$need" ]; then printf '\n=== SKIP (niveau %s, LEVEL=%s) : %s ===\n' "$need" "$LEVEL" "$desc" | tee -a "$LOG"; return 1; fi; step "$desc"; return 0; }
exec_cmd() { log "EXEC: $*"; [ "$DRY_RUN" = "1" ] && { printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"; return 0; }; eval "$@" >>"$LOG" 2>&1 || { log "ECHEC: $*"; return 1; }; }
backup() { [ -e "$1" ] || return 0; local d="$BACKUP_DIR$(dirname "$1")"; mkdir -p "$d"; cp -a "$1" "$d/$(basename "$1").$(date +%s)"; }
write_file() { local p="$1" m="$2" c="$3"; backup "$p"; if [ "$DRY_RUN" = "1" ]; then printf '    [DRY-RUN] ecriture %s\n' "$p" | tee -a "$LOG"; return 0; fi; mkdir -p "$(dirname "$p")"; printf '%s\n' "$c" > "$p.tmp"; chmod "$m" "$p.tmp"; mv "$p.tmp" "$p"; }

log "ANSSI hardening LEVEL=$LEVEL DRY_RUN=$DRY_RUN"

# --- niveau 1 : minimal (renforce le socle)
block 1 "ANSSI N1 - permissions /boot et ctrl-alt-del"
exec_cmd "chmod 700 /boot"
exec_cmd "systemctl disable ctrl-alt-del.target"
exec_cmd "systemctl mask ctrl-alt-del.target"

block 1 "ANSSI N1 - sysctl ANSSI (bpf, jit)"
write_file /etc/sysctl.d/98-anssi.conf 0644 "\
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.yama.ptrace_scope = 2
"
exec_cmd "sysctl --system"

# --- niveau 2 : intermediaire
block 2 "ANSSI N2 - politique de mots de passe (aging)"
if [ "$DRY_RUN" != "1" ]; then
  sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
  sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
  sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs
  grep -q '^PASS_MAX_DAYS' /etc/login.defs || echo 'PASS_MAX_DAYS   90' >> /etc/login.defs
fi

block 2 "ANSSI N2 - AIDE (integrite fichiers)"
# Les depots enterprise Proxmox (pve + ceph-squid) exigent une licence et
# renvoient 401 : ils cassent apt-get update. On les desactive (inutile en lab).
if [ "$DRY_RUN" != "1" ]; then
    for f in /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/ceph.sources; do
        if [ -f "$f" ]; then
            mv "$f" "$f.disabled"
            echo "  [ok] depot enterprise desactive : $(basename "$f")"
        fi
    done
fi
exec_cmd "apt-get update -y"
exec_cmd "apt-get install -y aide aide-common"
if [ "$DRY_RUN" != "1" ] && command -v aideinit >/dev/null 2>&1; then
  # 'aide --init' pose une question [yN] : on repond "yes" et on purge la base
  # existante pour eviter tout blocage interactif du script.
  rm -f /var/lib/aide/aide.db /var/lib/aide/aide.db.new
  yes | timeout 300 aideinit >/dev/null 2>&1 || true
  yes | timeout 300 aide --init >/dev/null 2>&1 || true
  [ -f /var/lib/aide/aide.db.new ] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  [ -f /var/lib/aide/aide.db.gz ] && echo "  [ok] base AIDE initialisee"
fi

block 2 "ANSSI N2 - AppArmor en mode enforce"
if command -v aa-enforce >/dev/null 2>&1; then
  for prof in /etc/apparmor.d/*; do
    [ -f "$prof" ] || continue
    aa-enforce "$prof" >/dev/null 2>&1 || true
  done
  exec_cmd "systemctl reload apparmor"
fi

block 2 "ANSSI N2 - centralisation des journaux (rsyslog)"
write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "\
# ANSSI : transfert vers un serveur de journaux central (a adapter)
# Definir LOG_SERVER pour activer le transfert distant (ex: 10.0.2.1).
# *.* action(type=\"omfwd\" target=\"$LOG_SERVER\" port=\"514\" protocol=\"tcp\")
# & stop
"
if [ "$DRY_RUN" != "1" ] && [ -n "${LOG_SERVER:-}" ]; then
    write_file /etc/rsyslog.d/99-anssi-remote.conf 0644 "\
*.* action(type=\"omfwd\" target=\"$LOG_SERVER\" port=\"514\" protocol=\"tcp\")
& stop
"
fi
exec_cmd "systemctl restart rsyslog"

# --- niveau 3 : renforce
block 3 "ANSSI N3 - desactivation du stockage USB"
write_file /etc/modprobe.d/99-anssi-usb.conf 0644 "\
install usb-storage /bin/false
blacklist usb-storage
"
exec_cmd "update-initramfs -u"

block 3 "ANSSI N3 - cron restreint (cron.allow)"
if [ "$DRY_RUN" != "1" ]; then
  echo root > /etc/cron.allow
  chmod 600 /etc/cron.allow
fi

# --- niveau 4 : eleve
block 4 "ANSSI N4 - services non essentiels"
for svc in avahi-daemon cups bluetooth; do
  if systemctl is-active "$svc" >/dev/null 2>&1; then exec_cmd "systemctl disable --now $svc"; fi
done

block 4 "ANSSI N4 - umask 077 pour root"
if [ "$DRY_RUN" != "1" ]; then
  grep -q 'umask 077' /root/.bashrc 2>/dev/null || echo 'umask 077' >> /root/.bashrc
fi

log "ANSSI termine LEVEL=$LEVEL"
exit 0