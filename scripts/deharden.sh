#!/usr/bin/env bash
# =============================================================================
# deharden.sh - Client bash pour de-harden un serveur Proxmox VE distant.
#
# -----------------------------------------------------------------------------
# Appelle le de-hardening sur un serveur Proxmox a distance, par son adresse
# IP et son mot de passe root (ou une cle SSH).
#
# Le script distant (guest/deharden-pve.sh) est copie sur le serveur puis
# execute. Tout est realise en bash + ssh/scp : aucune dependance Python.
#
# Usage :
#   ./deharden.sh --host 192.168.1.50 --password 'secret'
#   ./deharden.sh --host 10.0.0.5 --password 'secret' --dry-run
#   ./deharden.sh --host 10.0.0.5 --key ~/.ssh/id_ed25519
#   ./deharden.sh --host 10.0.0.5 --password 'secret' --script /chemin/deharden-pve.sh
#
# Securite :
#   - le mot de passe n'est jamais ecrit dans l'historique du shell distant
#     (il est passe via l'environnement SSHPASS ou askpass) ;
#   - la connexion se fait en mode non interactif ;
#   - le de-hardening distant peut lui-meme etre simule (--dry-run).
# =============================================================================
set -u
export LC_ALL=C

HOST=""
PORT=22
USER_NAME="root"
PASSWORD=""
KEY=""
SCRIPT=""
DRY_RUN=0
KEEP_PACKAGES=0
REPORT=""
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=15 -o PreferredAuthentications=password,publickey"

usage() {
    cat <<'EOF'
Usage : bash deharden.sh --host <ip> [--password <mdp> | --key <cle>] [options]

Requis :
  --host <ip|dns>        adresse du serveur Proxmox a de-hardener

Authentification (l'une des deux) :
  --password <mdp>        mot de passe root
  --key <chemin>          cle privee SSH

Options :
  --port <port>          port SSH (defaut 22)
  --user <nom>           utilisateur (defaut root)
  --script <chemin>      script distant a utiliser
                          (defaut : guest/deharden-pve.sh du depot)
  --dry-run              simule sur le serveur, ne modifie rien
  --keep-packages        conserve les paquets installes par le hardening
  --report <fichier>     rapport Markdown local (defaut : ./deharden-<hote>.md)
  --help                 cette aide

Le de-hardening retire les mesures de durcissement (SSH, PAM, sysctl, modules,
firewall, comptes, paquets) et restaure les fichiers depuis les sauvegardes
produites lors du durcissement (/root/hardening-backups/<horodatage>).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --host) HOST="$2"; shift ;;
        --port) PORT="$2"; shift ;;
        --user) USER_NAME="$2"; shift ;;
        --password) PASSWORD="$2"; shift ;;
        --key) KEY="$2"; shift ;;
        --script) SCRIPT="$2"; shift ;;
        --report) REPORT="$2"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        --keep-packages) KEEP_PACKAGES=1 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Option inconnue : $1" >&2; usage; exit 2 ;;
    esac
    shift
done

[ -n "$HOST" ] || { echo "L'option --host est obligatoire." >&2; usage; exit 2; }
if [ -z "$PASSWORD" ] && [ -z "$KEY" ]; then
    echo "Il faut --password ou --key." >&2
    usage
    exit 2
fi

command -v ssh >/dev/null 2>&1 || { echo "ssh introuvable." >&2; exit 2; }
command -v scp >/dev/null 2>&1 || { echo "scp introuvable." >&2; exit 2; }

# --- localisation du script distant ---------------------------------------
if [ -z "$SCRIPT" ]; then
    here="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
    for cand in "$here/deharden-pve.sh" "$here/../guest/deharden-pve.sh" "$here/../pve9-hardening-lab/guest/deharden-pve.sh"; do
        if [ -f "$cand" ]; then SCRIPT="$cand"; break; fi
    done
fi
[ -n "$SCRIPT" ] && [ -f "$SCRIPT" ] || {
    echo "Script distant introuvable (utilisez --script)." >&2
    exit 2
}
[ -n "$REPORT" ] || REPORT="./deharden-$(echo "$HOST" | tr ':.' '__').md"

# --- mot de passe : askpass (jamais en ligne de commande) ---------------
ASKPASS_SCRIPT=""
KEY_COPY=""
cleanup() {
    [ -n "$ASKPASS_SCRIPT" ] && rm -f "$ASKPASS_SCRIPT"
    [ -n "$KEY_COPY" ] && rm -f "$KEY_COPY"
    return 0
}
trap cleanup EXIT

if [ -n "$PASSWORD" ]; then
    ASKPASS_SCRIPT="$(mktemp)"
    chmod 700 "$ASKPASS_SCRIPT"
    cat > "$ASKPASS_SCRIPT" <<EOF
#!/bin/sh
printf '%s\n' '$PASSWORD'
EOF
    chmod 700 "$ASKPASS_SCRIPT"
    export SSH_ASKPASS="$ASKPASS_SCRIPT"
    export SSH_ASKPASS_REQUIRE=force
    export DISPLAY="${DISPLAY:-:0}"
fi

# --- authentification par cle : permissions SSH --------------------------
# SSH refuse une cle privee lisible par tous ("UNPROTECTED PRIVATE KEY
# FILE"). Sur un systeme de fichiers monte (/mnt/c sous WSL, /media sous
# Linux), les permissions sont forcees a 777 : on copie donc la cle dans
# un repertoire prive (~/.ssh) avant de l'utiliser.
KEY_COPY=""
if [ -n "$KEY" ]; then
    if [ ! -r "$KEY" ]; then
        echo "Cle introuvable ou illisible : $KEY" >&2
        exit 2
    fi
    KEY_DIR="${HOME}/.ssh"
    mkdir -p "$KEY_DIR" || { echo "Impossible de creer $KEY_DIR" >&2; exit 2; }
    chmod 700 "$KEY_DIR" 2>/dev/null || true
    KEY_COPY="$KEY_DIR/deharden_key_$$"
    if ! cp "$KEY" "$KEY_COPY" 2>/dev/null; then
        echo "Copie de la cle impossible vers $KEY_COPY" >&2
        exit 2
    fi
    chmod 600 "$KEY_COPY"
fi

SSH_CMD=(ssh $SSH_OPTS -p "$PORT" "${USER_NAME}@${HOST}")
if [ -n "$KEY_COPY" ]; then
    SSH_CMD=(ssh $SSH_OPTS -i "$KEY_COPY" -p "$PORT" "${USER_NAME}@${HOST}")
    SCP_CMD=(scp $SSH_OPTS -i "$KEY_COPY" -P "$PORT")
else
    SCP_CMD=(scp $SSH_OPTS -P "$PORT")
fi

echo "=== De-hardening de $HOST ==="
echo "  cible    : ${USER_NAME}@${HOST}:${PORT}"
echo "  script   : $SCRIPT"
echo "  mode     : $([ "$DRY_RUN" = "1" ] && echo 'simulation' || echo 'application')"

# --- 1. verifier la connectivite ----------------------------------------
echo ""
echo "--- 1. connectivite ---"
if ! "${SSH_CMD[@]}" 'echo CONNECTED && hostname' 2>/dev/null; then
    echo "  ECHEC : connexion SSH impossible sur ${HOST}:${PORT}" >&2
    echo "  Verifiez : le serveur est demarre, le port est correct, le mot de passe est valide." >&2
    exit 1
fi
"${SSH_CMD[@]}" 'hostname; cat /etc/pve/version 2>/dev/null || echo "(pas de Proxmox detecte)"' 2>/dev/null

# --- 2. verifier que c'est bien un noeud Proxmox -----------------------
echo ""
echo "--- 2. verification de la cible ---"
if ! "${SSH_CMD[@]}" 'test -d /etc/pve && echo PROXMOX_OK' 2>/dev/null | grep -q PROXMOX_OK; then
    echo "  ATTENTION : $HOST ne semble pas etre un noeud Proxmox (/etc/pve absent)." >&2
    echo "  Le de-hardening est specifique a Proxmox VE : abandon." >&2
    exit 1
fi
echo "  noeud Proxmox confirme"

# --- 3. transferer le script distant ------------------------------------
echo ""
echo "--- 3. transfert du script distant ---"
REMOTE_SCRIPT="/tmp/deharden-pve-$$.sh"
if ! "${SCP_CMD[@]}" "$SCRIPT" "${USER_NAME}@${HOST}:${REMOTE_SCRIPT}" 2>/dev/null; then
    echo "  ECHEC : copie du script impossible." >&2
    exit 1
fi
echo "  copie : $REMOTE_SCRIPT"

# --- 4. execution --------------------------------------------------------
echo ""
echo "--- 4. de-hardening ---"
REMOTE_ARGS=""
[ "$DRY_RUN" = "1" ] && REMOTE_ARGS="$REMOTE_ARGS --dry-run"
[ "$KEEP_PACKAGES" = "1" ] && REMOTE_ARGS="$REMOTE_ARGS --keep-packages"
REMOTE_REPORT="/tmp/deharden-report-$$.md"
REMOTE_ARGS="$REMOTE_ARGS --report $REMOTE_REPORT"

"${SSH_CMD[@]}" "chmod 700 '$REMOTE_SCRIPT' && bash '$REMOTE_SCRIPT'$REMOTE_ARGS; rc=\$?; rm -f '$REMOTE_SCRIPT'; exit \$rc"
RC=$?

# --- 5. recuperer le rapport ---------------------------------------------
echo ""
echo "--- 5. rapport ---"
mkdir -p "$(dirname "$REPORT")" 2>/dev/null || true
if "${SCP_CMD[@]}" "${USER_NAME}@${HOST}:${REMOTE_REPORT}" "$REPORT" 2>/dev/null; then
    echo "  rapport local : $REPORT"
else
    echo "  rapport non recupere (voir la sortie ci-dessus)" >&2
    [ -n "$REPORT" ] && rm -f "$REPORT" 2>/dev/null
fi
"${SSH_CMD[@]}" "rm -f '$REMOTE_REPORT'" 2>/dev/null

echo ""
if [ "$RC" = "0" ]; then
    echo "=== DE-HARDENDING TERMINE ==="
    exit 0
else
    echo "=== DE-HARDENDING ECHOUE (code $RC) ===" >&2
    exit "$RC"
fi
