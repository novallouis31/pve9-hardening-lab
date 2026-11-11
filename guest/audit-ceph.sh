#!/usr/bin/env bash
# audit-ceph.sh - controles Ceph (source par audit-pve.sh si AUDIT_EXTRA contient ceph)

sec "Ceph - configuration et durcissement"

# CEPH.PKG
if command -v ceph >/dev/null 2>&1; then chk CEPH.PKG PASS "ceph client installe"; else chk CEPH.PKG FAIL "ceph absent"; fi

# CEPH.CLUSTER : presence d'un cluster (ceph-mon)
if [ -x /usr/bin/ceph-mon ]; then chk CEPH.CLUSTER PASS "ceph-mon installe (cluster possible)"; else chk CEPH.CLUSTER NA "ceph-mon absent (pas de cluster local)"; fi

# CEPH.CONF : fichier de conf present
if [ -f /etc/ceph/ceph.conf ]; then chk CEPH.CONF PASS "/etc/ceph/ceph.conf present"; else chk CEPH.CONF FAIL "/etc/ceph/ceph.conf absent"; fi

# CEPH.AUTH.CEPHX : cephx active
if [ -f /etc/ceph/ceph.conf ] && grep -qi 'auth_cluster_required.*cephx\|auth_service_required.*cephx\|auth_client_required.*cephx' /etc/ceph/ceph.conf; then
    chk CEPH.AUTH.CEPHX PASS "cephx active dans ceph.conf"
else
    chk CEPH.AUTH.CEPHX FAIL "cephx non declare (ou conf absente)"
fi

# CEPH.MSGR2 : chiffrement msgr2
if [ -f /etc/ceph/ceph.conf ] && grep -qi 'ms_cluster_mode.*secure\|ms_service_mode.*secure\|ms_client_mode.*secure' /etc/ceph/ceph.conf; then
    chk CEPH.MSGR2 PASS "msgr2 en mode secure"
else
    chk CEPH.MSGR2 FAIL "msgr2 secure non declare"
fi

# CEPH.CONF.PERM
if [ -d /etc/ceph ]; then
    p=$(stat -c '%a' /etc/ceph 2>/dev/null)
    if [ "$p" = "750" ] || [ "$p" = "700" ]; then chk CEPH.CONF.PERM PASS "/etc/ceph mode=$p"; else chk CEPH.CONF.PERM FAIL "/etc/ceph mode=$p (attendu 750/700)"; fi
else
    chk CEPH.CONF.PERM NA "/etc/ceph absent"
fi

# CEPH.KEYRING.PERM
for kr in /etc/ceph/ceph.client.admin.keyring /etc/pve/priv/ceph.client.admin.keyring; do
    if [ -f "$kr" ]; then
        p=$(stat -c '%a' "$kr" 2>/dev/null)
        if [ "$p" = "600" ]; then chk CEPH.KEYRING.PERM PASS "$kr mode=$p"; else chk CEPH.KEYRING.PERM FAIL "$kr mode=$p (attendu 600)"; fi
    fi
done
if ! ls /etc/ceph/*.keyring /etc/pve/priv/*.keyring >/dev/null 2>&1; then
    chk CEPH.KEYRING.PERM NA "aucun keyring present"
fi

# CEPH.DASHBOARD
if systemctl is-active ceph-dashboard 2>/dev/null | grep -q active; then
    chk CEPH.DASHBOARD FAIL "dashboard actif (verifier l'authentification)"
else
    chk CEPH.DASHBOARD PASS "dashboard inactif"
fi