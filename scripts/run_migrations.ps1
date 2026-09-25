<#
.SYNOPSIS
    Runs all Al Batal Elite database migrations against a Supabase project.

.DESCRIPTION
    Two modes:
    1. --Mode File   — Concatenates all migration SQL files into one output file
                       you paste into the Supabase SQL Editor. No API key needed.
    2. --Mode API    — Links the project and uses the Supabase CLI migration
                       command so the remote migration ledger is updated.

.PARAMETER Mode
    "File" (default) or "API".

.PARAMETER OutputPath
    Where to write the combined SQL file (File mode only).
    Default: scripts/run_all_migrations.sql

.PARAMETER ProjectRef
    Supabase project reference ID (API mode only).
    Can also be set via SUPABASE_PROJECT_REF env var.

.EXAMPLE
    # File mode — generates a SQL file you paste into SQL Editor
    .\scripts\run_migrations.ps1

    # API mode — applies pending migrations and records them remotely
    .\scripts\run_migrations.ps1 -Mode API -ProjectRef "your-project-ref"
#>

param(
    [ValidateSet("File", "API")]
    [string]$Mode = "File",
    [string]$OutputPath = "scripts\run_all_migrations.sql",
    [string]$ProjectRef = $env:SUPABASE_PROJECT_REF
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationsDir = Join-Path (Split-Path -Parent $scriptDir) "supabase\migrations"

$migrationFiles = Get-ChildItem -Path $migrationsDir -Filter "*.sql" |
    Where-Object { $_.Name -match '^\d{3}_' } |
    Sort-Object Name

if ($migrationFiles.Count -eq 0) {
    Write-Error "No migration files found in $migrationsDir"
    exit 1
}

Write-Host "`n=== Al Batal Elite — Database Migration Runner ===" -ForegroundColor Cyan
Write-Host "Found $($migrationFiles.Count) migration files:`n" -ForegroundColor Gray

foreach ($f in $migrationFiles) {
    Write-Host "  $($f.Name)" -ForegroundColor White
}

if ($Mode -eq "File") {
    $outputFile = Join-Path (Split-Path -Parent $scriptDir) $OutputPath
    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("-- Al Batal Elite — Combined Migration Script")
    [void]$sb.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("--")
    [void]$sb.AppendLine("-- Paste this into Supabase SQL Editor and click Run.")
    [void]$sb.AppendLine("-- Existing projects should use run_migrations.ps1 with the migration ledger.")
    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("SET client_min_messages = warning;")
    [void]$sb.AppendLine("")

    foreach ($f in $migrationFiles) {
        $content = Get-Content -Path $f.FullName -Raw
        [void]$sb.AppendLine("-- ────────────────────────────────────────────────────────────")
        [void]$sb.AppendLine("-- MIGRATION: $($f.Name)")
        [void]$sb.AppendLine("-- ────────────────────────────────────────────────────────────")
        [void]$sb.AppendLine($content)
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("-- All migrations included. Reload the PostgREST schema cache.")
    [void]$sb.AppendLine("NOTIFY pgrst, 'reload schema';")
    [void]$sb.AppendLine("-- Run verify_schema.sql to confirm the schema.")
    [void]$sb.AppendLine("-- ============================================================")

    $sb.ToString() | Out-File -FilePath $outputFile -Encoding UTF8

    Write-Host "`n✅ Combined SQL file written to:" -ForegroundColor Green
    Write-Host "   $outputFile" -ForegroundColor Yellow
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "   1. Open Supabase Dashboard → SQL Editor" -ForegroundColor White
    Write-Host "   2. Paste the contents of the file" -ForegroundColor White
    Write-Host "   3. Click 'Run'" -ForegroundColor White
    Write-Host "   4. Run verify_schema.sql to confirm" -ForegroundColor White
    exit 0
}

if ($Mode -ne "API") {
    Write-Error "Unsupported migration mode: $Mode"
    exit 1
}

$accessToken = $env:SUPABASE_ACCESS_TOKEN
if (-not $ProjectRef -or -not $accessToken) {
    Write-Error @"
API mode requires:
  SUPABASE_PROJECT_REF   = your project reference ID
  SUPABASE_ACCESS_TOKEN  = your Supabase management API token
"@
    exit 1
}

Write-Host "`nTarget: project $ProjectRef" -ForegroundColor Yellow
Write-Host "Using the Supabase CLI migration ledger." -ForegroundColor Gray

& supabase link --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) {
    Write-Error "Supabase project linking failed."
    exit 1
}

& supabase db push --linked --yes
if ($LASTEXITCODE -ne 0) {
    Write-Error "Supabase migration push failed; no schema reload was attempted."
    exit 1
}

& supabase db query --linked "NOTIFY pgrst, 'reload schema';"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Migrations applied, but the PostgREST schema reload failed."
    exit 1
}

Write-Host "`n✅ Pending migrations applied and PostgREST reloaded." -ForegroundColor Green
exit 0
