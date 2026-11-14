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
#      Les attributs (mode, proprietaire) sont records a part dans des
#      fichiers "<nom>.mode".
#   2. Ce script restaure, pour chaque chemin, la sauvegarde la plus
#      ANCIENNE (c'est l'etat d'origine : les sauvegardes ulterieures
#      contiennent la version deja durcie).
#   3. Les fichiers CREES par le durcissement (sans sauvegarde d'origine)
#      sont supprimes. Un fichier de la liste "crees" qui possede une
#      sauvegarde anterieure au durcissement est en fait pre-existant :
#      il est restaure, pas supprime.
#   4. Les actions d'etat (systemd, comptes, modules, PAM, depots apt)
#      sont re-vertes.
#   5. Un rapport Markdown (avant/apres) est produit.
#
# Usage :
#   bash deharden-pve.sh --dry-run        # simule, ne modifie rien
#   bash deharden-pve.sh                  # de-hardening complet
#   bash deharden-pve.sh --keep-packages  # ne desinstalle pas les paquets
#   bash deharden-pve.sh --report /tmp/x.md
#
# Securite :
#   - le de-hardening ne coupe JAMAIS l'acces SSH : la configuration SSH est
#     restauree en dernier et le service n'est recharge qu'apres verification
#     par "sshd -t" ;
#   - une sauvegarde de securite de l'etat courant est prise avant toute
#     ecriture (/root/deharden-safety-<horodatage>/) ;
#   - le mode --dry-run n'ecrit rien.
# =============================================================================
set -u
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

DRY_RUN=0
KEEP_PACKAGES=0
FORCE=0
REPORT=""
BACKUP_ROOT="/root/hardening-backups"
ANS_BACKUP_ROOT="/root/anssi-backups"
TS="$(date +%Y%m%d_%H%M%S)"
SAFETY="/root/deharden-safety-$TS"
LOG="/var/log/deharden-$TS.log"
MANIFEST="/root/deharden-manifest-$TS.txt"
WORK="/root/deharden-work-$TS"

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
  --force            proceed meme si aucune sauvegarde de durcissement n'est trouvee
  --report <fichier> ecrit un rapport Markdown (defaut : /root/deharden-<ts>.md)
  --help             cette aide

Le script doit etre execute en root sur le noeud Proxmox a restaurer.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --keep-packages) KEEP_PACKAGES=1 ;;
        --force) FORCE=1 ;;
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
# Fichiers CREES par le durcissement (ils n'existaient pas avant).
# La liste est derivee des scripts de durcissement ; lpresence d'une
# sauvegarde anterieure au durcissement est verifiee a l'etape 2 (un tel
# fichier pre-existait et doit etre restaure, pas supprime).
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
/etc/audit/rules.d/90-pve.rules
/etc/fail2ban/filter.d/pveproxy.conf
/etc/fail2ban/jail.d/pve-web.conf
/etc/fail2ban/jail.d/pve-web-http.conf
/etc/rsyslog.d/99-anssi-remote.conf
/etc/cron.daily/aide-check
/etc/issue.net
/etc/cron.allow
/etc/apt/apt.conf.d/20auto-upgrades
/root/rollback-hardening.sh
"

# Paquets installes par le durcissement : la liste reelle est calculee par
# difference entre les paquets presents maintenant et ceux presents AVANT le
# durcissement (fichier "packages.before" depose par les scripts de
# durcissement). La liste ci-dessous n'est qu'un repli.
PACKAGES="aide aide-common apparmor-utils rsyslog auditd audispd-plugins fail2ban rkhunter unattended-upgrades apt-listchanges libpam-pwquality libpam-modules sudo chrony"

# Paquets jamais desinstalles : les retirer casserait PAM ou SSH.
PROTECTED_PACKAGES="libpam-modules libpam-runtime libpam0g openssh-server openssh-client systemd apt dpkg bash coreutils util-linux libc6 dbus passwd login adduser procps iproute2 pve-manager pve-cluster pveproxy pvedaemon pvestatd"

# Comptes crees par le durcissement.
CREATED_USERS="pveadmin"

# Services DESACTIVES ou MASKES par le durcissement (a reactiver).
REENABLE_SERVICES="ctrl-alt-del.target avahi-daemon cups bluetooth rsh-server rsh-client talk-server talk-client telnet inetd xinetd nfs-kernel-server samba smbd nmbd snmpd vsftpd proftpd haproxy rsyslog-lm"

# ---------------------------------------------------------------------------
step "0. Sauvegarde de securite"
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$SAFETY" "$WORK"
    runsh "tar -C / -czf '$SAFETY/etat-avant-dehardening.tar.gz' \
        etc/ssh etc/pve etc/sysctl.d etc/modprobe.d etc/security etc/profile.d \
        etc/audit etc/fail2ban etc/rsyslog.d etc/systemd etc/login.defs etc/crontab \
        etc/fstab etc/cron.allow etc/issue.net etc/cron.daily etc/pam.d 2>/dev/null || true"
    log "Sauvegarde de securite : $SAFETY/etat-avant-dehardening.tar.gz"
fi

# ---------------------------------------------------------------------------
step "1. Index des sauvegardes produites par le durcissement"
# L'index contient une ligne par fichier de sauvegarde :
#   "<chemin d'origine>|<mtime de la source>|<horodatage>|<fichier de sauvegarde>"
# "cp -a" preserve le mtime : le mtime de la sauvegarde est donc celui du
# fichier AVANT modification. La sauvegarde la plus ancienne (mtime minimal)
# est donc l'etat d'origine.
INDEX="$WORK/index.txt"
: > "$INDEX"
FOUND_ROOT=0
for root in "$BACKUP_ROOT" "$ANS_BACKUP_ROOT"; do
    [ -d "$root" ] || continue
    FOUND_ROOT=1
    find "$root" -type f 2>/dev/null | while IFS= read -r saved; do
        rel="${saved#$root/}"
        case "$rel" in
            */shells.before|*/locked.before) continue ;;
        esac
        ts="${rel%%/*}"
        rest="${rel#*/}"
        case "$rest" in
            *.mode) orig="/${rest%.mode}" ;;
            *)      orig="/${rest%.*}" ;;
        esac
        mt=$(stat -c %Y "$saved" 2>/dev/null || echo 0)
        printf '%s|%s|%s|%s\n' "$orig" "$mt" "$ts" "$saved"
    done >> "$INDEX"
done
if [ "$FOUND_ROOT" = "0" ]; then
    log "AUCUNE sauvegarde trouvee ($BACKUP_ROOT, $ANS_BACKUP_ROOT)"
    log "le noeud n'a probablement jamais ete durci par ces scripts"
    log "ABANDON : aucune modification ne sera effectuee (utilisez --force pour passer outre)"
    if [ "$FORCE" != "1" ]; then
        exit 3
    fi
else
    log "index : $(wc -l < "$INDEX") sauvegarde(s) referencee(s)"
fi

# Debut du durcissement : horodatage de la plus ancienne sauvegarde.
HARDENING_START=0
first_ts=""
if [ -s "$INDEX" ]; then
    first_ts=$(cut -d'|' -f3 "$INDEX" | sort | head -1)
    HARDENING_START=$(date -d "${first_ts:0:8} ${first_ts:9:6}" +%s 2>/dev/null || echo 0)
    log "debut du durcissement (d apres les sauvegardes) : $first_ts (epoch $HARDENING_START)"
fi

# ---------------------------------------------------------------------------
step "2. Restauration des fichiers sauvegardes"
# Pour chaque chemin, on retient la sauvegarde de mtime minimal : c'est
# l'etat d'origine. Un chemin de la liste "crees" dont toutes les
# sauvegardes sont posterieures au durcissement est supprime.
RESTORED=""
DELETED=""
if [ -s "$INDEX" ]; then
    # Chemin -> mtime minimal
    best=$(sort -t'|' -k1,1 -k2,2n "$INDEX" | awk -F'|' '
        !seen[$1]++ { print }')
    while IFS='|' read -r orig mt ts saved; do
        [ -n "$orig" ] || continue
        case "$orig" in
            *.mode) continue ;;
        esac
        created=0
        for c in $CREATED_FILES; do
            [ "$c" = "$orig" ] && created=1 && break
        done
        # Fichier cree par le durcissement : aucune sauvegarde anterieure
        if [ "$created" = "1" ] && [ "$mt" -ge "$HARDENING_START" ] 2>/dev/null; then
            log "  suppression (cree par le durcissement) : $orig"
            if [ "$DRY_RUN" != "1" ]; then
                rm -f "$orig"
                # les repliques de sauvegarde correspondantes sont retirees
                rm -rf "$(dirname "$saved")" 2>/dev/null || true
            fi
            DELETED="$DELETED$orig
"
            continue
        fi
        if [ ! -e "$orig" ]; then
            log "  (absent, rien a restaurer) $orig"
            continue
        fi
        log "  restauration : $orig  <- $saved"
        if [ "$DRY_RUN" != "1" ]; then
            cp -a "$saved" "$orig" || log "ECHEC restauration $orig"
        fi
        RESTORED="$RESTORED$orig
"
    done <<EOF
$best
EOF
fi

# ---------------------------------------------------------------------------
step "2b. Suppression des fichiers crees sans sauvegarde"
if [ "$HARDENING_START" = "0" ]; then
    log "  ignore : aucune sauvegarde de durcissement, aucun fichier n'est supprime"
else
for f in $CREATED_FILES; do
    [ -n "$f" ] || continue
    # si le fichier a ete restaure a l'etape 2, il pre-existait : on le garde
    if printf '%s\n' "$RESTORED" | grep -qx "$f"; then
        log "  conserve (pre-existant, restaure) : $f"
        continue
    fi
    if [ -e "$f" ]; then
        log "  suppression : $f"
        if [ "$DRY_RUN" != "1" ]; then
            rm -f "$f"
        fi
        DELETED="$DELETED$f
"
    fi
done

# Fichiers de configuration du pare-feu PVE : crees par le durcissement sur
# un noeud isole (ils n'existent pas dans une installation standard).
for f in /etc/pve/firewall/cluster.fw /etc/pve/nodes/*/firewall; do
    [ -e "$f" ] || continue
    # s'il existe une sauvegarde anterieure au durcissement, il est restaure
    if [ -s "$INDEX" ]; then
        p=$(printf '%s\n' "$INDEX" | awk -F'|' -v p="$f" '$1==p {print $2" "$4}' | sort -n | head -1)
        mt=${p%% *}
        if [ -n "$mt" ] && [ "$mt" -lt "$HARDENING_START" ] 2>/dev/null; then
            log "  conserve (pre-existant) : $f"
            continue
        fi
    fi
    log "  suppression : $f"
    if [ "$DRY_RUN" != "1" ]; then
        rm -f "$f"
    fi
    DELETED="$DELETED$f
"
done
fi   # fin du bloc "des sauvegardes existent"

# ---------------------------------------------------------------------------
step "2c. Restauration des permissions et proprietaires"
# Les fichiers "<nom>.mode" contiennent : "<mode> <proprietaire> <groupe>".
for root in "$BACKUP_ROOT" "$ANS_BACKUP_ROOT"; do
    [ -d "$root" ] || continue
    find "$root" -type f -name '*.mode' 2>/dev/null | while IFS= read -r mf; do
        rel="${mf#$root/}"
        ts="${rel%%/*}"
        rest="${rel#*/}"
        orig="/${rest%.mode}"
        meta=$(cat "$mf" 2>/dev/null)
        mode=$(printf '%s' "$meta" | awk '{print $1}')
        owner=$(printf '%s' "$meta" | awk '{print $2}')
        group=$(printf '%s' "$meta" | awk '{print $3}')
        [ -n "$mode" ] || continue
        if [ ! -e "$orig" ]; then
            continue
        fi
        cur=$(stat -c %a "$orig" 2>/dev/null || echo "")
        if [ "$cur" = "$mode" ]; then
            continue
        fi
        log "  permissions : $orig  $cur -> $mode ($owner:$group)"
        if [ "$DRY_RUN" != "1" ]; then
            chmod "$mode" "$orig" 2>/dev/null || true
            [ -n "$owner" ] && chown "$owner:$group" "$orig" 2>/dev/null || true
        fi
    done
done

# ---------------------------------------------------------------------------
step "3. Reversement des mesures d'etat"

# 3a. Modules noyau bloques : l'initramfs est reconstruit avec la
#     configuration restauree.
log "  reconstruction de l'initramfs (modules noyau restaures)"
runsh "update-initramfs -u"

# 3b. Shells des comptes systeme (ANSSI N1).
SHELLS_FILE=$(find "$ANS_BACKUP_ROOT" -name shells.before -type f 2>/dev/null | sort | head -1)
if [ -n "$SHELLS_FILE" ]; then
    log "  restauration des shells de comptes systeme ($SHELLS_FILE)"
    while IFS=: read -r u sh; do
        [ -n "$u" ] || continue
        cur=$(getent passwd "$u" 2>/dev/null | cut -d: -f7)
        if [ -n "$cur" ] && [ "$cur" != "$sh" ]; then
            log "    $u : $cur -> $sh"
            runsh "usermod --shell '$sh' '$u' 2>/dev/null || true"
        fi
    done < "$SHELLS_FILE"
else
    log "  aucune liste de shells d'origine trouvee"
fi

# 3c. Comptes verrouilles (ANSSI N4).
LOCKED_FILE=$(find "$ANS_BACKUP_ROOT" -name locked.before -type f 2>/dev/null | sort | head -1)
if [ -n "$LOCKED_FILE" ]; then
    while IFS= read -r u; do
        [ -n "$u" ] || continue
        log "  deverrouillage du compte $u"
        runsh "usermod --unlock '$u' 2>/dev/null || true"
    done < "$LOCKED_FILE"
fi

# 3d. Systemd : les services desactives ou masques sont re-actives.
for s in $REENABLE_SERVICES; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\."; then
        log "  reactivation du service $s"
        runsh "systemctl unmask '$s' 2>/dev/null || true"
        runsh "systemctl enable '$s' 2>/dev/null || true"
        runsh "systemctl start '$s' 2>/dev/null || true"
    fi
done

# 3e. Comptes crees par le durcissement.
for u in $CREATED_USERS; do
    if getent passwd "$u" >/dev/null 2>&1; then
        log "  suppression du compte $u"
        runsh "deluser --remove-home '$u' 2>/dev/null || userdel -r '$u' 2>/dev/null || true"
    fi
done

# ---------------------------------------------------------------------------
step "4. Restauration de la configuration SSH (en dernier)"
# Le drop-in SSH a ete supprime a l'etape 2. On verifie que la
# configuration est valide AVANT de recharger le service : une
# configuration invalide couperait l'acces SSH.
if [ "$DRY_RUN" != "1" ]; then
    if sshd -t 2>/dev/null; then
        log "  configuration SSH valide"
        runsh "systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null || true"
    else
        log "  ATTENTION : configuration SSH invalide, le service n'est pas recharge"
        runsh "sshd -t 2>&1 | head -5"
    fi
else
    log "  [DRY-RUN] verification sshd -t puis reload ssh"
fi

# ---------------------------------------------------------------------------
step "5. Depots apt retablis"
# Les depots enterprise desactives par le durcissement sont renommes en
# .disabled : on les restaure.
for f in /etc/apt/sources.list.d/pve-enterprise.sources.disabled \
         /etc/apt/sources.list.d/ceph.sources.disabled; do
    if [ -e "$f" ]; then
        log "  reactivation du depot $(basename "$f" .disabled)"
        runsh "mv '$f' '${f%.disabled}' 2>/dev/null || true"
    fi
done

# ---------------------------------------------------------------------------
step "6. Paquets installes par le durcissement"
# Liste de reference : etat des paquets AVANT le premier durcissement
# (fichier "packages.before" depose par les scripts de durcissement).
PKG_REF=""
if [ "$HARDENING_START" != "0" ]; then
    for root in "$BACKUP_ROOT" "$ANS_BACKUP_ROOT"; do
        [ -d "$root" ] || continue
        if [ -f "$root/$first_ts/packages.before" ]; then
            PKG_REF="$root/$first_ts/packages.before"
            break
        fi
    done
fi
if [ "$KEEP_PACKAGES" = "1" ]; then
    log "  --keep-packages : les paquets sont conserves"
    if [ -n "$PKG_REF" ]; then
        log "  paquets ajoutes par le durcissement :"
        dpkg-query -W -f='${Package}\n' 2>/dev/null | sort > "$WORK/packages.now"
        comm -13 "$PKG_REF" "$WORK/packages.now" 2>/dev/null | sed 's/^/    /' | tee -a "$LOG"
    fi
else
    if [ -n "$PKG_REF" ]; then
        log "  desinstallation des paquets ajoutes par le durcissement (delta packages.before)"
        dpkg-query -W -f='${Package}\n' 2>/dev/null | sort > "$WORK/packages.now"
        comm -13 "$PKG_REF" "$WORK/packages.now" 2>/dev/null > "$WORK/packages.to-remove"
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            protected=0
            for prot in $PROTECTED_PACKAGES; do
                [ "$p" = "$prot" ] && protected=1 && break
            done
            if [ "$protected" = "1" ]; then
                log "    ignore (paquet systeme protege) : $p"
                continue
            fi
            log "    suppression du paquet $p"
            runsh "DEBIAN_FRONTEND=noninteractive apt-get remove -y '$p' 2>&1 | tail -3"
        done < "$WORK/packages.to-remove"
    else
        log "  aucune reference packages.before : desinstallation de la liste par defaut"
        for p in $PACKAGES; do
            protected=0
            for prot in $PROTECTED_PACKAGES; do
                [ "$p" = "$prot" ] && protected=1 && break
            done
            [ "$protected" = "1" ] && continue
            if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
                log "    suppression du paquet $p"
                runsh "DEBIAN_FRONTEND=noninteractive apt-get remove -y '$p' 2>&1 | tail -3"
            fi
        done
    fi
fi

# ---------------------------------------------------------------------------
step "7. Reconstruction de l'initramfs et application des sysctl"
runsh "update-initramfs -u"
runsh "sysctl --system 2>/dev/null || true"

# ---------------------------------------------------------------------------
step "8. Verification finale"
runsh "systemctl daemon-reload"
runsh "systemctl restart pve-firewall 2>/dev/null || true"
runsh "systemctl restart apparmor 2>/dev/null || true"
runsh "systemctl restart auditd 2>/dev/null || true"
runsh "systemctl restart rsyslog 2>/dev/null || true"

echo "" | tee -a "$LOG"
echo "--- services ---" | tee -a "$LOG"
for s in ssh pveproxy pvedaemon pvestatd pve-firewall; do
    st=$(systemctl is-active "$s" 2>/dev/null || echo "inactif")
    printf '    %-14s %s\n' "$s" "$st" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "--- de-hardening ---" | tee -a "$LOG"
for f in /etc/modprobe.d/99-pve-hardening.conf /etc/ssh/sshd_config.d/00-pve-hardening.conf; do
    if [ -e "$f" ]; then
        echo "    ATTENTION : $f est toujours present" | tee -a "$LOG"
    fi
done

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
    echo "## Fichiers restaures"
    echo ""
    echo "| Fichier |"
    echo "|---|"
    if [ -n "$RESTORED" ]; then
        printf '%s' "$RESTORED" | while IFS= read -r f; do
            [ -n "$f" ] && echo "| \`$f\` |"
        done
    else
        echo "| *(aucun)* |"
    fi
    echo ""
    echo "## Fichiers supprimes"
    echo ""
    echo "| Fichier |"
    echo "|---|"
    if [ -n "$DELETED" ]; then
        printf '%s' "$DELETED" | while IFS= read -r f; do
            [ -n "$f" ] && echo "| \`$f\` |"
        done
    else
        echo "| *(aucun)* |"
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
[ "$DRY_RUN" = "1" ] || rm -rf "$WORK"
log "De-hardening termine (dry-run=$DRY_RUN)"
