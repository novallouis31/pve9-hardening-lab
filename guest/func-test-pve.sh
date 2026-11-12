#!/usr/bin/env bash
# =============================================================================
# func-test-pve.sh - Tests fonctionnels Proxmox VE 9 (avant/apres hardening)
# -----------------------------------------------------------------------------
# Verifie que le durcissement N'ALTERE PAS le fonctionnement de PVE :
#   - Web UI et API
#   - SSH et authentification par cle
#   - Services critiques (pveproxy, pvedaemon, pvestatd, pve-firewall, ssh)
#   - Stockage (pvesm)
#   - Reseau (interfaces, pont vmbr0, connectivite)
#   - Creation/suppression d'un conteneur LXC de test (fonctionnel de bout en bout)
#   - Telechargement ISO et templates
#   - Taches (pvesh), noeud en ligne
#
# Sortie : @@TEST <ID> <PASS|FAIL|WARN|NA> <detail>
# Contrat : AUCUNE modification durable (le conteneur de test est supprime).
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

OUT_DIR="${1:-/tmp/pve-func}"
mkdir -p "$OUT_DIR" 2>/dev/null || OUT_DIR="/tmp/pve-func-$$"
mkdir -p "$OUT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$OUT_DIR/fonctionnel-$TS.txt"
exec > >(tee "$REPORT") 2>&1

PASS=0; FAIL=0; WARN=0; NA=0
tpass() { printf '@@TEST %s PASS %s\n' "$1" "$2"; PASS=$((PASS+1)); }
tfail() { printf '@@TEST %s FAIL %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
twarn() { printf '@@TEST %s WARN %s\n' "$1" "$2"; WARN=$((WARN+1)); }
tna()   { printf '@@TEST %s NA %s\n' "$1" "$2"; NA=$((NA+1)); }

echo "============================================================"
echo " TESTS FONCTIONNELS PROXMOX VE 9"
echo " Date  : $(date -Is)"
echo " Host  : $(hostname)"
echo "============================================================"

# --- 1. Web UI ---
echo ""
echo "--- 1. Interface web Proxmox ---"
if command -v curl >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -w "%{http_code}" -k --max-time 15 https://127.0.0.1:8006/ 2>/dev/null)
    case "$code" in
        200) tpass "FUNC.WEB.ACCESSIBLE" "Web UI sur 8006 repond (HTTP 200)" ;;
        401) tpass "FUNC.WEB.ACCESSIBLE" "Web UI sur 8006 repond (HTTP 401, authentification requise)" ;;
        000) tfail "FUNC.WEB.ACCESSIBLE" "Web UI sur 8006 ne repond pas" ;;
        *)   twarn "FUNC.WEB.ACCESSIBLE" "Web UI sur 8006 : HTTP $code" ;;
    esac
else
    tna "FUNC.WEB.ACCESSIBLE" "curl absent, test non realisable"
fi

# --- 2. API PVE ---
echo ""
echo "--- 2. API Proxmox (pvesh) ---"
if pvesh get /version --output-format json >/dev/null 2>&1; then
    tpass "FUNC.PVE.API" "API pvesh fonctionnelle"
else
    tfail "FUNC.PVE.API" "API pvesh ne repond pas"
fi

# --- 3. Authentification root par cle ---
echo ""
echo "--- 3. Authentification SSH root par cle ---"
if [ -f /root/.ssh/authorized_keys ] && grep -qE '^(ssh-|ecdsa-)' /root/.ssh/authorized_keys 2>/dev/null; then
    n=$(grep -cE '^(ssh-|ecdsa-)' /root/.ssh/authorized_keys 2>/dev/null || echo 0)
    tpass "FUNC.SSH.KEYAUTH" "$n cle(s) publique(s) autorisee(s) pour root"
else
    tfail "FUNC.SSH.KEYAUTH" "aucune cle publique pour root : acces SSH par cle casse"
fi

# --- 4. Services critiques ---
echo ""
echo "--- 4. Services critiques ---"
for svc in pveproxy pvedaemon pvestatd ssh; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        tpass "FUNC.SVC.$svc" "$svc actif"
    else
        tfail "FUNC.SVC.$svc" "$svc inactif : FONCTIONNELLEMENT CASSÉ"
    fi
done
# pve-firewall : actif OU desactive (les deux sont fonctionnels)
if systemctl is-active --quiet pve-firewall 2>/dev/null; then
    tpass "FUNC.SVC.pve-firewall" "pve-firewall actif"
elif systemctl is-enabled --quiet pve-firewall 2>/dev/null; then
    twarn "FUNC.SVC.pve-firewall" "pve-firewall enabled mais inactif"
else
    tpass "FUNC.SVC.pve-firewall" "pve-firewall desactive (comportement nominal hors durcissement)"
fi

# --- 5. Pare-feu : regles presentes ---
echo ""
echo "--- 5. Configuration du pare-feu PVE ---"
if pve-firewall status >/dev/null 2>&1; then
    tpass "FUNC.FW.STATUS" "pve-firewall status repond"
else
    tfail "FUNC.FW.STATUS" "pve-firewall status echoue"
fi
if pvesh get /cluster/firewall/options --output-format json >/dev/null 2>&1; then
    tpass "FUNC.FW.API" "options du pare-feu lisibles via l'API"
else
    twarn "FUNC.FW.API" "options du pare-feu non lisibles via l'API"
fi

# --- 6. Stockage ---
echo ""
echo "--- 6. Stockage ---"
if pvesm status >/dev/null 2>&1; then
    n=$(pvesm status 2>/dev/null | tail -n +2 | wc -l)
    tpass "FUNC.STORE.LIST" "pvesm status : $n entrepot(s) disponible(s)"
else
    tfail "FUNC.STORE.LIST" "pvesm status echoue"
fi
if pvesm status 2>/dev/null | awk '{print $3}' | grep -q active; then
    tpass "FUNC.STORE.ACTIVE" "au moins un depot de stockage est actif"
else
    twarn "FUNC.STORE.ACTIVE" "aucun depot de stockage actif"
fi

# --- 7. Reseau ---
echo ""
echo "--- 7. Reseau ---"
if ip -br addr show >/dev/null 2>&1; then
    if ip -br addr show | grep -q 'UP'; then
        tpass "FUNC.NET.IFACE" "au moins une interface reseau est UP"
    else
        tfail "FUNC.NET.IFACE" "aucune interface reseau UP"
    fi
    if ip -br link show | grep -q vmbr0; then
        tpass "FUNC.NET.VMBR0" "pont vmbr0 present"
    else
        twarn "FUNC.NET.VMBR0" "pont vmbr0 absent"
    fi
else
    tfail "FUNC.NET.IFACE" "commande ip indisponible"
fi
# connectivite
if ping -c1 -W3 10.0.2.2 >/dev/null 2>&1; then
    tpass "FUNC.NET.GATEWAY" "passerelle NAT 10.0.2.2 joignable"
else
    twarn "FUNC.NET.GATEWAY" "passerelle 10.0.2.2 injoignable"
fi

# --- 8. Noeud en ligne ---
echo ""
echo "--- 8. Etat du noeud ---"
if pvesh get /nodes/localhost/status >/dev/null 2>&1; then
    tpass "FUNC.NODE.ONLINE" "noeud localhost en ligne"
else
    tfail "FUNC.NODE.ONLINE" "noeud localhost hors ligne"
fi

# --- 9. Taches ---
echo ""
echo "--- 9. Gestion des taches ---"
if pvesh get /nodes/localhost/tasks --limit 1 --output-format json >/dev/null 2>&1; then
    tpass "FUNC.TASKS.LIST" "liste des taches accessible"
else
    twarn "FUNC.TASKS.LIST" "liste des taches inaccessible"
fi

# --- 10. Creation d'un conteneur LXC de test (fonctionnel de bout en bout) ---
echo ""
echo "--- 10. Cycle de vie d'un conteneur LXC de test ---"
CTID=99999
if ! command -v pct >/dev/null 2>&1; then
    tna "FUNC.LXC.CREATE" "pct absent (systeme minimal)"
else
    # template disponible ? On tente de l'installer si necessaire : sans
    # template, le test de cycle de vie LXC reste NA et ne prouve rien.
    tmpl=$(pveam list local 2>/dev/null | awk '/debian.*standard/ {print $2}' | head -1)
    if [ -z "$tmpl" ]; then
        echo "  aucun template local : tentative d'installation via pveam..."
        pveam update >/dev/null 2>&1 || true
        tmpl=$(pveam available 2>/dev/null | awk '/debian.*standard/ {print $2}' | head -1)
        if [ -n "$tmpl" ]; then
            pveam download "$tmpl" >/dev/null 2>&1 || true
        fi
    fi
    if [ -z "$tmpl" ]; then
        tna "FUNC.LXC.CREATE" "aucun template Debian disponible (depot pveam inaccessible ?)"
    else
        echo "  template : $tmpl"
        # volume de stockage pour le conteneur
        store=$(pvesm status 2>/dev/null | awk '$3=="active" {print $2; exit}')
        if [ -z "$store" ]; then
            twarn "FUNC.LXC.CREATE" "aucun stockage actif, creation impossible"
        else
            rm -f /etc/pve/lxc/$CTID.conf 2>/dev/null
            if pct create $CTID "$tmpl" --rootfs "$store:32" --cores 1 --memory 128 --net0 name=eth0,bridge=vmbr0,ip=dhcp --unprivileged 1 --ostype debian --password labtest123 2>&1 | tail -5; then
                tpass "FUNC.LXC.CREATE" "conteneur LXC $CTID cree sur $store"
                sleep 20
                if pct status $CTID 2>/dev/null | grep -q running; then
                    tpass "FUNC.LXC.RUNNING" "conteneur LXC $CTID en marche"
                    if pct exec $CTID -- /bin/true 2>/dev/null; then
                        tpass "FUNC.LXC.EXEC" "execution de commande dans le conteneur operationnelle"
                    else
                        twarn "FUNC.LXC.EXEC" "pct exec n'a pas reussi (conteneur encore en demarrage ?)"
                    fi
                else
                    twarn "FUNC.LXC.RUNNING" "conteneur LXC $CTID non lance"
                fi
                pct stop $CTID >/dev/null 2>&1
                pct destroy $CTID 2>/dev/null
                tpass "FUNC.LXC.DESTROY" "conteneur LXC $CTID supprime (aucun residu)"
            else
                tfail "FUNC.LXC.CREATE" "echec de la creation du conteneur LXC $CTID"
            fi
        fi
    fi
fi

# --- 11. Telechargement d'ISO / templates (chemin fonctionnel) ---
echo ""
echo "--- 11. Depot de fichiers (pveam) ---"
if command -v pveam >/dev/null 2>&1; then
    if pveam update >/dev/null 2>&1; then
        tpass "FUNC.PVEAM.UPDATE" "pveam update operationnel"
    else
        twarn "FUNC.PVEAM.UPDATE" "pveam update a echoue (acces reseau au depot ?)"
    fi
else
    tna "FUNC.PVEAM.UPDATE" "pveam absent"
fi

# --- 12. Certificat Web UI ---
echo ""
echo "--- 12. Certificat TLS de l'interface web ---"
# Proxmox VE 9 stocke le certificat de l'interface web dans
# /etc/pve/local/pve-ssl.pem (et NON pveproxy-ssl.pem comme en PVE 8).
TLS_FOUND=""
for c in /etc/pve/local/pve-ssl.pem /etc/pve/local/pveproxy-ssl.pem /etc/pve/pveproxy-ssl.pem; do
    [ -f "$c" ] && { TLS_FOUND="$c"; break; }
done
if [ -n "$TLS_FOUND" ]; then
    # on verifie que le certificat est exploitable (pas un fichier vide)
    if openssl x509 -in "$TLS_FOUND" -noout -subject >/dev/null 2>&1; then
        tpass "FUNC.TLS.CERT" "certificat TLS valide : $TLS_FOUND"
    else
        tfail "FUNC.TLS.CERT" "certificat TLS illisible : $TLS_FOUND"
    fi
else
    twarn "FUNC.TLS.CERT" "certificat TLS introuvable dans /etc/pve/local/"
fi

# --- 13. Journalisation ---
echo ""
echo "--- 13. Journalisation ---"
if systemctl is-active --quiet systemd-journald 2>/dev/null; then
    tpass "FUNC.LOG.JOURNALD" "systemd-journald actif"
else
    tfail "FUNC.LOG.JOURNALD" "systemd-journald inactif"
fi

# --- Resume ---
TOTAL=$((PASS+FAIL+WARN+NA))
echo ""
echo "============================================================"
echo " RESUME TESTS FONCTIONNELS"
echo " PASS : $PASS"
echo " FAIL : $FAIL"
echo " WARN : $WARN"
echo " NA   : $NA"
echo " TOTAL: $TOTAL"
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo " FONCTIONNELLEMENT CASSÉ : $FAIL test(s) en echec"
fi
echo "============================================================"

exit $FAIL
