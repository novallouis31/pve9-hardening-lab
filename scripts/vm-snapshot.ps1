<#
.SYNOPSIS
    Gestion des snapshots VirtualBox de la VM de test Proxmox VE 9.

.DESCRIPTION
    Un test de hardening mute profondement le systeme. Le snapshot est le seul
    moyen de revenir a l'etat "propre" sans reinstaller. Ce script encapsule
    create / list / restore / delete.

.EXAMPLE
    powershell -File scripts\vm-snapshot.ps1 -Action Create -Name pre-hardening
    powershell -File scripts\vm-snapshot.ps1 -Action Restore -Name pre-hardening
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'List', 'Restore', 'Delete')]
    [string]$Action,

    [string]$VmName = 'proxmox',
    [string]$Name   = 'pre-hardening',
    [string]$Description = 'PVE9 hardening lab'
)

$ErrorActionPreference = 'Stop'

$vbox = @(
    "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
    "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vbox) { throw "VBoxManage.exe introuvable." }

function Invoke-VBox {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& $vbox @Args 2>&1 | ForEach-Object { $_.ToString() })
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage $($Args -join ' ') a echoue :`n$($out -join "`n")"
    }
    return $out
}

switch ($Action) {
    'Create' {
        # Un snapshot "en ligne" capture l'etat memoire + disque : il faut la VM
        # eteinte pour un snapshot propre et restaurable de facon fiable.
        $running = Invoke-VBox 'list' 'runningvms'
        if ($running -match [regex]::Escape('"' + $VmName + '"')) {
            Write-Warning "La VM est en marche : le snapshot sera 'en ligne' (memoire capturee)."
            Write-Warning "Eteignez la VM pour un snapshot disque complet et fiable."
        }
        Invoke-VBox 'snapshot' $VmName 'take' $Name '--description' $Description | Out-Null
        Write-Host "Snapshot '$Name' cree." -ForegroundColor Green
        Invoke-VBox 'snapshot' $VmName 'list'
    }
    'List' {
        Invoke-VBox 'snapshot' $VmName 'list'
    }
    'Restore' {
        $list = Invoke-VBox 'snapshot' $VmName 'list'
        # NB : -match/-notmatch sur un tableau FILTRE les elements. On force un
        # test global en filtrant les lignes qui correspondent AU NOM du snapshot.
        $found = @($list) | Where-Object { $_ -match [regex]::Escape($Name) } |
                 Where-Object { $_ -match 'Name:' }
        if (-not $found) {
            throw "Snapshot '$Name' introuvable.`n$($list -join "`n")"
        }
        Write-Host "Restauration du snapshot '$Name'..." -ForegroundColor Yellow
        Invoke-VBox 'snapshot' $VmName 'restore' $Name | Out-Null
        Write-Host "Restauration effectuee. La VM est revenue a l'etat du snapshot." -ForegroundColor Green
    }
    'Delete' {
        Invoke-VBox 'snapshot' $VmName 'delete' $Name | Out-Null
        Write-Host "Snapshot '$Name' supprime." -ForegroundColor Green
    }
}
