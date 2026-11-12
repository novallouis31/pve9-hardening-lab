<#
.SYNOPSIS
    Gestion de l'image de reference du lab PVE 9 (base propre) par CLONAGE.

.DESCRIPTION
    Les snapshots VirtualBox creent des disques differentiels fragiles : apres
    plusieurs restore, le disque peut ne plus demarrer. On utilise donc un
    clonage complet du disque de reference, operationnelle et fiable.

    Actions :
      Save     - Sauvegarde le disque courant comme image de reference
      Restore  - Remplace le disque du VM par un clone de l'image de reference
      Status   - Affiche l'etat de l'image de reference

.EXAMPLE
    powershell -File scripts\vm-image.ps1 -Action Save
    powershell -File scripts\vm-image.ps1 -Action Restore
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Save', 'Restore', 'Status')]
    [string]$Action,

    [string]$VmName = 'proxmox',
    [string]$ImageName = 'reference-propre.vdi'
)

$ErrorActionPreference = 'Stop'
$vbox = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbox)) { throw "VBoxManage.exe introuvable." }

$vmDir = Join-Path "$env:USERPROFILE\VirtualBox VMs" $VmName
$vdi = Join-Path $vmDir "$VmName.vdi"
$ref = Join-Path $vmDir $ImageName

function Get-VmState {
    (& $vbox showvminfo $VmName --machinereadable |
        Select-String -Pattern '^VMState=' | Select-Object -First 1).Line -replace 'VMState=', ''
}

switch ($Action) {
    'Save' {
        if ((Get-VmState) -ne 'poweroff') {
            throw "Eteignez le VM avant de sauvegarder l'image de reference."
        }
        if (Test-Path $ref) { Remove-Item $ref -Force }
        & $vbox clonemedium disk --format VDI $vdi $ref | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Echec du clonage vers $ref" }
        $sz = [math]::Round((Get-Item $ref).Length / 1MB, 1)
        Write-Host "Image de reference sauvegardee : $ref ($sz Mo)" -ForegroundColor Green
    }
    'Restore' {
        if ((Get-VmState) -ne 'poweroff') {
            throw "Eteignez le VM avant de restaurer l'image de reference."
        }
        if (-not (Test-Path $ref)) { throw "Image de reference absente : $ref" }
        # Detache le disque courant
        & $vbox storageattach $VmName --storagectl 'IDE' --port 0 --device 0 --type hdd --medium none | Out-Null
        # Clone la reference vers un disque temporaire puis attache
        $tmp = Join-Path $vmDir "$VmName-restore.vdi"
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        & $vbox clonemedium disk --format VDI $ref $tmp | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Echec du clonage de l'image de reference." }
        & $vbox storageattach $VmName --storagectl 'IDE' --port 0 --device 0 --type hdd --medium $tmp | Out-Null
        Write-Host "Image de reference restauree (clone complet, pas de disque differentiel)." -ForegroundColor Green
    }
    'Status' {
        Write-Host ("VM       : {0}" -f (Get-VmState))
        Write-Host ("Disque   : {0}" -f $vdi)
        if (Test-Path $ref) {
            Write-Host ("Reference: {0} ({1} Mo)" -f $ref, [math]::Round((Get-Item $ref).Length / 1MB, 1))
        } else {
            Write-Host "Reference: ABSENTE" -ForegroundColor Yellow
        }
    }
}
