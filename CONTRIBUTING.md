# Contributing

Merci de votre interest pour ce lab. Ce document decrit la maniere de
contribuer de facon reproductible.

## Ce que fait ce projet

Un lab de test de hardening pour **Proxmox VE 9** : il applique un plan de
durcissement conforme CIS Debian 13 / ANSSI BP-028 / Ceph, mesure la
conformite **avant et apres** (160 controles), et verifie par **72 tests
fonctionnels** que le durcissement ne casse ni Proxmox ni l'OS.

Le livrable principal est la **collection de rapports PDF** dans `reports/`,
qui montrent pour chaque guide le delta de conformite et l'absence de
regression fonctionnelle.

## Workflow de contribution

```powershell
# 1. branche de travail
git switch -c feature/mon-contribut

# 2. cycle de test complet (baseline + durcissement + audit + rapports)
powershell -ExecutionPolicy Bypass -File scripts\run-phase.ps1 -Phase all -Target core -Level 2 `
    -AuditExtra anssi,ceph,cis13,communautaire -RunFunc

# 3. commit + push
git add -A
git commit -m "feat: description concise"
git push -u origin feature/mon-contribut
```

Voir [docs/GITKRAKEN.md](docs/GITKRAKEN.md) pour l'equivalent via
l'interface GitKraken.

## Regles de contribution

### 1. Toute modification de durcissement doit etre tracee

Chaque bloc porte sa **reference de controle** (guide PVE 9, ID CIS Debian
13, ANSSI BP-028 ou numero de check harbian-audit) :

```bash
block 1 "5. SSH : permissions, authentification, chiffrement (CIS 5.1.x)"
ref "CIS Debian 13 5.1.x + deviation guide PVE 9 section 5.1.21"
```

### 2. Un nouveau controle doit avoir son test fonctionnel

- controle d'audit : ajoute dans `guest/audit-*.sh`, avec un statut
  `PASS|FAIL|NA|INFO` et un detail explicite ;
- test fonctionnel : ajoute dans `guest/func-test-pve.sh` (comportement
  Proxmox) ou `guest/func-test-os.sh` (comportement de l'OS).

Un controle d'audit sans test fonctionnel associe est incomplet : il peut
passer alors que la machine est cassee.

### 3. Les scripts shell doivent rester compatibles bash + `set -u`

```bash
set -u
# les variables non definies doivent etre explicitement protegees
DNS_NAT="${DNS_NAT:-10.0.2.3}"
```

### 4. Les scripts doivent etre idempotents

Rejouer un apply sur une VM deja durcie ne doit rien casser. Les blocs
utilisent `write_file` (ecriture atomique) et `backup` (sauvegarde avant
modification).

### 5. Ne jamais commiter de secret

Le `.gitignore` exclut `.keys/`, `.local/`, `vendor/` et `artifacts/`.
Verifiez avec `git status` avant de commiter.

## Style

- **shell** : 4 espaces, `shellcheck` si disponible, commentaires en francais
  sans accents dans les scripts (encodage cp1252 cote hote)
- **PowerShell** : 4 espaces, `Write-Host` colore pour le suivi de cycle
- **documentation** : Markdown, tableaux pour les resultats, code inline
  pour les commandes

## Tests avant commit

```powershell
# syntaxe des scripts shell
wsl -d Ubuntu -- bash -n guest/apply-homesec-core.sh
wsl -d Ubuntu -- bash -n guest/apply-anssi.sh
wsl -d Ubuntu -- bash -n guest/func-test-os.sh

# syntaxe PowerShell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile("scripts\run-phase.ps1", [ref]$null, [ref]$errors)
if ($errors) { $errors }
```

## Signalement de bug

Ouvrez une issue avec :
- la VM concernee (proxmox / proxmox2 / proxmox3) et son port SSH ;
- la commande exacte lancee ;
- la sortie (log `/var/log/hardening-*.log` ou `/var/log/anssi-*.log`) ;
- le resultat de l'audit (`artifacts/after-*/audit.txt`).

## Licence

En contribuant, vous acceptez que votre contribution soit publiee sous
licence MIT (voir [LICENSE](LICENSE)).
