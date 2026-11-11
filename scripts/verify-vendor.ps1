<#
.SYNOPSIS
    Verifie l'integrite des artefacts de hardening telecharges (SHA256SUMS.txt).

.EXAMPLE
    powershell -File scripts\verify-vendor.ps1
#>
[CmdletBinding()]
param(
    [string]$VendorDir
)

$ErrorActionPreference = 'Stop'
if (-not $VendorDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $VendorDir = Join-Path $scriptDir '..\vendor'
}
$VendorDir = [System.IO.Path]::GetFullPath($VendorDir)
$sumFile = Join-Path $VendorDir 'SHA256SUMS.txt'

if (-not (Test-Path $sumFile)) {
    throw "SHA256SUMS.txt absent. Lancez d'abord fetch-vendor.ps1."
}

$ok = 0; $ko = 0
foreach ($line in (Get-Content $sumFile)) {
    if ($line -match '^\s*([0-9a-fA-F]{64})\s+(.+)$') {
        $expected = $Matches[1].ToLower()
        $rel = $Matches[2].Trim()
        $path = Join-Path $VendorDir ($rel -replace '/', '\')
        if (-not (Test-Path $path)) {
            Write-Host "[MANQUANT] $rel" -ForegroundColor Red; $ko++; continue
        }
        $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower()
        if ($actual -eq $expected) {
            Write-Host "[OK]      $rel" -ForegroundColor Green; $ok++
        } else {
            Write-Host "[ALTERE]  $rel" -ForegroundColor Red
            Write-Host "          attendu $expected"
            Write-Host "          obtenu  $actual"
            $ko++
        }
    }
}

Write-Host ""
Write-Host "Artefacts conformes : $ok / $($ok + $ko)"
if ($ko -gt 0) { exit 1 }
exit 0
