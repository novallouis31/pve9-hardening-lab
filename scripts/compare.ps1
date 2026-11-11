<#
.SYNOPSIS
    Compare deux instantanes d'audit (avant / apres hardening) et produit un
    rapport Markdown, HTML et PDF detaille.

.DESCRIPTION
    Les deux entrees sont des repertoires produits par run-phase.ps1, contenant :
      audit.txt   sortie complete du collecteur
      checks.tsv  lignes "ID<TAB>STATUT<TAB>DETAIL"

    Le rapport distingue :
      - REGRESSION : un controle qui passait et ne passe plus (priorite haute)
      - AMELIORATION: un controle qui echouait et passe
      - INCHANGE   : statut identique
      - NOUVEAU / PERDU : controle present d'un seul cote

    Sortie : comparatif-<ts>.md, comparatif-<ts>.html, comparatif-<ts>.pdf

.EXAMPLE
    powershell -File scripts\compare.ps1 -Before artifacts\baseline-xxx -After artifacts\after-yyy
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [string]$ReportPath,
    [string]$PdfPath,
    [switch]$NoPdf
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-Checks {
    param([string]$Dir)
    $map = [ordered]@{}
    $file = Join-Path $Dir 'audit.txt'
    if (-not (Test-Path $file)) { throw "audit.txt introuvable dans $Dir" }
    foreach ($line in (Get-Content $file)) {
        if ($line -match '^@@CHECK\s+(\S+)\s+(\S+)\s*(.*)$') {
            $map[$Matches[1]] = [pscustomobject]@{
                Id = $Matches[1]; Status = $Matches[2]; Detail = $Matches[3]
            }
        }
    }
    return $map
}

$beforeChecks = Read-Checks $Before
$afterChecks  = Read-Checks $After

$regressions = @(); $improvements = @(); $unchanged = @(); $newChecks = @(); $lostChecks = @()

foreach ($id in $beforeChecks.Keys) {
    $b = $beforeChecks[$id]
    if (-not $afterChecks.Contains($id)) { $lostChecks += $b; continue }
    $a = $afterChecks[$id]
    if ($b.Status -eq $a.Status) { $unchanged += [pscustomobject]@{ Id=$id; Before=$b; After=$a } }
    elseif ($b.Status -eq 'PASS' -and $a.Status -ne 'PASS') {
        $regressions += [pscustomobject]@{ Id=$id; Before=$b; After=$a }
    } elseif ($b.Status -ne 'PASS' -and $a.Status -eq 'PASS') {
        $improvements += [pscustomobject]@{ Id=$id; Before=$b; After=$a }
    } else {
        $unchanged += [pscustomobject]@{ Id=$id; Before=$b; After=$a }
    }
}
foreach ($id in $afterChecks.Keys) {
    if (-not $beforeChecks.Contains($id)) { $newChecks += $afterChecks[$id] }
}

function Get-Count { param($m, $s) ($m | Where-Object { $_.Status -eq $s }).Count }

$pb = Get-Count $beforeChecks.Values 'PASS'
$fb = Get-Count $beforeChecks.Values 'FAIL'
$pa = Get-Count $afterChecks.Values  'PASS'
$fa = Get-Count $afterChecks.Values  'FAIL'
$delta = $pa - $pb

Write-Host ""
Write-Host "=== Comparatif de posture de securite ===" -ForegroundColor Cyan
Write-Host ("Avant : PASS={0} FAIL={1}" -f $pb, $fb)
Write-Host ("Apres : PASS={0} FAIL={1}" -f $pa, $fa)
Write-Host ("Delta : {0:+#;-#;0} controles conformes" -f $delta)
Write-Host ""
Write-Host ("Regressions  : {0}" -f $regressions.Count) -ForegroundColor $(if ($regressions.Count) { 'Red' } else { 'Green' })
Write-Host ("Ameliorations: {0}" -f $improvements.Count) -ForegroundColor Green
Write-Host ("Inchanges    : {0}" -f $unchanged.Count) -ForegroundColor DarkGray
Write-Host ("Nouveaux     : {0}" -f $newChecks.Count) -ForegroundColor Cyan
Write-Host ("Perdus       : {0}" -f $lostChecks.Count) -ForegroundColor Yellow
Write-Host ""

if ($regressions.Count) {
    Write-Host "--- REGRESSIONS (a analyser) ---" -ForegroundColor Red
    $regressions | ForEach-Object {
        Write-Host ("  {0}" -f $_.Id) -ForegroundColor Red
        Write-Host ("      avant : {0} - {1}" -f $_.Before.Status, $_.Before.Detail) -ForegroundColor DarkGray
        Write-Host ("      apres : {0} - {1}" -f $_.After.Status,  $_.After.Detail)  -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ------------------------------------------------------------ noms de fichiers
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $ReportPath) { $ReportPath = Join-Path (Split-Path -Parent $After) "comparatif-$stamp.md" }
if (-not $PdfPath)    { $PdfPath    = [System.IO.Path]::ChangeExtension($ReportPath, '.pdf') }
$HtmlPath = [System.IO.Path]::ChangeExtension($ReportPath, '.html')

$meta = [ordered]@{
    beforeDir = $Before; afterDir = $After
    stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    passBefore = $pb; passAfter = $pa; failBefore = $fb; failAfter = $fa; delta = $delta
    regressions = $regressions.Count; improvements = $improvements.Count
    unchanged = $unchanged.Count; new = $newChecks.Count; lost = $lostChecks.Count
}

# --------------------------------------------------------------- tableaux MD
$mdTables = [ordered]@{}
if ($regressions.Count) {
    $mdTables['Regressions'] = @(@('Controle','Avant','Apres','Detail')) + @($regressions | ForEach-Object { ,@("``$($_.Id)``", $_.Before.Status, $_.After.Status, $_.After.Detail) })
}
if ($improvements.Count) {
    $mdTables['Ameliorations'] = @(@('Controle','Avant','Apres','Detail')) + @($improvements | ForEach-Object { ,@("``$($_.Id)``", $_.Before.Status, $_.After.Status, $_.After.Detail) })
}
$mdTables['Controles en echec restants (apres)'] = @(@('Controle','Statut','Detail')) + @($afterChecks.Values | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object { ,@("``$($_.Id)``", $_.Status, $_.Detail) })
# Tableau detaille complet : un tableau par categorie de controle (OS, PVE, USR, SYS),
# avec statut avant/apres, evolution et detail.
$categories = $afterChecks.Keys | Where-Object { $_ -notmatch '^__' } | ForEach-Object { ($_ -split '\.')[0] } | Sort-Object -Unique
foreach ($cat in $categories) {
    $catName = switch ($cat) {
        'OS'  { 'Systeme d exploitation (OS)' }
        'PVE' { 'Proxmox VE (PVE)' }
        'USR' { 'Utilisateurs (USR)' }
        'SYS' { 'Systeme (SYS)' }
        default { $cat }
    }
    $rows = @()
    $ids = $afterChecks.Keys | Where-Object { $_ -like "$cat.*" } | Sort-Object
    foreach ($id in $ids) {
        $a = $afterChecks[$id]
        $bs = if ($beforeChecks.Contains($id)) { $beforeChecks[$id].Status } else { '-' }
        $bDetail = if ($beforeChecks.Contains($id)) { $beforeChecks[$id].Detail } else { '' }
        $evol = if ($bs -eq $a.Status) { 'inchange' }
                elseif ($bs -eq 'PASS' -and $a.Status -ne 'PASS') { 'REGRESSION' }
                elseif ($bs -ne 'PASS' -and $a.Status -eq 'PASS') { 'amelioration' }
                else { 'modifie' }
        $rows += ,@("``$id``", $bs, $a.Status, $evol, $a.Detail)
    }
    $mdTables["Detail - $catName"] = @(@('Controle','Avant','Apres','Evolution','Detail (apres)')) + @($rows)
}

# ------------------------------------------------------------------- rendu MD
$md = @()
$md += "# Comparatif de hardening - Proxmox VE 9"
$md += ""
$md += "- **Avant** : ``$Before``"
$md += "- **Apres** : ``$After``"
$md += "- **Genere le** : $($meta.stamp)"
$md += ""
$md += "## Synthese"
$md += ""
$md += "| Indicateur | Avant | Apres | Delta |"
$md += "|---|---:|---:|---:|"
$md += "| Controles conformes (PASS) | $pb | $pa | $(if ($delta -ge 0) { '+' } else { '' })$delta |"
$md += "| Controles en echec (FAIL) | $fb | $fa | $(if (-$delta -ge 0) { '+' } else { '' })(-$delta) |"
$md += "| Regressions | - | $($meta.regressions) | |"
$md += "| Ameliorations | - | $($meta.improvements) | |"
$md += ""
foreach ($k in $mdTables.Keys) {
    $t = $mdTables[$k]
    $md += "## $k"
    $md += ""
    $md += ('| ' + ($t[0] -join ' | ') + ' |')
    $md += ('|' + (($t[0] | ForEach-Object { '---' }) -join '|') + '|')
    for ($i = 1; $i -lt $t.Count; $i++) { $md += ('| ' + ($t[$i] -join ' | ') + ' |') }
    $md += ""
}
$md | Set-Content -Path $ReportPath -Encoding UTF8
Write-Host "Rapport Markdown : $ReportPath" -ForegroundColor Green

# ------------------------------------------------------------------ rendu HTML
$htmlEsc = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

$badgeClass = { param($s) switch ($s) {
    'PASS' { 'pass' } 'FAIL' { 'fail' } 'NA' { 'na' } default { 'info' }
} }

function New-HtmlTable {
    param([System.Collections.ArrayList]$Rows, [string]$Title, [System.Collections.Hashtable]$Ctx)
    if ($Rows.Count -le 1) { return "" }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("<h3>$Title</h3>")
    [void]$sb.AppendLine('<table>')
    [void]$sb.Append('<thead><tr>')
    foreach ($h in $Rows[0]) { [void]$sb.Append("<th>$(& $Ctx['esc'] $h)</th>") }
    [void]$sb.AppendLine('</tr></thead><tbody>')
    for ($i = 1; $i -lt $Rows.Count; $i++) {
        [void]$sb.Append('<tr>')
        for ($c = 0; $c -lt $Rows[0].Count; $c++) {
            $v = $Rows[$i][$c]
            $cls = ""
            if ($c -gt 0 -and $c -le 2 -and $v) { $cls = " class=""$(& $Ctx['badge'] $v)""" }
            if ($c -eq 3 -and $v) {
                $ev = ([string]$v).ToLower()
                if ($ev -in @('amelioration','regression','inchange','modifie')) { $cls = " class=""$ev""" }
            }
            [void]$sb.Append("<td$cls>$(& $Ctx['esc'] $v)</td>")
        }
        [void]$sb.AppendLine('</tr>')
    }
    [void]$sb.AppendLine('</tbody></table>')
    return $sb.ToString()
}

$ctx = @{ esc = $htmlEsc; badge = $badgeClass }
$sectionsHtml = ""
foreach ($k in $mdTables.Keys) {
    $rows = [System.Collections.ArrayList]@()
    foreach ($r in $mdTables[$k]) { [void]$rows.Add(@($r)) }
    $sectionsHtml += New-HtmlTable -Rows $rows -Title $k -Ctx $ctx
}

$css = @'
:root { --pass:#0a7d33; --fail:#c62828; --na:#6b7280; --info:#2563eb; --ink:#111827; }
* { box-sizing:border-box; }
body { font-family:"Segoe UI",Calibri,Arial,sans-serif; color:var(--ink); margin:0; padding:0 0 24px; font-size:11pt; line-height:1.5; }
header { border-bottom:3px solid #111827; padding:18px 28px 12px; }
header h1 { font-size:19pt; margin:0 0 4px; }
header .meta { color:#4b5563; font-size:9.5pt; }
main { padding:0 28px; }
.kpi { display:flex; gap:12px; margin:18px 0 6px; flex-wrap:wrap; }
.kpi div { border:1px solid #d1d5db; border-radius:6px; padding:10px 14px; min-width:110px; background:#fafafa; }
.kpi .v { font-size:16pt; font-weight:600; }
.kpi .l { font-size:8.5pt; color:#4b5563; text-transform:uppercase; letter-spacing:.4px; }
.good { color:var(--pass); } .bad { color:var(--fail); }
h3 { font-size:12pt; border-bottom:1px solid #e5e7eb; padding-bottom:4px; margin:26px 0 10px; }
table { border-collapse:collapse; width:100%; margin-bottom:8px; font-size:9.5pt; }
th { background:#111827; color:#fff; text-align:left; padding:6px 8px; font-weight:600; }
td { border-bottom:1px solid #e5e7eb; padding:5px 8px; vertical-align:top; }
tr:nth-child(even) td { background:#f9fafb; }
td.pass, td.fail, td.na, td.info { text-align:center; font-weight:600; width:74px; }
td.pass { color:var(--pass); } td.fail { color:var(--fail); } td.na { color:var(--na); } td.info { color:var(--info); }\ntd.amelioration { color:var(--pass); font-weight:600; } td.regression { color:var(--fail); font-weight:600; } td.inchange { color:var(--na); } td.modifie { color:var(--info); }
code { font-family:Consolas,"Courier New",monospace; font-size:9pt; background:#f3f4f6; padding:1px 4px; border-radius:3px; }
footer { padding:14px 28px 0; color:#6b7280; font-size:8.5pt; border-top:1px solid #e5e7eb; margin-top:24px; }
@page { size:A4; margin:14mm 12mm 14mm 12mm; }
'@

$sumHtml = ""
$sumHtml += "<div class=""kpi"">"
$sumHtml += "<div><div class=""v"">$pb</div><div class=""l"">PASS avant</div></div>"
$sumHtml += "<div><div class=""v"">$pa</div><div class=""l"">PASS apres</div></div>"
$sumHtml += "<div><div class=""v $(if ($delta -ge 0) { 'good' } else { 'bad' })"">$delta</div><div class=""l"">Delta conformes</div></div>"
$sumHtml += "<div><div class=""v"">$($meta.regressions)</div><div class=""l"">Regressions</div></div>"
$sumHtml += "<div><div class=""v"">$($meta.improvements)</div><div class=""l"">Ameliorations</div></div>"
$sumHtml += "</div>"

$html = @"
<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<title>Comparatif de hardening - Proxmox VE 9</title>
<style>$css</style></head>
<body>
<header>
  <h1>Comparatif de hardening &mdash; Proxmox VE 9</h1>
  <div class="meta">
    Avant : <code>$($meta.beforeDir)</code> &nbsp;|&nbsp;
    Apres : <code>$($meta.afterDir)</code> &nbsp;|&nbsp;
    Genere le $($meta.stamp)
  </div>
</header>
<main>
  <h3>Synthese</h3>
  $sumHtml
  $sectionsHtml
</main>
<footer>
  Genere par pve9-hardening-lab / scripts\compare.ps1 &mdash; collecteur lecture seule guest\audit-pve.sh.
  Controles codes PASS / FAIL / NA (non applicable dans ce lab) / INFO.
</footer>
</body></html>
"@
$html | Set-Content -Path $HtmlPath -Encoding UTF8
Write-Host "Rapport HTML     : $HtmlPath" -ForegroundColor Green

# --------------------------------------------------------------------- PDF
if (-not $NoPdf) {
    & (Join-Path $scriptDir 'render-pdf.ps1') -Html $HtmlPath -Pdf $PdfPath
}
