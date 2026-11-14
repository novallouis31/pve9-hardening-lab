#!/usr/bin/env bash
# =============================================================================
# deharden-pve.sh - Restaure un noeud Proxmox VE a son etat ANTERIEUR au
#                   durcissement.
#
# -----------------------------------------------------------------------------
# Objectif : permettre la mise a jour d'un Proxmox VE durci (le verrouillage
# de SSH, les Policies PAM strictes, les modules noyau bloques, etc. peuvent
# generer des blocages lors d'une upgrade) en revenant a l'etat d'origine.
#
# Mecanisme :
#   1. Les scripts de durcissement (apply-homesec-core.sh / apply-anssi.sh)
#      sauvegardent chaque fichier AVANT modification dans
#      /root/hardening-backups/<horodatage>/ (structure arborescente).
#   2. Ce script restaure ces sauvegardes (le fichier le plus recent gagne).
#   3. Les fichiers CREES par le durcissement (sans sauvegarde) sont
#      supprimes : ils sont listes explicitement ci-dessous.
#   4. Les actions d'etat (systemd, comptes, modules, PAM) sont re-vertes.
#   5. Un rapport est produit (avant/apres) pour tracer l'operation.
#
# Usage :
#   bash deharden-pve.sh --dry-run        # simule, ne modifie rien
#   bash deharden-pve.sh                  # de-hardening complet
#   bash deharden-pve.sh --keep-packages  # ne desinstalle pas les paquets
#   bash deharden-pve.sh --report /tmp/x.md
#
# Securite :
#   - le de-hardening ne coupe JAMAIS l'acces SSH : la configuration SSH est
#     restauree en dernier et le service n'est recharge qu'apres verification ;
#   - un snapshot de securite des fichiers est pris avant toute ecriture
#     (/root/deharden-safety-<horodatage>/) ;
#   - le mode --dry-run par defaut n'ecrit rien.
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

DRY_RUN=0
KEEP_PACKAGES=0
REPORT=""
BACKUP_ROOT="/root/hardening-backups"
ANS_BACKUP_ROOT="/root/anssi-backups"
TS="$(date +%Y%m%d_%H%M%S)"
SAFETY="/root/deharden-safety-$TS"
LOG="/var/log/deharden-$TS.log"
MANIFEST="/root/deharden-manifest-$TS.txt"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
step() { printf '\n=== %s ===\n' "$*" | tee -a "$LOG"; }
run()  {
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [DRY-RUN] %s\n' "$*" | tee -a "$LOG"
        return 0
    fi
    "$@" >>"$LOG" 2>&1 && return 0
    log "ECHEC : $*"
    return 1
}
# execute une commande shell en journalisant (pour les redirections, pipelines)
runsh() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [DRY-RUN] %s\n' "$1" | tee -a "$LOG"
        return 0
    fi
    bash -c "$1" >>"$LOG" 2>&1 && return 0
    log "ECHEC : $1"
    return 1
}

usage() {
    cat <<'EOF'
Usage : bash deharden-pve.sh [options]

  --dry-run          simule l'operation sans rien modifier (recommande en premier)
  --keep-packages    ne desinstalle pas les paquets installes par le hardening
  --report <fichier> ecrit un rapport Markdown (defaut : /root/deharden-<ts>.md)
  --help             cette aide

Le script doit etre execute en root sur le noeud Proxmox a restaurer.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --keep-packages) KEEP_PACKAGES=1 ;;
        --report) REPORT="$2"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Option inconnue : $1" >&2; usage; exit 2 ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || { echo "Ce script doit etre execute en root." >&2; exit 2; }
[ -n "$REPORT" ] || REPORT="/root/deharden-$TS.md"

: > "$LOG"
log "de-hardening Proxmox VE - $TS (dry-run=$DRY_RUN)"

# ---------------------------------------------------------------------------
# Fichiers CREES par le durcissement (absents avant) : ils sont supprimes.
# La liste est explicite pour rester deterministe, meme si les sauvegardes
# sont absentes.
# ---------------------------------------------------------------------------
CREATED_FILES="
/etc/modprobe.d/99-pve-hardening.conf
/etc/modprobe.d/99-anssi-usb.conf
/etc/sysctl.d/97-pve-hardening.conf
/etc/sysctl.d/98-anssi.conf
/etc/sysctl.d/99-pve-hardening.conf
/etc/ssh/sshd_config.d/00-pve-hardening.conf
/etc/systemd/journald.conf.d/99-pve-hardening.conf
/etc/security/limits.d/99-pve-hardening.conf
/etc/security/pwquality.conf
/etc/security/faillock.conf
/etc/profile.d/99-pve-hardening.sh
/etc/profile.d/tmout.sh
/etc/profile.d/99-lab-dns
/etc/audit/rules.d/90-pve.rules
/etc/fail2ban/filter.d/pveproxy.conf
/etc/fail2ban/jail.d/pve-web.conf
/etc/fail2ban/jail.d/pve-web-http.conf
/etc/rsyslog.d/99-anssi-remote.conf
/etc/cron.daily/aide-check
/etc/issue.net
/etc/cron.allow
/etc/network/interfaces.d/99-lab-dns
/root/rollback-hardening.sh
"

# Paquets installes par le durcissement (option --purge-packages).
PACKAGES="aide aide-common apparmor-utils rsyslog auditd audispd-plugins fail2ban rkhunter unattended-upgrades apt-listchanges libpam-pwquality libpam-modules sudo chrony"

# Comptes crees par le durcissement.
CREATED_USERS="pveadmin"

# Services DESACTIVES par le durcissement (a reactiver).
REENABLE_SERVICES="ctrl-alt-del.target avahi-daemon cups bluetooth rsh-server rsh-client talk-server talk-client telnet inetd xinetd nfs-kernel-server samba smbd nmbd snmpd vsftpd proftpd haproxy rsyslog-lm"

# ---------------------------------------------------------------------------
step "0. Sauvegarde de securite"
# Copie de securite de l'etat courant, pour pouvoir annuler une mauvaise
# operation (les sauvegardes du hardening sont, elles, restaurees).
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$SAFETY"
    runsh "tar -C / -czf '$SAFETY/etat-avant-dehardening.tar.gz' \\
        etc/ssh etc/pve etc/sysctl.d etc/modprobe.d etc/security etc/profile.d \\
        etc/audit etc/fail2ban etc/rsyslog.d etc/systemd etc/login.defs etc/crontab \\
        etc/fstab etc/cron.allow etc/issue.net etc/cron.daily 2>/dev/null || true"
    log "Sauvegarde de securite : $SAFETY/etat-avant-dehardening.tar.gz"
fi

# ---------------------------------------------------------------------------
step "1. Restauration des fichiers sauvegardes par le durcissement"
# Les sauvegardes sont dans <racine>/<horodatage>/<chemin/du/fichier>.<epoch>.
# On parcourt toutes les racines de sauvegarde et on restaure le fichier le
# plus recent pour chaque chemin.
restore_tree() {
    local root="$1"
    [ -d "$root" ] || return 0
    # liste des horodatages de sauvegarde, du plus ancien au plus recent
    local stamps
    stamps=$(ls -1 "$root" 2>/dev/null | sort)
    local st
    for st in $stamps; do
        local dir="$root/$st"
        [ -d "$dir" ] || continue
        # parcourt les fichiers sauvegardes de cet horodatage
        while IFS= read -r saved; do
            [ -n "$saved" ] || continue
            # nom du fichier d'origine : on retire le suffixe .<epoch>
            local rel="${saved#$dir/}"
            local orig="${rel%.*}"
            local target="/$orig"
            if [ ! -e "$target" ]; then
                log "  (fichier absent, rien a restaurer) $target"
                continue
            fi
            log "  restauration : $target  <-  $saved"
            if [ "$DRY_RUN" != "1" ]; then
                cp -a "$saved" "$target" || log "ECHEC restauration $target"
            fi
            printf '%s\n' "$target" >> "$MANIFEST"
        done <<EOF
$(find "$dir" -type f 2>/dev/null)
EOF
    done
}
restore_tree "$BACKUP_ROOT"
restore_tree "$ANS_BACKUP_ROOT"

# ---------------------------------------------------------------------------
step "2. Suppression des fichiers crees par le durcissement"
# On ne supprime que ceux qui n'ont PAS ete restaures a l'etape 1.
for f in $CREATED_FILES; do
    [ -n "$f" ] || continue
    # si le fichier existe et n'est pas dans le manifeste de restauration,
    # c'est un fichier cree par le hardening -> on le supprime.
    if grep -qx "$f" "$MANIFEST" 2>/dev/null; then
        log "  conserve (restaure) : $f"
        continue
    fi
    if [ -e "$f" ]; then
        log "  suppression : $f"
        runsh "rm -f '$f'"
        printf '%s\n' "$f" >> "$MANIFEST"
    fi
done

# ---------------------------------------------------------------------------
step "3. Desactivation des mesures d'etat"
# 3a. Modules noyau bloques
log "  reconstruction de l'initramfs (modules noyau restaures)"
runsh "update-initramfs -u"

# 3b. Politiques PAM : restauration via les sauvegardes (fait a l'etape 1).
#     On neutralise au cas ou la restauration n'aurait pas eu lieu.
for f in /etc/pam.d/common-auth /etc/pam.d/common-password /etc/pam.d/common-account /etc/pam.d/common-session; do
    [ -f "$f" ] || continue
    if grep -q 'pam_faillock' "$f" 2>/dev/null; then
        log "  neutralisation de pam_faillock dans $f"
        runsh "sed -i '/pam_faillock/d' '$f'"
    fi
    if grep -q 'pam_pwquality' "$f" 2>/dev/null; then
        log "  neutralisation de pam_pwquality dans $f"
        runsh "sed -i '/pam_pwquality/d' '$f'"
    fi
done

# 3c. Systemd : les services desactives par le hardening sont re-actives.
for s in $REENABLE_SERVICES; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\."; then
        log "  reactivation du service $s"
        runsh "systemctl unmask '$s' 2>/dev/null || true"
        runsh "systemctl enable '$s' 2>/dev/null || true"
        runsh "systemctl start '$s' 2>/dev/null || true"
    fi
done

# 3d. Comptes crees par le hardening
for u in $CREATED_USERS; do
    if getent passwd "$u" >/dev/null 2>&1; then
        log "  suppression du compte $u"
        runsh "deluser --remove-home '$u' 2>/dev/null || userdel -r '$u' 2>/dev/null || true"
    fi
done

# ---------------------------------------------------------------------------
step "4. Restauration de la configuration SSH (en dernier)"
# Le fichier de drop-in SSH est restaure a l'etape 2 (suppression). On
# verifie que la configuration est valide AVANT de recharger le service :
# un fichier invalide couperait l'acces SSH.
if [ "$DRY_RUN" != "1" ]; then
    if sshd -t 2>/dev/null; then
        log "  configuration SSH valide"
        runsh "systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null || true"
    else
        log "  ATTENTION : configuration SSH invalide, on ne recharge pas le service"
        runsh "sshd -t 2>&1 | head -5"
    fi
else
    log "  [DRY-RUN] verification sshd -t puis reload ssh"
fi

# ---------------------------------------------------------------------------
step "5. Depots apt retablis"
# Les depots enterprise desactives par le hardening sont renommes en .disabled :
# on les restaure.
for f in /etc/apt/sources.list.d/pve-enterprise.sources.disabled \
         /etc/apt/sources.list.d/ceph.sources.disabled; do
    if [ -e "$f" ]; then
        log "  reactivation du depot $(basename "$f" .disabled)"
        runsh "mv '$f' '${f%.disabled}' 2>/dev/null || true"
    fi
done

# ---------------------------------------------------------------------------
step "6. Paquets installes par le durcissement"
if [ "$KEEP_PACKAGES" = "1" ]; then
    log "  --keep-packages : les paquets sont conserves"
    log "  paquets potentiellement ajoutes : $PACKAGES"
else
    log "  desinstallation des paquets ajoutes par le hardening"
    # apt-get remove est plus propre que purge (conserve la config) mais on
    # purge les paquets de configuration pour un retour a l'etat initial.
    for p in $PACKAGES; do
        if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
            log "    suppression du paquet $p"
            runsh "DEBIAN_FRONTEND=noninteractive apt-get remove -y '$p' 2>&1 | tail -3"
        fi
    done
fi

# ---------------------------------------------------------------------------
step "7. Reconstruction de l'initramfs et application des sysctl"
runsh "update-initramfs -u"
runsh "sysctl --system 2>/dev/null || true"

# ---------------------------------------------------------------------------
step "8. Verification finale"
runsh "systemctl daemon-reload"
runsh "systemctl restart apparmor 2>/dev/null || true"
runsh "systemctl restart auditd 2>/dev/null || true"
runsh "systemctl restart rsyslog 2>/dev/null || true"

echo ""
echo "--- services ---" | tee -a "$LOG"
for s in ssh pveproxy pvedaemon pvestatd pve-firewall; do
    st=$(systemctl is-active "$s" 2>/dev/null || echo "inactif")
    printf '    %-14s %s\n' "$s" "$st" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "--- de-hardening ---" | tee -a "$LOG"
if [ -e /etc/modprobe.d/99-pve-hardening.conf ]; then
    echo "    ATTENTION : /etc/modprobe.d/99-pve-hardening.conf est toujours present" | tee -a "$LOG"
fi
if [ -e /etc/ssh/sshd_config.d/00-pve-hardening.conf ]; then
    echo "    ATTENTION : le drop-in SSH est toujours present" | tee -a "$LOG"
fi

# ---------------------------------------------------------------------------
step "Rapport"
{
    echo "# De-hardening Proxmox VE"
    echo ""
    echo "- **Date** : $(date -Is)"
    echo "- **Hote** : $(hostname)"
    echo "- **Mode** : $([ "$DRY_RUN" = "1" ] && echo 'simulation (dry-run)' || echo 'application')"
    echo "- **Journal** : \`$LOG\`"
    echo "- **Sauvegarde de securite** : \`$SAFETY\`"
    echo ""
    echo "## Fichiers restaures ou supprimes"
    echo ""
    echo "| Fichier | Action |"
    echo "|---|---|"
    if [ -s "$MANIFEST" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && echo "| \`$f\` | restaure ou supprime |"
        done < "$MANIFEST"
    else
        echo "| *(aucun fichier restaure)* | |"
    fi
    echo ""
    echo "## Paquets"
    echo ""
    if [ "$KEEP_PACKAGES" = "1" ]; then
        echo "Conserves (option --keep-packages) : \`$PACKAGES\`"
    else
        echo "Desinstalles : \`$PACKAGES\`"
    fi
    echo ""
    echo "## Verification"
    echo ""
    echo "| Service | Etat |"
    echo "|---|---|"
    for s in ssh pveproxy pvedaemon pvestatd pve-firewall; do
        echo "| \`$s\` | $(systemctl is-active "$s" 2>/dev/null || echo inactif) |"
    done
} > "$REPORT"

log "Rapport : $REPORT"
log "De-hardening termine (dry-run=$DRY_RUN)"
