#!/usr/bin/env bash
# =============================================================================
# apply-ceph.sh - Durcissement Ceph (client + configuration du cluster)
# -----------------------------------------------------------------------------
# References :
#   - Guide PVE 9 § 3.4 (chiffrement OSD) et § 3.5 (chiffrement msgr2)
#   - Clefs Ceph : auth_*_required=cephx, ms_bind_msgr2, ms_encrypt, ms_*_mode=secure
#   - Permissions : /etc/ceph en 750, keyrings en 600
#
# Usage : bash apply-ceph.sh   (DRY_RUN=1 pour simuler)
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

DRY_RUN="${DRY_RUN:-0}"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="/var/log/ceph-hardening-$TS.log"
CONF=/etc/ceph/ceph.conf

mkdir -p /etc/ceph
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
step() { printf '\n=== %s ===\n' "$*" | tee -a "$LOG"; }
run()  { log "EXEC: $*"; if [ "$DRY_RUN" = "1" ]; then printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"; return 0; fi; eval "$@" >>"$LOG" 2>&1 || log "ECHEC: $*"; }

log "=========================================================="
log " apply-ceph.sh - durcissement Ceph"
log " DRY_RUN=$DRY_RUN"
log "=========================================================="

# --- Sauvegarde -------------------------------------------------------------
if [ -f "$CONF" ]; then
    cp -a "$CONF" "$CONF.bak-$TS"
    log "Sauvegarde : $CONF.bak-$TS"
fi

# --- Permissions d'origine --------------------------------------------------
# Le de-hardening restaure les fichiers "<nom>.mode" trouves sous
# /root/hardening-backups (format : "<mode> <proprietaire> <groupe>").
# Sans cet enregistrement, le chmod 0750 sur /etc/ceph resterait applique
# apres le de-hardening et l'etat d'origine ne serait pas retrouve.
BK="/root/hardening-backups/$TS"
record_mode() {
    local p="$1"
    [ -e "$p" ] || return 0
    [ "$DRY_RUN" = "1" ] && return 0
    mkdir -p "$BK$(dirname "$p")"
    printf '%s %s %s\n' "$(stat -c %a "$p")" "$(stat -c %U "$p")" "$(stat -c %G "$p")" \
        > "$BK$(dirname "$p")/$(basename "$p").mode"
}
record_mode /etc/ceph

# --- Permissions de /etc/ceph ----------------------------------------------
step "1. Permissions du repertoire /etc/ceph"
run "chmod 0750 /etc/ceph"

# --- Permissions des keyrings ----------------------------------------------
step "2. Permissions des keyrings (secrets Ceph)"
for kr in /etc/ceph/*.keyring /etc/pve/priv/*.keyring; do
    [ -f "$kr" ] || continue
    record_mode "$kr"
    run "chmod 0600 $kr"
done

# --- Configuration cephx + msgr2 -------------------------------------------
# Guide PVE 9 § 3.5 : chiffrement en transit des communications Ceph.
step "3. Configuration cephx et chiffrement msgr2"
if [ "$DRY_RUN" != "1" ]; then
    touch "$CONF"
    if ! grep -q '^\[global\]' "$CONF"; then
        printf '[global]\n' >> "$CONF"
    fi
    # cephx : authentification obligatoire sur tous les canaux
    for kv in "auth_client_required=cephx" \
              "auth_cluster_required=cephx" \
              "auth_service_required=cephx"; do
        k="${kv%%=*}"
        if grep -qE "^[[:space:]]*${k}[[:space:]]*=" "$CONF"; then
            sed -i "s/^[[:space:]]*${k}[[:space:]]*=.*/${kv}/" "$CONF"
        else
            printf '%s\n' "$kv" >> "$CONF"
        fi
    done
    # msgr2 : messenger v2 + chiffrement de bout en bout
    for kv in "ms_bind_msgr2=true" \
              "ms_encrypt=true" \
              "ms_cluster_mode=secure" \
              "ms_service_mode=secure" \
              "ms_client_mode=secure" \
              "ms_mon_client_mode=secure" \
              "ms_mon_cluster_mode=secure" \
              "ms_mon_service_mode=secure"; do
        k="${kv%%=*}"
        if grep -qE "^[[:space:]]*${k}[[:space:]]*=" "$CONF"; then
            sed -i "s/^[[:space:]]*${k}[[:space:]]*=.*/${kv}/" "$CONF"
        else
            printf '%s\n' "$kv" >> "$CONF"
        fi
    done
    chmod 0640 "$CONF"
    log "--- $CONF ---"
    grep -E '^[[:space:]]*(auth_|ms_)' "$CONF" | tee -a "$LOG"
fi

# --- Chiffrement des OSD (option, Guide § 3.4) ------------------------------
step "4. Chiffrement des OSD (Guide PVE 9 § 3.4)"
log "Note : le chiffrement OSD se DEFINIT a la creation de l'OSD (ceph-volume lvm --dmcrypt)."
log "Valeur par defaut appliquee dans ceph.conf pour les prochains OSD :"
if [ "$DRY_RUN" != "1" ]; then
    if ! grep -qE '^[[:space:]]*osd_encrypt[[:space:]]*=' "$CONF"; then
        printf 'osd_encrypt=true\n' >> "$CONF"
    else
        sed -i 's/^[[:space:]]*osd_encrypt[[:space:]]*=.*/osd_encrypt=true/' "$CONF"
    fi
fi

# --- Dashboard : desactivation si inactif ----------------------------------
step "5. Dashboard Ceph"
if systemctl list-unit-files 2>/dev/null | grep -q 'ceph-dashboard'; then
    run "systemctl disable --now ceph-dashboard"
    log "Dashboard desactive (reactivez uniquement avec SSL + RBAC strict)"
else
    log "ceph-dashboard non installe : rien a faire"
fi

# --- Redemarrage des daemons ------------------------------------------------
step "6. Redemarrage des services Ceph"
if systemctl list-unit-files 2>/dev/null | grep -q 'ceph-mon'; then
    run "systemctl restart ceph.target"
else
    log "Aucun cluster Ceph local : pas de redemarrage"
fi

step "Termine"
log "Journal : $LOG"
exit 0
