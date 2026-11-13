#!/usr/bin/env python3
"""Lanceur du lab de hardening Proxmox VE 9 (multiplateforme).

Usage :
    python3 scripts/pve.py --help
    python3 scripts/pve.py run --phase all --target core --level 2 --run-func

Ce lanceur fonctionne sans installation : il ajoute simplement son dossier au
chemin d'import pour trouver le paquet ``pve_hardening``.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pve_hardening.cli import main  # noqa: E402

if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # La sortie standard a ete fermee (pipes vers head/less) : on sort
        # proprement plutot que d'afficher une trace d'exception.
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(0)
    except KeyboardInterrupt:
        sys.exit(130)
