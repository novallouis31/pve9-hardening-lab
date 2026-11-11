#!/usr/bin/env bash
# =============================================================================
# bootstrap-sshkey.sh - installe une cle publique pour root sur un noeud PVE
# -----------------------------------------------------------------------------
# A coller dans le shell de la web UI Proxmox (Noeud -> Shell) quand la cle
# publique n'a pas encore pu etre injectee par scp.
#
# Usage :
#   bash bootstrap-sshkey.sh 'ssh-ed25519 AAAAC3Nz... user@host'
#   bash bootstrap-sshkey.sh --stdin < cle.pub
# =============================================================================
set -u

KEY="${1:-}"
if [ "$KEY" = "--stdin" ]; then
    KEY="$(cat)"
fi
KEY="$(printf '%s' "$KEY" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if ! printf '%s' "$KEY" | grep -qE '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp[0-9]+) '; then
    echo "ERREUR : la cle publique fournie n'a pas le format attendu." >&2
    echo "Exemple attendu : ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host" >&2
    exit 1
fi

mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Sur PVE, /root/.ssh/authorized_keys est un lien vers /etc/pve/priv/authorized_keys
# (partage avec les noeuds du cluster). On ecrit dans la cible reelle.
TARGET=/root/.ssh/authorized_keys
if [ -L "$TARGET" ]; then
    TARGET="$(readlink -f "$TARGET")"
fi

if grep -qF "$KEY" "$TARGET" 2>/dev/null; then
    echo "Cle deja presente dans $TARGET"
else
    printf '%s\n' "$KEY" >> "$TARGET"
    echo "Cle ajoutee dans $TARGET"
fi
chmod 600 "$TARGET"

# Verifie que la cle correspond bien a une ligne "type base64 commentaire"
echo "--- verification ---"
awk '{print NR": "$1" ... "$3}' "$TARGET"
echo
echo "Test depuis l'hote Windows :"
echo "  ssh -i .keys/id_ed25519 -p 2222 -o StrictHostKeyChecking=no root@127.0.0.1 'hostname; pveversion'"
