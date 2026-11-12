#!/usr/bin/env bash
# =============================================================================
# reset-pristine.sh - Restaure la VM dans un etat PROPRE (post-installation PVE)
# Usage : bash reset-pristine.sh
# =============================================================================
set -u
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

echo "=========================================================="
echo " RESET PRISTINE - Proxmox VE 9"
echo " $(date -Is)"
echo "=========================================================="

# Backup le plus ANCIEN = etat d'origine
BK=$(ls -d /root/hardening-backups/*/ 2>/dev/null | sort | head -1)
echo "Backup de reference : ${BK:-aucun}"

# Restaure le fichier original (les backups sont suffixes par timestamp)
# Restaure le fichier original (les backups sont suffixes par timestamp).
# On cherche dans TOUS les repertoires de backup et on privilegie la copie
# NON VIDE la plus recente.
restore() {
    local f="$1"
    local abs="/${f#/}"
    local dir="${abs%/*}"
    local base
    base=$(basename "$abs")
    local src=""
    local cand
    for bdir in $(ls -d /root/hardening-backups/*/ 2>/dev/null | sort -r); do
        for cand in $(find "${bdir}${dir}" -maxdepth 1 -name "${base}.*" -type f 2>/dev/null | sort -r); do
            if [ -s "$cand" ]; then src="$cand"; break 2; fi
        done
    done
    if [ -n "$src" ]; then
        cp -a "$src" "$abs"
        echo "  restaure : $abs (depuis $(basename "$src"))"
    else
        echo "  (aucun backup valide pour $abs)"
    fi
}

echo ""
echo "--- 1. Suppression des fichiers de hardening ---"
for f in \
  /etc/ssh/sshd_config.d/00-pve-hardening.conf \
  /etc/modprobe.d/99-pve-hardening.conf \
  /etc/modprobe.d/99-anssi-usb.conf \
  /etc/sysctl.d/99-pve-hardening.conf \
  /etc/sysctl.d/98-anssi.conf \
  /etc/systemd/journald.conf.d/99-pve-hardening.conf \
  /etc/security/limits.d/99-pve-hardening.conf \
  /etc/fail2ban/jail.d/pve-web.conf \
  /etc/fail2ban/filter.d/proxmox.conf \
  /etc/audit/rules.d/90-pve.rules \
  /etc/profile.d/99-pve-hardening.sh \
  /etc/issue.net \
  /etc/cron.allow \
  /etc/rsyslog.d/99-anssi-remote.conf \
  /etc/pve/nodes/$(hostname)/firewall ; do
    if [ -e "$f" ]; then rm -f "$f" && echo "  supprime : $f"; fi
done
rmdir /etc/systemd/journald.conf.d 2>/dev/null

echo ""
echo "--- 2. Restauration des fichiers modifies ---"
restore etc/ssh/sshd_config
restore etc/crontab
restore etc/fstab
restore etc/pam.d/common-auth
restore etc/pam.d/common-password
restore etc/security/faillock.conf
restore etc/security/pwquality.conf
restore etc/apt/apt.conf.d/20auto-upgrades
# cluster.fw : restauration du fichier d'origine s'il existait
if [ -n "$BK" ]; then
    src=$(find "${BK}etc/pve/firewall" -maxdepth 1 -name 'cluster.fw.*' -type f 2>/dev/null | sort | head -1)
    if [ -n "$src" ]; then
        mkdir -p /etc/pve/firewall && cp -a "$src" /etc/pve/firewall/cluster.fw
        echo "  restaure : /etc/pve/firewall/cluster.fw"
    else
        rm -f /etc/pve/firewall/cluster.fw && echo "  supprime : /etc/pve/firewall/cluster.fw (absent a l'origine)"
    fi
fi

echo ""
echo "--- 3. Permissions d'origine ---"
chmod 0644 /etc/ssh/sshd_config 2>/dev/null
chmod 0644 /etc/crontab 2>/dev/null
chmod 0644 /etc/fstab 2>/dev/null
chmod 0644 /etc/pam.d/common-auth /etc/pam.d/common-password 2>/dev/null
for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    [ -d "$d" ] && chmod 0755 "$d"
done
find /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly -type f -exec chmod 0644 {} + 2>/dev/null
chmod 0600 /etc/ssh/ssh_host_*_key 2>/dev/null
chmod 0644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null
echo "  permissions restaurees"

echo ""
echo "--- 4. Nettoyage PAM / unattended-upgrades ---"
sed -i '/pam_faillock/d' /etc/pam.d/common-auth 2>/dev/null
sed -i '/pam_pwquality/d' /etc/pam.d/common-password 2>/dev/null
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    python3 - <<'PY'
import re
p = "/etc/apt/apt.conf.d/50unattended-upgrades"
s = open(p).read()
s = re.sub(r"\n*Unattended-Upgrade::Origins-Pattern \{[^}]*\};", "", s, flags=re.S)
s = re.sub(r"\n*Unattended-Upgrade::Remove-Unused-Dependencies.*", "", s)
s = re.sub(r"\n*Unattended-Upgrade::Automatic-Reboot.*", "", s)
open(p, "w").write(s)
print("  50unattended-upgrades nettoye")
PY
fi

echo ""
echo "--- 5. Suppression du compte administrateur ---"
if id pveadmin >/dev/null 2>&1; then
    userdel -r pveadmin 2>/dev/null && echo "  pveadmin supprime"
fi

echo ""
echo "--- 6. Purge des paquets installes par le hardening ---"
apt-get remove -y --purge auditd audispd-plugins fail2ban rkhunter aide aide-common \
    unattended-upgrades apt-listchanges libpam-pwquality 2>/dev/null | tail -1
apt-get autoremove -y 2>/dev/null | tail -1
apt-get clean 2>/dev/null
rm -rf /var/lib/aide /var/lib/fail2ban /var/lib/rkhunter /etc/audit/rules.d/90-pve.rules 2>/dev/null
echo "  paquets purges"

echo ""
echo "--- 7. Rechargement des services ---"
systemctl daemon-reload
systemctl restart systemd-journald 2>/dev/null
systemctl restart rsyslog 2>/dev/null
systemctl restart ssh 2>/dev/null
systemctl disable --now auditd 2>/dev/null
systemctl disable --now fail2ban 2>/dev/null
systemctl disable --now unattended-upgrades 2>/dev/null
systemctl disable --now rkhunter 2>/dev/null
sysctl --system 2>&1 | tail -1
echo "  services recharges"

echo ""
echo "--- 8. Verification ---"
sshd -t && echo "  sshd -t : OK"
systemctl is-active ssh pveproxy pve-firewall pvedaemon pvestatd | tr '\n' ' '; echo
echo "--- ports ---"
ss -tln 2>/dev/null | grep -E ':22 |:8006 ' | head -4
echo ""
echo "=========================================================="
echo " RESET TERMINE"
echo "=========================================================="
