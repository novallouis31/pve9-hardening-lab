<#
.SYNOPSIS
    Configure la VM VirtualBox "proxmox" pour acceuillir Proxmox VE 9.x de facon
    exploitable comme cible de test de hardening.

.DESCRIPTION
    Corrige la configuration par defaut d'une VM VirtualBox "vide" qui est
    inexploitable pour Proxmox VE 9 :

      - RAM 64 Mo           -> 8 Go   (l'installeur PVE 9 demande >= 2 Go)
      - PAE/LongMode off    -> on     (Debian 13 est 64 bits : sans long mode, pas de boot)
      - 1 CPU               -> 4
      - disque 2 Mo         -> 64 Go  (ZFS/LVM + ISO + conteneurs)
      - pas de port-forward -> 8006 (web) et 2222 (SSH) exposes sur 127.0.0.1
      - pas de port serie  -> ttyS0 journalise dans <VM>\console.log (securite deSecours)

    A executer VM ETEINTE. La commande refuse de tourner si la VM tourne.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\prepare-vm.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$VmName        = 'proxmox',
    [int]$MemoryMB        = 8192,
    [int]$CpuCount        = 4,
    [int]$DiskGB          = 64,
    [int]$WebHostPort     = 8006,
    [int]$SshHostPort     = 2222,
    [string]$IsoPath      = "$env:USERPROFILE\Downloads\proxmox-ve_9.2-1.iso",
    [string]$Firmware      = 'bios',   # 'bios' (defaut fiable) ou 'efi'
    [switch]$SkipDiskResize,
    [switch]$NoIso  # PVE installe : detache l'ISO et boote sur le disque
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- utilitaires
function Find-VBoxManage {
    $candidates = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    if ($candidates) { return ($candidates | Select-Object -First 1) }
    $cmd = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "VBoxManage.exe introuvable. Installez VirtualBox ou corrigez le PATH."
}

function Invoke-VBox {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& $VBox @Args 2>&1 | ForEach-Object { $_.ToString() })
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage $($Args -join ' ') a echoue (code $LASTEXITCODE) :`n$($out -join "`n")"
    }
    return $out
}

$VBox = Find-VBoxManage
Write-Host "VirtualBox : $VBox" -ForegroundColor DarkGray
Write-Host ("Version    : " + (Invoke-VBox '--version')) -ForegroundColor DarkGray

# ------------------------------------------------------------------- controles
$vms = Invoke-VBox 'list' 'vms'
if (-not ($vms -match [regex]::Escape('"' + $VmName + '"'))) {
    throw "VM introuvable : '$VmName'. VMs disponibles :`n$($vms -join "`n")"
}

$running = Invoke-VBox 'list' 'runningvms'
if ($running -match [regex]::Escape('"' + $VmName + '"')) {
    throw "La VM '$VmName' est en cours d'execution. Eteignez-la (VBoxManage controlvm $VmName acpipowerbutton ou GUI) puis relancez."
}

$vmDir = Join-Path "$env:USERPROFILE\VirtualBox VMs" $VmName
$vdi = Join-Path $vmDir "$VmName.vdi"
$consoleLog = Join-Path $vmDir 'console.log'

Write-Host ""
Write-Host "=== Configuration de la VM '$VmName' ===" -ForegroundColor Cyan

# ------------------------------------------------------------- CPU / memoire
Invoke-VBox 'modifyvm' $VmName '--os-type=Debian_64' | Out-Null
Invoke-VBox 'modifyvm' $VmName "--memory=$MemoryMB" | Out-Null
Invoke-VBox 'modifyvm' $VmName "--cpus=$CpuCount" | Out-Null
Write-Host "  [ok] os-type=Debian_64 memory=${MemoryMB}Mo cpus=$CpuCount"

# Les drapeaux 64 bits sont implicitement actifs avec ostype=Debian_64 ;
# on les force explicitement pour lever toute ambiguite.
Invoke-VBox 'modifyvm' $VmName '--x86-pae=on' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--x86-long-mode=on' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--hwvirtex=on' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--nested-paging=on' | Out-Null
Write-Host "  [ok] pae/long-mode/hwvirtex/nested-paging = on"

# ------------------------------------------------------------------ firmware
Invoke-VBox 'modifyvm' $VmName "--firmware=$Firmware" | Out-Null
Invoke-VBox 'modifyvm' $VmName '--boot1=dvd' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--boot2=disk' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--acpi=on' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--ioapic=on' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--rtc-use-utc=on' | Out-Null
Write-Host "  [ok] firmware=$Firmware boot=dvd,disk acpi/ioapic/rtc-utc=on"

# ------------------------------------------------------------------- reseau
Invoke-VBox 'modifyvm' $VmName '--nic1=nat' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--nic-type1=virtio' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--cable-connected1=on' | Out-Null
# On recreate proprement les regles de redirection NAT.
# Syntaxe VBox 7.2 : la forme "--nat-pf1=delete=nom" affichee dans l'aide est
# refusee par le parser ; il faut passer les arguments separes.
foreach ($rule in @('pve-web', 'pve-ssh')) {
    try {
        Invoke-VBox 'modifyvm' $VmName '--nat-pf1' 'delete' $rule | Out-Null
        Write-Host "  [ok] ancienne regle NAT '$rule' supprimee" -ForegroundColor DarkGray
    } catch {
        # La regle n'existait pas encore : cas nominal au premier lancement
        Write-Host "  [..] regle NAT '$rule' inexistante (rien a supprimer)" -ForegroundColor DarkGray
    }
}
Invoke-VBox 'modifyvm' $VmName "--nat-pf1=pve-web,tcp,127.0.0.1,$WebHostPort,,8006" | Out-Null
Invoke-VBox 'modifyvm' $VmName "--nat-pf1=pve-ssh,tcp,127.0.0.1,$SshHostPort,,22" | Out-Null
Write-Host "  [ok] NAT : 127.0.0.1:$WebHostPort -> 8006 (web) | 127.0.0.1:$SshHostPort -> 22 (ssh)"

# -------------------------------------------------------- port serie (secours)
# VBox 7.2 : plus d'argument IRQ, la base seule suffit (IRQ attribuee auto).
Invoke-VBox 'modifyvm' $VmName '--uart1=0x3F8' | Out-Null
Invoke-VBox 'modifyvm' $VmName '--uart-mode1' 'file' $consoleLog | Out-Null
Invoke-VBox 'modifyvm' $VmName '--uart-type1=16550A' | Out-Null
Write-Host "  [ok] port serie ttyS0 -> $consoleLog"

# --------------------------------------------------------------------- ISO
# VBox 7.2 : le type d'attachement optique s'appelle 'dvddrive' ('dvd' est refuse).
if ($NoIso) {
    try {
        Invoke-VBox 'storageattach' $VmName '--storagectl=IDE' '--port=1' '--device=0' '--type=dvddrive' '--medium=emptydrive' | Out-Null
        Write-Host "  [ok] ISO detachee (PVE installe) - la VM boote sur le disque"
    } catch {
        Write-Host "  [..] aucun lecteur DVD attache (rien a detacher)" -ForegroundColor DarkGray
    }
    Invoke-VBox 'modifyvm' $VmName '--boot1=disk' | Out-Null
    Invoke-VBox 'modifyvm' $VmName '--boot2=dvd' | Out-Null
    Write-Host "  [ok] ordre de boot : disk, dvd"
}
elseif (Test-Path $IsoPath) {
    Invoke-VBox 'storageattach' $VmName '--storagectl=IDE' '--port=1' '--device=0' '--type=dvddrive' "--medium=$IsoPath" | Out-Null
    Write-Host "  [ok] ISO attache : $IsoPath"
} else {
    Write-Warning "ISO introuvable : $IsoPath (attachez-la manuellement ou corrigez -IsoPath)"
}

# ------------------------------------------------------------------- disque
if (-not $SkipDiskResize) {
    if (Test-Path $vdi) {
        $needMB = $DiskGB * 1024
        Invoke-VBox 'modifymedium' 'disk' $vdi "--resize=$needMB" | Out-Null
        Write-Host "  [ok] disque redimensionne a $DiskGB Go"
    } else {
        Write-Warning "Disque introuvable : $vdi"
    }
}

# ------------------------------------------------------------ cle SSH du lab
$labRoot = Split-Path -Parent $PSScriptRoot
$keyDir = Join-Path $labRoot '.keys'
$keyPath = Join-Path $keyDir 'id_ed25519'
if (-not (Test-Path $keyPath)) {
    New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
    & ssh-keygen -t ed25519 -a 100 -N '""' -C 'pve9-hardening-lab' -f $keyPath | Out-Null
    Write-Host "  [ok] cle SSH du lab generee : $keyPath"
} else {
    Write-Host "  [..] cle SSH du lab deja presente : $keyPath"
}

# ------------------------------------------------------------------ recap
Write-Host ""
Write-Host "=== Configuration finale ===" -ForegroundColor Cyan
$info = Invoke-VBox 'showvminfo' $VmName '--machinereadable'
$keys = 'name', 'ostype', 'memory', 'cpus', 'firmware', 'nic1', 'nictype1', 'natpf1', 'uart1', 'uartmode1', 'boot1', 'boot2'
foreach ($k in $keys) {
    $line = $info | Where-Object { $_ -like "$k=*" } | Select-Object -First 1
    if ($line) { Write-Host ("  {0,-12} {1}" -f $k, ($line -split '=', 2)[1]) }
}
$cfg = [ordered]@{
    vmName = $VmName; memoryMB = $MemoryMB; cpuCount = $CpuCount; diskGB = $DiskGB
    firmware = $Firmware; iso = $IsoPath
    webUrl = "https://127.0.0.1:$WebHostPort/"; sshTarget = "root@127.0.0.1 -p $SshHostPort"
    sshKey = $keyPath; consoleLog = $consoleLog
}
$cfgPath = Join-Path $labRoot 'vm-config.json'
$cfg | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding UTF8
Write-Host ""
Write-Host "  Recapitulatif ecrit : $cfgPath" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes :" -ForegroundColor Green
Write-Host "  1. Demarrer la VM et installer Proxmox VE 9.2 depuis l'ISO (voir docs/PLAN-DE-TEST.md)"
Write-Host "  2. Definir un mot de passe root a l'installation"
Write-Host "  3. Ouvrir https://127.0.0.1:$WebHostPort/ -> Noeud -> Shell"
Write-Host "  4. Coller la commande d'amorcage de la cle SSH (generee par run-phase.ps1 -Phase bootstrap)"
