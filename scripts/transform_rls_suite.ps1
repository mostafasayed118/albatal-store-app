# Transform test_rls_adversarial.sql for `supabase db query --file` compatibility.
# Semantics preserved:
#  - drop \echo psql meta-commands (display-only; db query rejects them)
#  - top-level `PERFORM fn();` -> `SELECT fn();` (identical call, PERFORM is
#    only valid inside plpgsql)
#  - inject one consolidated JSON results query before ROLLBACK (db query
#    returns only the last result set)
$src = 'c:\flutter_projects\albatal-candidate-b74d326\supabase\tests\test_rls_adversarial.sql'
$dst = 'c:\flutter_projects\albatal_store\scripts\run_rls_adversarial_dbquery.sql'

$lines = Get-Content $src |
  Where-Object { $_ -notmatch '^\s*\\echo' } |
  ForEach-Object { $_ -replace '^PERFORM ', 'SELECT ' }

$rb = ($lines | Select-String -Pattern '^ROLLBACK;' | Select-Object -First 1).LineNumber

$agg = @(
  ''
  'SELECT'
  "  count(*) FILTER (WHERE status = 'FAIL') AS failed,"
  "  count(*) FILTER (WHERE status = 'PASS') AS passed,"
  '  count(*) AS total,'
  "  json_agg(json_build_object('id', test_id, 'desc', description, 'expected', expected, 'actual', actual, 'status', status) ORDER BY test_id) FILTER (WHERE status = 'FAIL') AS failures"
  'FROM _rls_results;'
  ''
)

$out = $lines[0..($rb - 2)] + $agg + $lines[($rb - 1)..($lines.Count - 1)]
Set-Content -Path $dst -Value $out -Encoding UTF8

Write-Host "ROLLBACK at line $rb; wrote $((Get-Content $dst).Count) lines to $dst"
$left = Select-String -Path $dst -Pattern '^\s*\\|^PERFORM '
Write-Host "Remaining meta-commands/bare PERFORM: $(@($left).Count)"
