# Al Batal Elite — repeatable audit + verification harness
#
# Re-runs the scoring pass and the verification pass described in
# docs/audit/2026-09-15/01-rubric.md and writes raw evidence under
# .openclaw/tmp/audit/rerun/.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/run-audit.ps1
#   powershell ... -File scripts/audit/run-audit.ps1 -SkipBuild     # faster pass
#   powershell ... -File scripts/audit/run-audit.ps1 -WithCoverage  # adds coverage
#
# Exit code: 0 = harness green (all gates pass), 1 = at least one gate failed.

param(
  [switch]$SkipBuild,
  [switch]$WithCoverage
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$outDir = ".openclaw/tmp/audit/rerun"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$results = [ordered]@{}

function Invoke-Gate {
  param([string]$Name, [string]$Command, [string]$LogFile)
  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  $started = Get-Date
  cmd /c "$Command > `"$LogFile`" 2>&1"
  $code = $LASTEXITCODE
  $secs = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
  $tail = (Get-Content $LogFile -Tail 3 -ErrorAction SilentlyContinue) -join ' | '
  Write-Host ("exit={0} ({1}s) :: {2}" -f $code, $secs, $tail)
  $script:results[$Name] = @{ exit = $code; seconds = $secs; log = $LogFile }
  return $code
}

$fails = 0

# 1. Static analysis / lint (must be clean)
if ((Invoke-Gate -Name 'flutter analyze' -Command 'flutter analyze --no-pub' -LogFile "$outDir/analyze.txt") -ne 0) { $fails++ }

# 2. Format gate (no reformat required)
if ((Invoke-Gate -Name 'dart format' -Command 'dart format --set-exit-if-changed --output=none lib test' -LogFile "$outDir/format.txt") -ne 0) { $fails++ }

# 3. Test suite (must be fully green)
if ((Invoke-Gate -Name 'flutter test' -Command 'flutter test --reporter compact' -LogFile "$outDir/test.txt") -ne 0) { $fails++ }
$testLine = (Select-String -Path "$outDir/test.txt" -Pattern '\+\d+( -\d+)?: (All tests passed|Some tests failed)' | Select-Object -Last 1).Line
if ($testLine) { $results['flutter test summary'] = @{ value = $testLine.Trim() } }

# 4. Build (Android debug smoke build)
if (-not $SkipBuild) {
  if ((Invoke-Gate -Name 'flutter build apk --debug' -Command 'flutter build apk --debug' -LogFile "$outDir/build_apk.txt") -ne 0) { $fails++ }
} else {
  Write-Host "`n=== flutter build apk --debug : SKIPPED (--SkipBuild) ===" -ForegroundColor Yellow
}

# 5. Coverage (optional: slower, ~25 min)
if ($WithCoverage) {
  if ((Invoke-Gate -Name 'flutter test --coverage' -Command 'flutter test --coverage' -LogFile "$outDir/coverage_test.txt") -eq 0) {
    $lf = (Select-String -Path coverage/lcov.info -Pattern '^LF:' | ForEach-Object { [int]($_.Line -replace 'LF:','') } | Measure-Object -Sum).Sum
    $lh = (Select-String -Path coverage/lcov.info -Pattern '^LH:' | ForEach-Object { [int]($_.Line -replace 'LH:','') } | Measure-Object -Sum).Sum
    if ($lf -gt 0) {
      $pct = [math]::Round(100 * $lh / $lf, 1)
      Write-Host "coverage: $pct% ($lh/$lf)"
      "coverage: $pct% ($lh/$lf)" | Out-File "$outDir/coverage.txt"
    }
  }
}

# 6. Secret sweep on the working tree (tracked files only)
Write-Host "`n=== secret sweep (tracked files) ===" -ForegroundColor Cyan
$tracked = git ls-files
$suspicious = $tracked | Where-Object { $_ -match '^\.env$|\.jks$|\.keystore$|key\.properties$|^secrets-.*\.env$' }
$leakHits = 0
if ($suspicious) {
  Write-Host "suspicious tracked files: $($suspicious -join ', ')"
  $leakHits = 1
}
# Real Supabase JWTs are long base64url strings (anon/service keys). Any long
# token committed on purpose needs triage: decode the role claim and hard-fail
# on privileged roles (service_role bypasses RLS entirely), while reporting a
# public-by-design `anon` key as a warned finding (see AUD-014 in the ledger).
$tokenHits = git grep -n -E 'eyJ[A-Za-z0-9_-]{40,}' -- 'lib/*' 'config/*' 'supabase/*' 2>$null
$privileged = @()
foreach ($hit in @($tokenHits)) {
  $file = ($hit -split ':', 2)[0]
  $tok = [regex]::Match($hit, 'eyJ[A-Za-z0-9_\.\-]+').Value.TrimEnd('.')
  $role = 'undecodable'
  try {
    $seg = $tok.Split('.')[1]
    $seg = $seg.Replace('-', '+').Replace('_', '/')
    switch ($seg.Length % 4) { 2 { $seg += '==' } 3 { $seg += '=' } }
    $role = ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($seg)) | ConvertFrom-Json).role
  } catch { $role = 'undecodable' }
  if ($role -eq 'anon') {
    Write-Host "WARN triaged: public-by-design 'anon' key committed in $file (AUD-014 - owner to placeholder/rotate)" -ForegroundColor Yellow
  } else {
    Write-Host "FAIL $role key committed in $file - rotate immediately" -ForegroundColor Red
    $privileged += $hit
  }
}
if ($privileged.Count -gt 0) { $leakHits = 1 }
if ($leakHits -eq 0) { Write-Host "clean: no keystores, privileged keys or untriaged secrets detected" }
$results['secret sweep'] = @{ exit = $leakHits }
if ($leakHits -ne 0) { $fails++ }

# 7. Dependency snapshot (informational)
Invoke-Gate -Name 'flutter pub outdated' -Command 'flutter pub outdated' -LogFile "$outDir/pub_outdated.txt" | Out-Null

# Summary
Write-Host "`n================ SUMMARY ================" -ForegroundColor Green
$results.GetEnumerator() | ForEach-Object {
  $v = $_.Value
  if ($v.ContainsKey('exit')) {
    Write-Host ("{0,-28} exit={1,-3} {2}s" -f $_.Key, $v.exit, $v.seconds)
  } else {
    Write-Host ("{0,-28} {1}" -f $_.Key, $v.value)
  }
}
Write-Host ("failed gates: {0}" -f $fails) -ForegroundColor $(if ($fails -eq 0) { 'Green' } else { 'Red' })
Write-Host "evidence: $outDir"

exit $(if ($fails -eq 0) { 0 } else { 1 })
