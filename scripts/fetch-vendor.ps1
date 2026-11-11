<#
.SYNOPSIS
    Telecharge les artefacts de hardening Proxmox VE 9 en version PINNEE (commit SHA),
    puis genere le fichier SHA256SUMS.txt pour verifier l'integrite.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\fetch-vendor.ps1
#>
[CmdletBinding()]
param(
    [string]$VendorDir,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $VendorDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $VendorDir = Join-Path $scriptDir '..\vendor'
}
$VendorDir = [System.IO.Path]::GetFullPath($VendorDir)

# Chaque artefact est fige sur un commit SHA : le contenu ne peut pas changer
# sous nos pieds entre deux executions, ce qui rend les tests reproductibles.
$Artifacts = @(
    @{ Id = 'homesec-pve9-guide'
       Repo = 'HomeSecExplorer/Proxmox-Hardening-Guide'
       Sha  = 'd630ff29ca5f89db2a9b416e88634d385fa7f708'
       Path = 'docs/pve9-hardening-guide.md'
       Dest = 'homesec/pve9-hardening-guide.md' }

    @{ Id = 'homesec-readme'
       Repo = 'HomeSecExplorer/Proxmox-Hardening-Guide'
       Sha  = 'd630ff29ca5f89db2a9b416e88634d385fa7f708'
       Path = 'README.md'
       Dest = 'homesec/README.md' }

    @{ Id = 'abua-script'
       Repo = 'abualialfatih23/PVE-9-Hardening'
       Sha  = 'c9909d0422a77f89ea3d5ebc61ca4284bacd0b5a'
       Path = 'PVE9-Harden-FinalVersion-v1.sh'
       Dest = 'abualialfatih23/PVE9-Harden-FinalVersion-v1.sh' }

    @{ Id = 'abua-readme'
       Repo = 'abualialfatih23/PVE-9-Hardening'
       Sha  = 'c9909d0422a77f89ea3d5ebc61ca4284bacd0b5a'
       Path = 'README.md'
       Dest = 'abualialfatih23/README.md' }

    @{ Id = 'mm-script'
       Repo = 'MrMasterbay/proxmox-security-hardening'
       Sha  = '44e0154bedfa5ecde2f557710c7108fc734c423e'
       Path = 'seuwurity.sh'
       Dest = 'mrmasterbay/seuwurity.sh' }

    @{ Id = 'mm-readme'
       Repo = 'MrMasterbay/proxmox-security-hardening'
       Sha  = '44e0154bedfa5ecde2f557710c7108fc734c423e'
       Path = 'README.md'
       Dest = 'mrmasterbay/README.md' }

    @{ Id = 'ssh-guide'
       Repo = 'alexandreravelli/Securing-SSH-Access-on-Proxmox-VE-9'
       Sha  = 'c35a64617523299fa4e5396a72016973f6422510'
       Path = 'README.md'
       Dest = 'ssh-guide/README.md' }
)

New-Item -ItemType Directory -Force -Path $VendorDir | Out-Null

$lines = @('# SHA256SUMS - artefacts de hardening PVE 9 (verifie par verify-vendor.ps1)')
$failures = 0

foreach ($a in $Artifacts) {
    $dest = Join-Path $VendorDir $a.Dest
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null

    if ((Test-Path $dest) -and -not $Force) {
        Write-Host "[skip] $($a.Id) deja present ($($a.Dest))" -ForegroundColor DarkGray
    } else {
        $url = "https://raw.githubusercontent.com/$($a.Repo)/$($a.Sha)/$($a.Path)"
        try {
            Write-Host "[get ] $($a.Id) <- $($a.Repo)@$($a.Sha.Substring(0,7))" -ForegroundColor Cyan
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 60
        } catch {
            Write-Host "[FAIL] $($a.Id) : $($_.Exception.Message)" -ForegroundColor Red
            $failures++
            continue
        }
    }

    $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
    $lines += "$hash  $($a.Dest.Replace('\','/'))"
}

$sumFile = Join-Path $VendorDir 'SHA256SUMS.txt'
$lines | Set-Content -Path $sumFile -Encoding UTF8
Write-Host ""
Write-Host "Vendor dir : $VendorDir"
Write-Host "Checksums  : $sumFile"
Write-Host "Artefacts  : $($Artifacts.Count - $failures)/$($Artifacts.Count)"

if ($failures -gt 0) { exit 1 }
exit 0
