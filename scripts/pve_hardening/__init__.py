"""pve_hardening - Lab de test de hardening Proxmox VE 9 (implementation Python).

Ce package est l'equivalent multiplateforme de la serie de scripts
PowerShell du lab (scripts/*.ps1). Il fonctionne sous Linux (Ubuntu, SLES,
RHEL), macOS et Windows, sans dependance hors stdlib (paramiko et un moteur
Chromium sont requis pour le SSH et le rendu PDF).

Utilisation :

    python3 scripts/pve.py --help
    python3 scripts/pve.py run --phase baseline
    python3 scripts/pve.py run --phase all --target core --level 2 \\
        --audit-extra anssi,ceph,cis13,communautaire --run-func
    python3 scripts/pve.py report --before artifacts/baseline-x \\
        --after artifacts/after-y
    python3 scripts/pve.py snapshot --action create --name pristine
"""

__version__ = "1.3.0"
__all__ = ["__version__"]
