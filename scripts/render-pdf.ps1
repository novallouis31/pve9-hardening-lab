<#
.SYNOPSIS
    Rend un fichier HTML en PDF via Chrome (ou Edge) headless.

.DESCRIPTION
    Ne depend d'aucun package externe : Chrome et Edge sont presents sur
    Windows 11 et embarquent tous deux un moteur d'impression PDF. Le chemin
    source contenant espaces et accents est encode proprement via System.Uri.
    Chrome headless plante si le chemin de SORTIE contient des espaces ou des
    accents : on imprime donc dans un fichier temporaire sans espace, puis on
    deplace le resultat vers le chemin demande.

.EXAMPLE
    powershell -File scripts\render-pdf.ps1 -Html rapport.html -Pdf rapport.pdf
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Html,
    [Parameter(Mandatory = $true)][string]$Pdf,
    [string]$ChromePath,
    [string]$EdgePath
)

$ErrorActionPreference = 'Stop'

function Find-Browser {
    param([string]$Preferred, [string]$EnvVar)
    $candidates = @()
    if ($Preferred) { $candidates += $Preferred }
    if ($EnvVar)   { $candidates += $EnvVar }
    $candidates += @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )
    $hit = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $hit) { throw "Chrome ou Edge introuvable pour l'impression PDF." }
    return $hit
}

$Html = [System.IO.Path]::GetFullPath($Html)
$Pdf  = [System.IO.Path]::GetFullPath($Pdf)

if (-not (Test-Path $Html)) { throw "HTML introuvable : $Html" }

$browser = Find-Browser -Preferred $ChromePath -EnvVar $EdgePath
# System.Uri encode correctement les espaces et les accents dans file:///
$srcUri = ([System.Uri]$Html).AbsoluteUri

# Repertoire de profil isole : evite tout conflit avec un Chrome deja ouvert
$profileDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pve9-pdf-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

# Chrome headless plante si le chemin de sortie contient des espaces ou des
# accents : on imprime dans un fichier temporaire sans espace, puis on deplace.
$tmpPdf = Join-Path ([System.IO.Path]::GetTempPath()) ('pve9-out-' + [Guid]::NewGuid().ToString('N') + '.pdf')

$args = @(
    '--headless'
    '--disable-gpu'
    '--disable-extensions'
    '--no-first-run'
    '--no-sandbox'
    '--disable-setuid-sandbox'
    '--no-pdf-header-footer'
    "--user-data-dir=$profileDir"
    "--print-to-pdf=$tmpPdf"
    $srcUri
)

Write-Host "  moteur    : $browser" -ForegroundColor DarkGray
Write-Host "  source    : $srcUri" -ForegroundColor DarkGray

$proc = Start-Process -FilePath $browser -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
if ($proc.ExitCode -ne 0) {
    throw "Chrome headless a echoue (code $($proc.ExitCode))."
}
if (-not (Test-Path $tmpPdf)) {
    throw "Le PDF n'a pas ete produit : $tmpPdf"
}
Move-Item -Force $tmpPdf $Pdf
Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue

$size = (Get-Item $Pdf).Length
Write-Host "  pdf       : $Pdf ($([math]::Round($size/1kb,1)) ko)" -ForegroundColor Green
