#!/usr/bin/env bash
# =============================================================================
# audit-ceph.sh - Controles Ceph (configuration PVE 9 / guide HomeSecExplorer)
# -----------------------------------------------------------------------------
# References :
#   - Guide PVE 9 § 3.4 / 3.5 (OSD encryption, messenger in-flight encryption)
#   - Clefs de configuration Ceph (ms_bind_msgr2, ms_encrypt, ms_*_mode)
#   - Documentation Ceph : cephx, keyring, dashboard, pool
#
# Contrat de sortie : @@CHECK <ID> <PASS|FAIL|NA|INFO> <detail>
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

sec "Ceph - configuration et durcissement"

CONF=/etc/ceph/ceph.conf

# --- Presence du client Ceph -------------------------------------------------
if command -v ceph >/dev/null 2>&1; then
    chk "CEPH.PKG" PASS "client ceph installe"
else
    chk "CEPH.PKG" FAIL "client ceph absent"
fi

# --- Cluster deploye ? ------------------------------------------------------
if [ -x /usr/bin/ceph-mon ] || systemctl list-unit-files 2>/dev/null | grep -q 'ceph-mon'; then
    if systemctl is-active --quiet ceph-mon 2>/dev/null; then
        chk "CEPH.CLUSTER" PASS "cluster Ceph operationnel (mon actif)"
    else
        chk "CEPH.CLUSTER" FAIL "ceph-mon present mais inactif"
    fi
else
    chk "CEPH.CLUSTER" NA "aucun cluster Ceph sur ce noeud (mode client seul)"
fi

# --- Fichier de configuration ------------------------------------------------
if [ -f "$CONF" ]; then
    chk "CEPH.CONF" PASS "$CONF present"
else
    chk "CEPH.CONF" FAIL "$CONF absent"
fi

# --- cephx : authentification obligatoire ------------------------------------
# CIS/Guide : auth_client_required / auth_cluster_required / auth_service_required
if [ -f "$CONF" ]; then
    missing=""
    for k in auth_client_required auth_cluster_required auth_service_required; do
        grep -qE "^[[:space:]]*${k}[[:space:]]*=[[:space:]]*cephx" "$CONF" || missing="$missing $k"
    done
    if [ -z "$missing" ]; then
        chk "CEPH.AUTH.CEPHX" PASS "cephx exige pour client/cluster/service"
    else
        chk "CEPH.AUTH.CEPHX" FAIL "cephx non declare pour :$missing"
    fi
else
    chk "CEPH.AUTH.CEPHX" FAIL "cephx non verifiable (conf absente)"
fi

# --- Chiffrement en transit (msgr2) ------------------------------------------
# Guide PVE 9 § 3.5 : ms_bind_msgr2 + ms_encrypt + modes secure
if [ -f "$CONF" ]; then
    miss=""
    grep -qE '^[[:space:]]*ms_bind_msgr2[[:space:]]*=[[:space:]]*true' "$CONF" || miss="$miss ms_bind_msgr2"
    grep -qE '^[[:space:]]*ms_encrypt[[:space:]]*=[[:space:]]*true' "$CONF" || miss="$miss ms_encrypt"
    for m in ms_cluster_mode ms_service_mode ms_client_mode; do
        grep -qE "^[[:space:]]*${m}[[:space:]]*=[[:space:]]*secure" "$CONF" || miss="$miss $m"
    done
    if [ -z "$miss" ]; then
        chk "CEPH.MSGR2" PASS "chiffrement msgr2 actif (bind+encrypt+modes secure)"
    else
        chk "CEPH.MSGR2" FAIL "chiffrement msgr2 incomplet :$miss"
    fi
else
    chk "CEPH.MSGR2" FAIL "chiffrement msgr2 non verifiable (conf absente)"
fi

# --- Permissions de /etc/ceph -----------------------------------------------
if [ -d /etc/ceph ]; then
    p=$(stat -c '%a' /etc/ceph 2>/dev/null)
    if [ "$p" = "750" ] || [ "$p" = "700" ]; then
        chk "CEPH.CONF.PERM" PASS "/etc/ceph en $p"
    else
        chk "CEPH.CONF.PERM" FAIL "/etc/ceph en ${p:-?} (attendu 750/700)"
    fi
else
    chk "CEPH.CONF.PERM" NA "/etc/ceph absent"
fi

# --- Permissions des keyrings (secrets) --------------------------------------
kr_ok=0; kr_bad=0
for kr in /etc/ceph/*.keyring /etc/pve/priv/*.keyring; do
    [ -f "$kr" ] || continue
    p=$(stat -c '%a' "$kr" 2>/dev/null)
    if [ "$p" = "600" ] || [ "$p" = "400" ]; then kr_ok=$((kr_ok+1)); else kr_bad=$((kr_bad+1)); fi
done
if [ $((kr_ok + kr_bad)) -gt 0 ]; then
    if [ "$kr_bad" -eq 0 ]; then
        chk "CEPH.KEYRING.PERM" PASS "$kr_ok keyring(s) en 600/400"
    else
        chk "CEPH.KEYRING.PERM" FAIL "$kr_bad keyring(s) avec permissions trop larges"
    fi
else
    chk "CEPH.KEYRING.PERM" NA "aucun keyring present"
fi

# --- Dashboard Ceph ---------------------------------------------------------
if systemctl list-unit-files 2>/dev/null | grep -q 'ceph-dashboard'; then
    if systemctl is-active --quiet ceph-dashboard 2>/dev/null; then
        # Verifier que SSL est actif
        if grep -qsE '^[[:space:]]*ssl[[:space:]]*=[[:space:]]*true' /etc/ceph/ceph.conf 2>/dev/null; then
            chk "CEPH.DASHBOARD" FAIL "dashboard actif (SSL active, verifier MFA/RBAC)"
        else
            chk "CEPH.DASHBOARD" FAIL "dashboard actif SANS SSL : interception possible"
        fi
    else
        chk "CEPH.DASHBOARD" PASS "dashboard inactif"
    fi
else
    chk "CEPH.DASHBOARD" NA "ceph-dashboard non installe (pas de cluster)"
fi

# --- Chiffrement des OSD (Guide § 3.4) ---------------------------------------
if [ -f "$CONF" ]; then
    if grep -qE '^[[:space:]]*osd_encrypt[[:space:]]*=[[:space:]]*true' "$CONF" 2>/dev/null; then
        chk "CEPH.OSD.ENCRYPT" PASS "chiffrement des OSD declare"
    else
        chk "CEPH.OSD.ENCRYPT" INFO "chiffrement OSD non declare dans ceph.conf (option a l'creation de l'OSD)"
    fi
else
    chk "CEPH.OSD.ENCRYPT" NA "ceph.conf absent"
fi

# --- Pools : replication et min_size (Guide § 3.3) --------------------------
if command -v ceph >/dev/null 2>&1 && ceph status >/dev/null 2>&1; then
    pools=$(ceph osd pool ls detail 2>/dev/null | grep -c 'size')
    chk "CEPH.POOL.SIZING" INFO "$pools pool(s) detecte(s) (verifier size/min_size selon la tolerance de panne)"
else
    chk "CEPH.POOL.SIZING" NA "cluster Ceph injoignable (pas de pool a verifier)"
fi

# --- mgr : modules inutiles desactives --------------------------------------
if systemctl is-active --quiet ceph-mgr 2>/dev/null; then
    mods=$(ceph mgr module ls 2>/dev/null | grep -c 'enabled')
    chk "CEPH.MGR.MODULES" INFO "$mods module(s) mgr actif(s) (desactiver les modules non necessaires)"
else
    chk "CEPH.MGR.MODULES" NA "ceph-mgr inactif"
fi

# (pas de 'exit' : ce fichier est SOURCЕ par audit-pve.sh, un exit tuerait le script parent)
