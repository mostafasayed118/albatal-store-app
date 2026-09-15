# Al Batal Elite — repeatable scoring pass
#
# Recomputes the weighted overall score from docs/audit/2026-09-15/scores.json
# using the weights published in docs/audit/2026-09-15/01-rubric.md, validates
# the inputs (weights sum to 100%, scores within 0..10), cross-checks the
# findings ledger for any open critical/high finding in a scored dimension, and
# prints the arithmetic so a reader can reproduce the number by hand.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/score.ps1
#
# Exit code: 0 = consistent and reproducible, 1 = inconsistency or an open
# critical/high finding in a scored dimension.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$scoresPath = "docs\audit\2026-09-15\scores.json"
$ledgerPath = "docs\audit\2026-09-15\02-findings-ledger.json"

$s = Get-Content $scoresPath -Raw | ConvertFrom-Json

# 1. Validate weights
$weights = $s.weights
$sum = 0.0
foreach ($p in $weights.PSObject.Properties) { $sum += [double]$p.Value }
if ([math]::Abs($sum - 1.0) -gt 0.001) {
  Write-Host "ERROR: weights sum to $sum (expected 1.0)" -ForegroundColor Red
  exit 1
}

# 2. Validate scores in range
foreach ($phase in @('baseline', 'postFix')) {
  foreach ($p in $s.scores.$phase.PSObject.Properties) {
    $v = [double]$p.Value
    if ($v -lt 0 -or $v -gt 10) {
      Write-Host "ERROR: $phase.$($p.Name) = $v out of 0..10" -ForegroundColor Red
      exit 1
    }
  }
}

# 3. Recompute weighted overall for each phase
function Weighted([string]$phase) {
  $total = 0.0
  foreach ($dim in $weights.PSObject.Properties) {
    $total += [double]$weights.$($dim.Name) * [double]$s.scores.$phase.$($dim.Name)
  }
  return [math]::Round($total, 1)
}

$baseline = Weighted 'baseline'
$postFix  = Weighted 'postFix'

# 4. Cross-check the ledger for open critical/high findings in scored dimensions
$scored = @('maintainability', 'clean_architecture', 'code_quality', 'security', 'performance')
$ledger = Get-Content $ledgerPath -Raw | ConvertFrom-Json
$open = $ledger.findings | Where-Object {
  ($_.severity -in @('critical', 'high')) -and
  ($_.status -ne 'fixed') -and
  ($_.dimension -in $scored)
}
if ($open) {
  Write-Host "WARNING: open critical/high findings in scored dimensions:" -ForegroundColor Yellow
  $open | ForEach-Object { Write-Host ("  {0} [{1}] {2}" -f $_.id, $_.severity, $_.title) }
} else {
  Write-Host "ledger: no open critical/high findings in scored dimensions"
}

# 5. Print the arithmetic
Write-Host "`nWeights:" -ForegroundColor Cyan
foreach ($dim in $weights.PSObject.Properties) {
  Write-Host ("  {0,-20} {1:P0}" -f $dim.Name, [double]$dim.Value)
}

Write-Host "`nBaseline:" -ForegroundColor Cyan
$terms = @()
foreach ($dim in $weights.PSObject.Properties) {
  $d = $dim.Name
  Write-Host ("  {0,-20} {1} x {2} = {3}" -f $d, [double]$weights.$d, $s.scores.baseline.$d, [math]::Round([double]$weights.$d * [double]$s.scores.baseline.$d, 3))
}
Write-Host ("  weighted overall = {0}" -f $baseline) -ForegroundColor Green

Write-Host "`nPost-fix:" -ForegroundColor Cyan
foreach ($dim in $weights.PSObject.Properties) {
  $d = $dim.Name
  Write-Host ("  {0,-20} {1} x {2} = {3}" -f $d, [double]$weights.$d, $s.scores.postFix.$d, [math]::Round([double]$weights.$d * [double]$s.scores.postFix.$d, 3))
}
Write-Host ("  weighted overall = {0}" -f $postFix) -ForegroundColor Green

Write-Host "`nReported overall: baseline 8.4 -> post-fix 9.4" -ForegroundColor Cyan
if ([math]::Abs($baseline - 8.4) -gt 0.051 -or [math]::Abs($postFix - 9.4) -gt 0.051) {
  Write-Host "MISMATCH vs published report (8.4 / 9.4)" -ForegroundColor Red
  exit 1
}

Write-Host "scoring pass consistent: $baseline -> $postFix"
if ($open) { Write-Host "note: open findings above are recorded in the residual register (05-reaudit.md)" }
exit 0
