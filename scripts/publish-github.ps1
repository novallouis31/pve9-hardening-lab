# =============================================================================
# publish-github.ps1 - Publie un depot Git local sur GitHub.
#
# Le depot est pushé via l'API GitHub et l'URL HTTPS. Le Personal Access
# Token est optionnelement enregistre dans le magasin chiffre de la CLI
# GitKraken (`gk provider add github -t ...`), ce qui permet ensuite
# d'utiliser `gk` (push, PR, issues) sans ressaisir le jeton.
#
# Le jeton n'est JAMAIS ecrit dans .git/config : le remote reste propre.
#
# Usage :
#   publish-github.ps1 -Repo pve9-hardening-lab -Token ghp_xxx [-Tags]
#   publish-github.ps1 -Repo petit-atelier-de-jeux -Token ghp_xxx [-Tags]
#   publish-github.ps1 -UseGitKraken        # jeton deja dans le magasin gk
# =============================================================================
param(
    # Depot GitHub cible (nom du depot)
    [string]$Repo = 'pve9-hardening-lab',
    # Personal Access Token GitHub (perimetre 'repo')
    [string]$Token = '',
    # Utilise le jeton deja enregistre dans la CLI GitKraken
    [switch]$UseGitKraken,
    # Compte proprietaire (deduit de l'API si absent)
    [string]$Owner = '',
    # Visibilite du depot cree
    [ValidateSet('public', 'private')][string]$Visibility = 'public',
    # Pousser aussi les tags
    [switch]$Tags,
    # Chemin du depot local (par defaut : depot courant)
    [string]$Path = ''
)

$ErrorActionPreference = 'Stop'
$gk = Join-Path $env:LOCALAPPDATA 'GitKrakenCLI\gk.exe'

if (-not $Path) { $Path = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Path '.git'))) {
    Write-Host "Ce dossier n'est pas un depot git : $Path" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- 1. controles
Write-Host "=== 1. controle du depot a publier ===" -ForegroundColor Cyan
Write-Host ("  depot local : {0}" -f $Path)
$branch = (git -C $Path branch --show-current 2>$null)
Write-Host ("  branche     : {0}" -f $branch)
$files = git -C $Path ls-files
Write-Host ("  {0} fichiers suivis" -f $files.Count)
$dirty = git -C $Path status --short | Where-Object { $_ -notmatch '^\?\?' }
if ($dirty) {
    Write-Host "  ATTENTION : modifications non commitees :" -ForegroundColor Yellow
    $dirty | Select-Object -First 10 | ForEach-Object { Write-Host ("    " + $_) -ForegroundColor DarkYellow }
} else {
    Write-Host "  arbre propre" -ForegroundColor Green
}

# aucun secret ne doit etre versionne
$leak = $false
foreach ($f in $files) {
    $p = Join-Path $Path $f
    if (-not (Test-Path $p)) { continue }
    $c = Get-Content $p -Raw -ErrorAction SilentlyContinue
    if (-not $c) { continue }
    if ($c -match 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY') {
        Write-Host "  FUITE : cle privee dans $f" -ForegroundColor Red; $leak = $true
    }
    if ($c -match 'gh[pousr]_[A-Za-z0-9]{20,}' -or $c -match 'glpat-[A-Za-z0-9_-]{20,}') {
        Write-Host "  FUITE : token dans $f" -ForegroundColor Red; $leak = $true
    }
}
if ($leak) { Write-Host "Publication interrompue : secret detecte" -ForegroundColor Red; exit 1 }
Write-Host "  aucun secret detecte" -ForegroundColor Green

# volume : les fichiers volumineux sont signales (GitHub refuse > 100 Mo)
$big = @()
foreach ($f in $files) {
    $p = Join-Path $Path $f
    if (Test-Path $p) {
        $len = (Get-Item $p).Length
        if ($len -gt 50MB) { $big += ("{0} ({1} Mo)" -f $f, [math]::Round($len/1MB,0)) }
    }
}
if ($big.Count) {
    Write-Host "  ATTENTION : fichier(s) > 50 Mo (GitHub les refusera) :" -ForegroundColor Yellow
    $big | ForEach-Object { Write-Host ("    " + $_) -ForegroundColor DarkYellow }
}

# ------------------------------------------------------- 2. authentification
Write-Host "`n=== 2. authentification GitHub ===" -ForegroundColor Cyan
if ($UseGitKraken -and -not $Token) {
    if (-not (Test-Path $gk)) { Write-Host "  CLI GitKraken introuvable" -ForegroundColor Red; exit 2 }
    $list = & $gk provider list 2>&1 | Out-String
    Write-Host "  providers GitKraken :"
    ($list -split "`n" | Where-Object { $_ -match 'GitHub|github' }) | Select-Object -First 3 | ForEach-Object { Write-Host ("    " + $_.Trim()) }
    Write-Host ""
    Write-Host "  Pour publier : gk provider add github -t ghp_..." -ForegroundColor Yellow
    Write-Host "  (le jeton est stocke chiffre par GitKraken, jamais dans le depot)" -ForegroundColor DarkGray
    exit 2
}
if (-not $Token) {
    Write-Host "  aucun jeton fourni" -ForegroundColor Red
    Write-Host "  usage : -Token ghp_...  ou  -UseGitKraken" -ForegroundColor Yellow
    exit 2
}

# enregistrement dans le magasin chiffre de la CLI GitKraken
if (Test-Path $gk) {
    & $gk provider add github -t $Token 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host ("  gk : " + $_) -ForegroundColor DarkGray }
}
$headers = @{ Authorization = "Bearer $Token"; 'User-Agent' = 'opencode-publish' }

# --------------------------------------------------- 3. creation du depot
Write-Host "`n=== 3. depot GitHub ===" -ForegroundColor Cyan
if (-not $Owner) {
    try {
        $me = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -TimeoutSec 30
        $Owner = $me.login
        Write-Host ("  compte : {0}" -f $Owner)
    } catch {
        Write-Host ("  jeton invalide : {0}" -f $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}
$remote = "https://github.com/$Owner/$Repo.git"
Write-Host ("  cible : {0}" -f $remote)

$exists = $true
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo" -Headers $headers -TimeoutSec 30 | Out-Null
} catch { $exists = $false }

if (-not $exists) {
    $body = @{
        description = "Lab de hardening Proxmox VE 9 : CIS Debian 13 / ANSSI BP-028 / Ceph, 160 controles, 72 tests de non-regression, rapports PDF"
        private = ($Visibility -eq 'private')
        auto_init = $false
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" -Headers $headers `
            -Body $body -ContentType 'application/json' -TimeoutSec 30 | Out-Null
        Write-Host "  depot cree ($Visibility)" -ForegroundColor Green
    } catch {
        Write-Host ("  ECHEC creation : {0}" -f $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  depot deja existant" -ForegroundColor DarkGray
}

# ------------------------------------------------------------- 4. remote
Write-Host "`n=== 4. remote ===" -ForegroundColor Cyan
git -C $Path remote remove origin 2>$null | Out-Null
git -C $Path remote add origin $remote
Write-Host ("  origin -> {0}" -f (git -C $Path remote get-url origin)) -ForegroundColor Green

# --------------------------------------------------------------- 5. push
Write-Host "`n=== 5. push ===" -ForegroundColor Cyan
$pushUrl = "https://$([uri]::EscapeDataString($Owner)):$([uri]::EscapeDataString($Token))@github.com/$Owner/$Repo.git"
$args = @('push', '-u', $pushUrl, $branch)
if ($Tags) { $args += '--tags' }
$out = & git -C $Path @args 2>&1
$code = $LASTEXITCODE
$out | Select-Object -Last 10 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
git -C $Path remote set-url origin $remote

if ($code -ne 0) {
    Write-Host "`n  ECHEC du push (code $code)" -ForegroundColor Red
    Write-Host "  Verifiez que le PAT a le perimetre 'repo' et n'est pas expire." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== PUBLICATION REUSSIE ===" -ForegroundColor Green
Write-Host ("  https://github.com/{0}/{1}" -f $Owner, $Repo) -ForegroundColor Green
Write-Host ""
Write-Host "  Dans GitKraken : File > Open > {0}" -ForegroundColor Cyan
Write-Host "  Puis : bouton Push (branche {0})" -f $branch
