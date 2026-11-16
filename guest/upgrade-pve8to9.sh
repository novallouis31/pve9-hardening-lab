#!/usr/bin/env bash
# =============================================================================
# upgrade-pve8to9.sh - Montee de version Proxmox VE 8 (Debian 12) -> 9 (Debian 13)
#
# A executer SUR le noeud, une fois le de-hardening realise : le noeud doit etre
# revenu a son etat d'origine pour que la montee de version ne soit pas bloquee
# par les mesures de durcissement (SSH restreint, depots desactives, etc.).
#
# Procedure officielle Proxmox :
#   1. sauvegarde de l'etat (/etc/pve, reseau, apt, noyau)
#   2. bascule des depots Debian bookworm -> trixie
#   3. depot PVE 9 pve-no-subscription (trixie) ; depots enterprise desactives
#   4. verification pve8to9 --full
#   5. apt dist-upgrade (configuration existante conservee)
#   6. controle apres montee de version
#
# Le redemarrage n'est PAS automatique : il doit etre fait par l'operateur
# (dans le lab, par un arret puis un demarrage a froid de la VM).
#
# Usage : ./upgrade-pve8to9.sh [--dry-run]
# =============================================================================
set -u

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "argument inconnu : $arg" >&2; exit 2 ;;
    esac
done

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="/root/pre-upgrade-${TS}.tar.gz"

step() { printf '\n=== %s ===\n' "$*"; }
info() { printf '  %s\n' "$*"; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  [dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

# --------------------------------------------------------------- 0. controles
step "0. Controles prealables"
if [ "$(id -u)" -ne 0 ]; then
    echo "  ce script doit etre lance en root" >&2
    exit 1
fi

PVE_VER="$(pveversion 2>/dev/null | sed -n 's|pve-manager/\([0-9][0-9.]*\)/.*|\1|p')"
info "version PVE : ${PVE_VER:-inconnue}"
case "$PVE_VER" in
    8.*) : ;;
    9.*) echo "  deja en PVE 9 : rien a faire" ; exit 0 ;;
    *)   echo "  version non reconnue ou pve-manager absent" >&2; exit 1 ;;
esac

if [ -e /etc/sysctl.d/97-pve-hardening.conf ] || [ -e /etc/sysctl.d/98-anssi.conf ]; then
    echo "  ATTENTION : fichiers de durcissement encore presents." >&2
    echo "  Lancez d'abord le de-hardening (scripts/deharden.sh)." >&2
    exit 1
fi

DEB_CODENAME="$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-inconnu}")"
info "base Debian : ${DEB_CODENAME}"
if [ "$DEB_CODENAME" != "bookworm" ]; then
    echo "  base inattendue (bookworm attendu) : arret" >&2
    exit 1
fi

info "espace disque :"
df -h / | tail -1 | sed 's/^/    /'

# -------------------------------------------------------------- 1. sauvegarde
step "1. Sauvegarde de l'etat avant montee de version"
if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] tar czf $BACKUP /etc/pve /etc/network/interfaces /etc/apt /etc/fstab /etc/default/grub"
else
    tar czf "$BACKUP" \
        /etc/pve /etc/network/interfaces /etc/apt /etc/fstab /etc/default/grub \
        2>/dev/null || true
    info "archive : $BACKUP ($(du -h "$BACKUP" 2>/dev/null | cut -f1))"
fi

# ------------------------------------------------------------ 2. depots Debian
step "2. Bascule des depots Debian bookworm -> trixie"
if [ -f /etc/apt/sources.list ]; then
    cp -a /etc/apt/sources.list "/etc/apt/sources.list.bak-${TS}"
    run sed -i 's/\bbookworm-updates\b/trixie-updates/g; s/\bbookworm-security\b/trixie-security/g; s/\bbookworm\b/trixie/g' \
        /etc/apt/sources.list
    info "sources.list :"
    sed 's/^/    /' /etc/apt/sources.list
fi
for f in /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] || continue
    cp -a "$f" "${f}.bak-${TS}"
    run sed -i 's/\bbookworm\b/trixie/g' "$f"
    info "deb822 converti : $f"
done

# ------------------------------------------------------- 3. depots Proxmox 9
step "3. Depots Proxmox VE 9"
for f in /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.sources; do
    if [ -e "$f" ]; then
        run mv "$f" "${f}.disabled"
        info "depot enterprise desactive : $f"
    fi
done
for f in /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.sources; do
    if [ -e "$f" ]; then
        run mv "$f" "${f}.disabled"
        info "depot Ceph enterprise desactive : $f"
    fi
done

PVE_LIST=/etc/apt/sources.list.d/pve9-no-subscription.list
if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] ecriture de $PVE_LIST (trixie pve-no-subscription)"
else
    printf 'deb http://download.proxmox.com/debian/pve trixie pve-no-subscription\n' > "$PVE_LIST"
    info "$PVE_LIST :"
    sed 's/^/    /' "$PVE_LIST"
fi

step "4. Mise a jour de l'index des paquets"
run apt-get update --allow-releaseinfo-change 2>&1 | tail -12

# ----------------------------------------------------------- 5. verification
step "5. Verification pve8to9"
if command -v pve8to9 >/dev/null 2>&1; then
    run pve8to9 --full 2>&1 | tail -40
else
    info "pve8to9 absent : ignore (outil fourni par pve-manager >= 8.1)"
fi

# -------------------------------------------------------------- 6. montee
step "6. Montee de version (dist-upgrade)"
if [ "$DRY_RUN" -eq 1 ]; then
    apt-get -s dist-upgrade 2>&1 | tail -25
    info "[dry-run] simulation seulement, aucune modification appliquee"
else
    apt-get -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        dist-upgrade 2>&1 | tail -45
    info "code de retour apt : $?"
fi

# -------------------------------------------------------------- 7. controles
step "7. Etat apres montee de version"
info "noyaux installes :"
ls /boot/vmlinuz-* 2>/dev/null | sed 's/^/    /'
info "version active :"
uname -r | sed 's/^/    /'
info "paquets principaux :"
dpkg-query -W -f='    ${Package} ${Version}\n' proxmox-ve pve-manager 2>/dev/null

step "8. Redemarrage"
info "un arret puis un demarrage (a froid) est necessaire pour amorcer"
info "sur le noyau ${PVE_VER} -> 9. Dans le lab :"
info "  VBoxManage controlvm <vm> acpipowerbutton"
info "  VBoxManage startvm <vm> --type headless"
