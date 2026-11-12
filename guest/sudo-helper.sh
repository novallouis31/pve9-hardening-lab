#!/usr/bin/env bash
# Helper root via su (sudo absent sur PVE 9 fresh install)
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
ROOTPW='19581958'

root() {
    echo "$ROOTPW" | su -s /bin/bash -c "$*" root 2>&1
}

case "${1:-help}" in
    id)        root "id" ;;
    sshd)      root "cat /etc/ssh/sshd_config.d/00-pve-hardening.conf; echo '--- principal ---'; grep -nE 'Include|PermitRoot|PasswordAuth|AllowUsers|AllowGroups' /etc/ssh/sshd_config" ;;
    backups)   root "ls -la /root/hardening-backups/ 2>&1; echo '--- fichiers ---'; find /root/hardening-backups -type f 2>/dev/null | head -40" ;;
    rootkeys)  root "ls -la /root/.ssh/; echo '--- contenu ---'; cat /root/.ssh/authorized_keys" ;;
    state)     root "ls -la /etc/sysctl.d/99-pve-hardening.conf /etc/modprobe.d/99-pve-hardening.conf /etc/security/faillock.conf /etc/fail2ban/jail.d/pve-web.conf /etc/pve/firewall/cluster.fw 2>&1" ;;
    exec)      shift; root "$*" ;;
    apply)     root "bash $2" ;;
    *)         echo "Usage: sudo-helper.sh {id|sshd|backups|rootkeys|state|exec <cmd>|apply <script>}" ;;
esac
