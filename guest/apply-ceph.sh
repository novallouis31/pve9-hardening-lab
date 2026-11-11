#!/usr/bin/env bash
# apply-ceph.sh - durcissement Ceph (config client + permissions)
set -u
export LC_ALL=C
DRY_RUN="${DRY_RUN:-0}"
log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
step() { printf '\n=== %s ===\n' "$*"; }
exec_cmd() { log "EXEC: $*"; [ "$DRY_RUN" = "1" ] && { printf '    [DRY-RUN] %s\n' "$*"; return 0; }; eval "$@" >>/var/log/ceph-hardening.log 2>&1 || log "ECHEC: $*"; }
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p /etc/ceph
# permissions repertoire
[ "$DRY_RUN" != "1" ] && chmod 750 /etc/ceph
# ceph.conf durci (client + crypto)
if [ "$DRY_RUN" != "1" ]; then
  if [ ! -f /etc/ceph/ceph.conf ]; then touch /etc/ceph/ceph.conf; fi
  # ensure [global] section with auth + msgr2 secure
  if ! grep -q '^\[global\]' /etc/ceph/ceph.conf; then echo '[global]' >> /etc/ceph/ceph.conf; fi
  grep -q 'auth_cluster_required' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a auth_cluster_required = cephx' /etc/ceph/ceph.conf
  grep -q 'auth_service_required' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a auth_service_required = cephx' /etc/ceph/ceph.conf
  grep -q 'auth_client_required' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a auth_client_required = cephx' /etc/ceph/ceph.conf
  grep -q 'ms_cluster_mode' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a ms_cluster_mode = secure' /etc/ceph/ceph.conf
  grep -q 'ms_service_mode' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a ms_service_mode = secure' /etc/ceph/ceph.conf
  grep -q 'ms_client_mode' /etc/ceph/ceph.conf || sed -i '/^\[global\]/a ms_client_mode = secure' /etc/ceph/ceph.conf
  chmod 640 /etc/ceph/ceph.conf
fi
# keyrings
for kr in /etc/ceph/*.keyring /etc/pve/priv/*.keyring; do
  [ -f "$kr" ] && [ "$DRY_RUN" != "1" ] && chmod 600 "$kr"
done
log "Ceph hardening termine"
exit 0