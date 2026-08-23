# Provenance check: compare remote supabase_migrations.schema_migrations.statements
# against committed migration files for versions 022,024,025,026,027,028.
# READ-ONLY: only SELECTs against the remote ledger; writes nothing to the DB.
# Normalization: strip trailing semicolons, collapse all whitespace, ignore case
# of keywords is NOT applied (content compared byte-for-byte after whitespace fold).

# NOTE: supabase CLI prints its "Initialising login role..." banner to stderr,
# which PowerShell treats as a NativeCommandError under Stop. Keep Continue and
# validate JSON output explicitly instead.
$ErrorActionPreference = "Continue"
$versions = @("022","024","025","026","027","028")
$files = @{
  "022" = "supabase/migrations/022_repair_confirm_cod_payment.sql"
  "024" = "supabase/migrations/024_hardening_rpcs_policies.sql"
  "025" = "supabase/migrations/025_race_safe_state_machine.sql"
  "026" = "supabase/migrations/026_forward_repair_confirm_cod_payment_and_grants.sql"
  "027" = "supabase/migrations/027_add_payments_insert_policy.sql"
  "028" = "supabase/migrations/028_reclose_payments_insert_policy.sql"
}

function Normalize([string]$text) {
  # remove comment-only lines are KEPT (remote keeps them); fold whitespace, drop semicolons
  $t = $text -replace ";", ""
  $t = $t -replace "\s+", " "
  return $t.Trim()
}

$results = @()
foreach ($v in $versions) {
  $json = cmd /c "supabase db query --linked `"SELECT array_to_string(statements, E'\n') AS body FROM supabase_migrations.schema_migrations WHERE version = '$v';`" -o json 2>nul"
  $parsed = ($json -join "`n") | ConvertFrom-Json
  if (-not $parsed) { throw "No remote ledger row for version $v" }
  $remoteBody = $parsed[0].body
  $localBody  = Get-Content -Raw -Encoding UTF8 $files[$v]

  $rn = Normalize $remoteBody
  $ln = Normalize $localBody

  $md5 = [System.Security.Cryptography.MD5]::Create()
  $rHash = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($rn))).Replace("-","").ToLower()
  $lHash = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($ln))).Replace("-","").ToLower()

  $match = if ($rHash -eq $lHash) { "MATCH" } else { "MISMATCH" }
  $results += [PSCustomObject]@{
    version      = $v
    file         = Split-Path -Leaf $files[$v]
    local_md5    = $lHash
    remote_md5   = $rHash
    status       = $match
    remote_chars = $rn.Length
    local_chars  = $ln.Length
  }
}
$results | Format-Table -AutoSize
if ($results | Where-Object { $_.status -ne "MATCH" }) { Write-Host "RESULT: PROVENANCE MISMATCH DETECTED" } else { Write-Host "RESULT: ALL 6 MIGRATIONS MATCH COMMITTED CONTENT" }
