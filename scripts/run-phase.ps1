<#
.SYNOPSIS
    Orchestrateur du lab de test de hardening Proxmox VE 9.

.DESCRIPTION
    Enchaine les etapes du protocole de test :

      bootstrap  affiche la commande a coller dans le shell de la web UI PVE
                 pour installer la cle publique du lab (acces SSH automatise)
      baseline   collecte l'etat de securite AVANT hardening
      apply      applique un hardenur sur le noeud
      verify     collecte l'etat APRES hardening et compare au baseline
      all        baseline -> apply -> verify

    La collecte s'appuie sur guest/audit-pve.sh (lecture seule) : environ 60
    controles objectifs (CIS Debian 13 / guide PVE 9) sont evalues et stockes
    au format @@CHECK <ID> <PASS|FAIL|NA|INFO> <detail>, ce qui rend le
    avant/apres directement comparable.

.PARAMETER Phase
    bootstrap | baseline | apply | verify | all

.PARAMETER Target
    core        (defaut) script du lab, traceable, applique le guide PVE 9
    abua        PVE-9-Hardening (abualialfatih23) - assistant interactif pilote
    mrmasterbay proxmox-security-hardening (MrMasterbay) - assistant interactif
                agressif, depot GitHub archive

.EXAMPLE
    powershell -File scripts\run-phase.ps1 -Phase bootstrap
    powershell -File scripts\run-phase.ps1 -Phase baseline
    powershell -File scripts\run-phase.ps1 -Phase apply -Target core
    powershell -File scripts\run-phase.ps1 -Phase verify
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('bootstrap', 'baseline', 'apply', 'verify', 'all')]
    [string]$Phase,

    [ValidateSet('core', 'abua', 'mrmasterbay', 'anssi', 'ceph')]
    [string]$Target = 'core',
    
    [string]$SshHost   = '127.0.0.1',
    [int]$SshPort      = 2222,
    [string]$User      = 'root',
    [string]$KeyPath,
    [ValidateRange(1, 4)]
    [int]$Level        = 1,
    [int]$AbuaLevel    = 3,
    [string]$AuditExtra = '',
    [int]$SshTimeout   = 3600,
    [switch]$RunFunc,
    [switch]$SkipVendorVerify
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------- chemins
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$labRoot    = Split-Path -Parent $scriptDir
$guestDir   = Join-Path $labRoot 'guest'
$vendorDir  = Join-Path $labRoot 'vendor'
$artifacts  = Join-Path $labRoot 'artifacts'
if (-not $KeyPath) { $KeyPath = Join-Path $labRoot '.keys\id_ed25519' }
$knownHosts = Join-Path $labRoot '.keys\known_hosts'

New-Item -ItemType Directory -Force -Path $artifacts | Out-Null

# Timeout d'execution SSH : les installations de paquets (apt) et les scripts
# de durcissement peuvent depasser plusieurs minutes.
$env:SSH_TIMEOUT = [string]$SshTimeout

$sshOpts = @(
    '-i', $KeyPath,
    '-p', $SshPort,
    '-o', 'StrictHostKeyChecking=no',
    '-o', "UserKnownHostsFile=$knownHosts",
    '-o', 'ConnectTimeout=10',
    '-o', 'LogLevel=ERROR'
)

# ----------------------------------------------------------------- helpers
function Write-Step { param([string]$m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }

function Test-Ssh {
    $python = "C:\Users\Louis\AppData\Local\Programs\Python\Python313\python.exe"
    $tool = Join-Path $scriptDir 'ssh-tool.py'
    $args = @('test', $SshHost, $SshPort, $User, $KeyPath)
    try {
        & $python $tool @args 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Invoke-Ssh {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$StandardInput
    )
    $python = "C:\Users\Louis\AppData\Local\Programs\Python\Python313\python.exe"
    $tool = Join-Path $scriptDir 'ssh-tool.py'
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $stdinArg = ''
        if ($StandardInput) {
            $stdinArg = ($StandardInput -join "`n") + "`n"
        }
        $args = @('exec', $SshHost, $SshPort, $User, $KeyPath, $Command, $stdinArg)
        $out = & $python $tool @args 2> $errFile
        $code = $LASTEXITCODE
        $err = (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)
        if ($out -is [array]) { $out = ($out -join "`n") }
        return [pscustomobject]@{ ExitCode = $code; Out = $out; Err = $err }
    } finally {
        Remove-Item $errFile -ErrorAction SilentlyContinue
    }
}

function Copy-ToGuest {
    param([string]$Local, [string]$Remote)
    $python = "C:\Users\Louis\AppData\Local\Programs\Python\Python313\python.exe"
    $tool = Join-Path $scriptDir 'ssh-tool.py'
    $args = @('put', $SshHost, $SshPort, $User, $KeyPath, $Local, $Remote)
    & $python $tool @args 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Echec du transfert de $Local vers $Remote" }
    # Verification de l'integrite du fichier distant : un transfert tronque
    # (connexion coupee) produisait un fichier VIDE, execute sans rien faire
    # et bloquait le cycle indefiniment. On refuse de continuer dans ce cas.
    $localSize = (Get-Item $Local).Length
    $check = Invoke-Ssh -Command "stat -c %s $Remote 2>/dev/null || echo 0"
    $remoteSize = 0
    if ($check.Out -match '(\d+)') { $remoteSize = [int]$Matches[1] }
    if ($remoteSize -ne $localSize) {
        throw "Transfert incomplet : $Remote fait $remoteSize octets au lieu de $localSize"
    }
    Write-Host "  transfere : $(Split-Path -Leaf $Local) -> $Remote ($remoteSize octets)" -ForegroundColor DarkGray
}

# Injecte la cle publique du lab dans le fichier PARTAGE de Proxmox.
# Indispensable : apres une restauration de snapshot, /etc/pve/priv/authorized_keys
# est reinitialise et l'acces SSH par cle est perdu.
function Install-SshPubKey {
    if (-not $SshPubKey) { return }
    $pubFile = "$KeyPath.pub"
    if (-not (Test-Path $pubFile)) { return }
    $pub = (Get-Content $pubFile -Raw).Trim()
    if (-not $pub) { return }
    # /root/.ssh/authorized_keys est un symlink vers /etc/pve/priv/authorized_keys
    $cmd = "grep -qF '$pub' /etc/pve/priv/authorized_keys 2>/dev/null || " +
           "printf '%s\n' '$pub' >> /etc/pve/priv/authorized_keys; " +
           "chmod 0600 /etc/pve/priv/authorized_keys 2>/dev/null || true; " +
           "systemctl reload pvedaemon 2>/dev/null || true; " +
           "grep -c 'ssh-' /etc/pve/priv/authorized_keys 2>/dev/null || echo 0"
    $res = Invoke-Ssh -Command $cmd
    $n = 0
    if ($res.Out -match '(\d+)') { $n = [int]$Matches[1] }
    Write-Host ("  cle publique du lab installee dans /etc/pve/priv/authorized_keys ({0} cle(s))" -f $n) -ForegroundColor DarkGray
}

function Assert-Ssh {
    if (-not (Test-Ssh)) {
        Write-Host ""
        Write-Host "Connexion SSH impossible vers $User@$SshHost`:$SshPort" -ForegroundColor Red
        Write-Host "Verifiez :" -ForegroundColor Red
        Write-Host "  1. la VM est demarree et l'installation de PVE est terminee"
        Write-Host "  2. la redirection NAT est active (port $SshPort -> 22)"
        Write-Host "  3. la cle publique du lab est installee (phase bootstrap)"
        throw "SSH indisponible"
    }
}

# --------------------------------------------------------------- phase: bootstrap
function Invoke-Bootstrap {
    Write-Step 'bootstrap - injection de la cle publique du lab'
    if (-not (Test-Path $KeyPath)) {
        throw "Cle absente : $KeyPath. Lancez d'abord scripts\prepare-vm.ps1."
    }
    $pub = (Get-Content "$KeyPath.pub" -Raw).Trim()
    Write-Host "Cle publique du lab :" -ForegroundColor Green
    Write-Host "  $pub" -ForegroundColor Green
    Write-Host ""
    Write-Host "Collez cette commande dans Web UI -> Noeud -> Shell :" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  bash -c 'mkdir -p /root/.ssh && chmod 700 /root/.ssh && echo `"$pub`" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'" -ForegroundColor White
    Write-Host ""
    Write-Host "Ou copiez le script bootstrap-sshkey.sh dans la VM et lancez :" -ForegroundColor DarkGray
    Write-Host "  bash /root/bootstrap-sshkey.sh '$pub'" -ForegroundColor White
    Write-Host ""
    Write-Host "Note : sur PVE, /root/.ssh/authorized_keys est un lien vers" -ForegroundColor DarkGray
    Write-Host "/etc/pve/priv/authorized_keys (partage entre les noeuds du cluster)." -ForegroundColor DarkGray
}

# --------------------------------------------------------------- phase: baseline
function Invoke-FuncTest {
    param([string]$Label)

    Assert-Ssh

    # Deux suites de tests fonctionnels :
    #   - func-test-pve.sh : le durcissement ne casse pas Proxmox
    #   - func-test-os.sh  : le durcissement ne casse pas l'OS lui-meme
    #     (systemd, sysctl, montages, DNS, PAM, cron, dpkg, journalisation...)
    $suites = @(
        @{ Guest = 'func-test-pve.sh'; Remote = '/root/func-test-pve.sh'; Pattern = 'fonctionnel-'; Tag = 'PVE' },
        @{ Guest = 'func-test-os.sh';  Remote = '/root/func-test-os.sh';  Pattern = 'fonctionnel-os-'; Tag = 'OS' }
    )

    $remote = "/tmp/func-$Label"
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $artifacts "func-$Label-$stamp"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $local = Join-Path $dir 'fonctionnel.txt'
    $py = "C:\Users\Louis\AppData\Local\Programs\Python\Python313\python.exe"
    $tool = Join-Path $scriptDir 'ssh-tool.py'

    $totalFail = 0
    $combined = New-Object System.Collections.ArrayList

    foreach ($suite in $suites) {
        $localSuite = Join-Path $guestDir $suite.Guest
        if (-not (Test-Path $localSuite)) {
            Write-Warning "Suite de tests absente : $($suite.Guest)"
            continue
        }
        Copy-ToGuest $localSuite $suite.Remote | Out-Null
        Invoke-Ssh -Command "chmod +x $($suite.Remote)" | Out-Null

        Write-Host ("  tests fonctionnels {0} ({1})..." -f $suite.Tag, $Label) -ForegroundColor DarkGray
        # Le code de sortie est le nombre d'echecs : on ne le considere pas comme fatal
        $res = Invoke-Ssh -Command "bash $($suite.Remote) $remote"
        $failures = @($res.Out -split "`n" | Where-Object { $_ -match '^@@TEST\s+\S+\s+FAIL' }).Count
        $totalFail += $failures

        # On recupere le rapport horodate pour l'archiver
        $ls = Invoke-Ssh -Command "ls -1 $remote 2>/dev/null | grep '$($suite.Pattern).*\.txt' | head -1"
        $remoteFile = ($ls.Out -split "`n" | Where-Object { $_ -match '\.txt$' } | Select-Object -First 1)
        if ($remoteFile) {
            $remoteFile = $remoteFile.Trim()
            $gargs = @('get', $SshHost, $SshPort, $User, $KeyPath, "$remote/$remoteFile", (Join-Path $dir "$($suite.Tag)-$remoteFile"))
            & $py $tool @gargs 2>&1 | Out-Null
        }

        # Rapport unifie : on concatene les lignes @@TEST des deux suites
        [void]$combined.Add("===== SUITE $($suite.Tag) =====")
        foreach ($line in ($res.Out -split "`n")) {
            if ($line -match '^@@TEST\s+') { [void]$combined.Add($line) }
        }
        [void]$combined.Add("")

        Write-Host ("    {0} : {1} echec(s)" -f $suite.Tag, $failures) -ForegroundColor $(if ($failures) { 'Yellow' } else { 'Green' })
    }

    $combined -join "`n" | Set-Content -Path $local -Encoding UTF8
    Write-Host ("  rapport fonctionnel : {0} ({1} echec(s))" -f $local, $totalFail) -ForegroundColor $(if ($totalFail) { 'Yellow' } else { 'Green' })
    return $local
}

function Invoke-Audit {
    param([string]$Label, [string]$AuditExtra = '')

    Assert-Ssh
    Install-SshPubKey
    Copy-ToGuest (Join-Path $guestDir 'audit-pve.sh') '/root/audit-pve.sh'
    Invoke-Ssh -Command 'chmod +x /root/audit-pve.sh' | Out-Null
    # Scripts d'audit supplementaires (anssi, ceph)
    foreach ($extra in ($AuditExtra -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $extraLocal = Join-Path $guestDir "audit-$extra.sh"
        if (Test-Path $extraLocal) {
            Copy-ToGuest $extraLocal "/root/audit-$extra.sh"
            Invoke-Ssh -Command "chmod +x /root/audit-$extra.sh" | Out-Null
        }
    }

    $remote = "/tmp/audit-$Label"
    Write-Host "  collecte de l'etat ($Label)..." -ForegroundColor DarkGray
    $envPrefix = if ($AuditExtra) { "AUDIT_EXTRA=$AuditExtra " } else { '' }
    $res = Invoke-Ssh -Command "${envPrefix}bash /root/audit-pve.sh $remote"
    if ($res.ExitCode -ne 0) {
        Write-Host $res.Out -ForegroundColor DarkGray
        Write-Host $res.Err -ForegroundColor Red
        throw "La collecte d'audit a echoue (code $($res.ExitCode))"
    }

    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir    = Join-Path $artifacts "$Label-$stamp"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # On recupere le fichier produit par le script (checks.tsv + audit.txt)
    $python = "C:\Users\Louis\AppData\Local\Programs\Python\Python313\python.exe"
    $tool = Join-Path $scriptDir 'ssh-tool.py'
    $args1 = @('get', $SshHost, $SshPort, $User, $KeyPath, "$remote/audit.txt", (Join-Path $dir 'audit.txt'))
    & $python $tool @args1 2>&1 | Out-Null
    $args2 = @('get', $SshHost, $SshPort, $User, $KeyPath, "$remote/checks.tsv", (Join-Path $dir 'checks.tsv'))
    & $python $tool @args2 2>&1 | Out-Null

    $summary = ($res.Out -split "`n" | Where-Object { $_ -match '^PASS=' }) -join ''
    Write-Host "  rapport : $dir\audit.txt" -ForegroundColor Green
    if ($summary) { Write-Host "  synthese : $summary" -ForegroundColor Green }
    return $dir
}

# ----------------------------------------------------------------- phase: apply
function Invoke-Apply {
    Assert-Ssh
    Install-SshPubKey
    Write-Step "apply - cible : $Target"

    switch ($Target) {
        'core' {
            Copy-ToGuest (Join-Path $guestDir 'apply-homesec-core.sh') '/root/apply-homesec-core.sh'
            Write-Host "  execution du script du lab, niveau CIS $Level (controles traces du guide PVE 9)..." -ForegroundColor DarkGray
            $res = Invoke-Ssh -Command "LEVEL=$Level bash /root/apply-homesec-core.sh"
            $res.Out -split "`n" | Where-Object { $_ -match '^\s*(===|\[|    )' } | Select-Object -Last 60 |
                ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            if ($res.ExitCode -ne 0) {
                Write-Host $res.Err -ForegroundColor Red
                throw "apply-homesec-core.sh a echoue (code $($res.ExitCode))."
            }
        }
        'anssi' {
            Copy-ToGuest (Join-Path $guestDir 'apply-anssi.sh') '/root/apply-anssi.sh'
            Write-Host "  execution ANSSI niveau $Level..." -ForegroundColor DarkGray
            $res = Invoke-Ssh -Command "LEVEL=$Level bash /root/apply-anssi.sh"
            $res.Out -split "`n" | Where-Object { $_ -match '^\s*(===|\[|    )' } | Select-Object -Last 40 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            if ($res.ExitCode -ne 0) { Write-Host $res.Err -ForegroundColor Red; throw "apply-anssi.sh a echoue (code $($res.ExitCode))." }
        }
        'ceph' {
            Copy-ToGuest (Join-Path $guestDir 'apply-ceph.sh') '/root/apply-ceph.sh'
            Write-Host "  execution Ceph hardening..." -ForegroundColor DarkGray
            $res = Invoke-Ssh -Command 'bash /root/apply-ceph.sh'
            $res.Out -split "`n" | Select-Object -Last 20 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            if ($res.ExitCode -ne 0) { Write-Host $res.Err -ForegroundColor Red; throw "apply-ceph.sh a echoue (code $($res.ExitCode))." }
        }
        'abua' {
            $src = Join-Path $vendorDir 'abualialfatih23\PVE9-Harden-FinalVersion-v1.sh'
            if (-not (Test-Path $src)) { throw "Artefact manquant : $src (lancer fetch-vendor.ps1)" }
            Copy-ToGuest $src '/root/PVE9-Harden-FinalVersion-v1.sh'
            Write-Host "  assistant interactif pilote : menu 1 -> niveau $AbuaLevel -> menu 5 (quitter)" -ForegroundColor DarkGray
            # PTY obligatoire : le script utilise 'tput' et 'clear' pour la barre de progression.
            $answers = @('1', "$AbuaLevel", '5')
            $res = Invoke-Ssh -Command 'TERM=xterm script -q -e -c "bash /root/PVE9-Harden-FinalVersion-v1.sh" /dev/null' -StandardInput $answers
            $res.Out -split "`n" | Select-Object -Last 80 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            if ($res.ExitCode -ne 0) {
                Write-Host $res.Err -ForegroundColor Red
                throw "Le script abualialfatih23 a echoue (code $($res.ExitCode))."
            }
        }
        'mrmasterbay' {
            $src = Join-Path $vendorDir 'mrmasterbay\seuwurity.sh'
            if (-not (Test-Path $src)) { throw "Artefact manquant : $src (lancer fetch-vendor.ps1)" }
            Copy-ToGuest $src '/root/seuwurity.sh'
            $ansFile = Join-Path $labRoot 'answers\mrmasterbay.txt'
            # On ne garde ni les commentaires ni les lignes vides du fichier de reponses
            $answers = if (Test-Path $ansFile) {
                Get-Content $ansFile | ForEach-Object { ($_ -split '#', 2)[0].Trim() } |
                    Where-Object { $_ -ne '' }
            } else { @('y') }
            Write-Host "  assistant interactif pilote avec $($answers.Count) reponses" -ForegroundColor DarkGray
            $res = Invoke-Ssh -Command 'TERM=xterm script -q -e -c "bash /root/seuwurity.sh" /dev/null' -StandardInput $answers
            $res.Out -split "`n" | Select-Object -Last 80 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            if ($res.ExitCode -ne 0) {
                Write-Host $res.Err -ForegroundColor Red
                throw "Le script MrMasterbay a echoue (code $($res.ExitCode))."
            }
        }
    }
}

# ---------------------------------------------------------------- phase: verify
function Invoke-Verify {
    param([string]$AuditExtra = '', [string]$FuncBefore = '', [string]$FuncAfter = '')
    $dir = Invoke-Audit -Label 'after' -AuditExtra $AuditExtra
    $baseline = Get-ChildItem $artifacts -Directory -Filter 'baseline-*' |
                Sort-Object Name | Select-Object -Last 1
    if (-not $baseline) {
        Write-Warning "Aucun baseline trouve. Lancez d'abord -Phase baseline."
        return
    }
    Write-Step "compare - $([System.IO.Path]::GetFileName($baseline.FullName)) vs $([System.IO.Path]::GetFileName($dir))"
    $cargs = @{ Before = $baseline.FullName; After = $dir }
    if ($FuncBefore -and $FuncAfter) {
        $cargs['BeforeFunc'] = $FuncBefore
        $cargs['AfterFunc'] = $FuncAfter
    }
    & (Join-Path $scriptDir 'compare.ps1') @cargs
}

# ------------------------------------------------------------------- dispatch
if (-not $SkipVendorVerify) {
    Write-Host "Verification de l'integrite des artefacts..." -ForegroundColor DarkGray
    & (Join-Path $scriptDir 'verify-vendor.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Artefacts alteres : lancer fetch-vendor.ps1 -Force." }
}

switch ($Phase) {
    'bootstrap' { Invoke-Bootstrap }
    'baseline'  {
        Invoke-Audit -Label 'baseline' -AuditExtra $AuditExtra | Out-Null
        if ($RunFunc) { Invoke-FuncTest -Label 'before' | Out-Null }
    }
    'apply'     { Invoke-Apply }
    'verify'    {
        $fb = ''
        $fa = ''
        if ($RunFunc) {
            $fa = Invoke-FuncTest -Label 'after'
            $fbefore = Get-ChildItem $artifacts -Directory -Filter 'func-before-*' |
                       Sort-Object Name | Select-Object -Last 1
            if ($fbefore) { $fb = Join-Path $fbefore.FullName 'fonctionnel.txt' }
        }
        Invoke-Verify -AuditExtra $AuditExtra -FuncBefore $fb -FuncAfter $fa
    }
    'all'       {
        Invoke-Audit -Label 'baseline' -AuditExtra $AuditExtra | Out-Null
        $fb = ''
        if ($RunFunc) { $fb = Invoke-FuncTest -Label 'before' }
        Invoke-Apply
        $fa = ''
        if ($RunFunc) { $fa = Invoke-FuncTest -Label 'after' }
        Invoke-Verify -AuditExtra $AuditExtra -FuncBefore $fb -FuncAfter $fa
    }
}

Write-Host "`nPhase '$Phase' terminee." -ForegroundColor Green
