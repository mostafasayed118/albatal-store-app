<#
.SYNOPSIS
    Generates a single SQL file from all migration files.

.DESCRIPTION
    Reads all numbered migration SQL files from supabase/migrations/
    and concatenates them in order into one file you can paste into
    the Supabase SQL Editor.

.PARAMETER Output
    Output file path. Default: scripts/run_all_migrations.sql
#>
param([string]$Output = "scripts\run_all_migrations.sql")

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationsDir = Join-Path (Split-Path -Parent $scriptDir) "supabase\migrations"
$outFile = Join-Path (Split-Path -Parent $scriptDir) $Output

# Get migration files sorted by name (001_, 002_, etc.)
$files = Get-ChildItem -Path $migrationsDir -Filter "*.sql" |
    Where-Object { $_.Name -match '^\d{3}_' } |
    Sort-Object Name

if ($files.Count -eq 0) {
    Write-Error "No migration files found in $migrationsDir"
    exit 1
}

Write-Host "Combining $($files.Count) migration files...`n" -ForegroundColor Cyan

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("-- Al Batal Elite — Combined Migration Script")
[void]$sb.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("--")
[void]$sb.AppendLine("-- Paste into Supabase SQL Editor → Run")
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("SET client_min_messages = warning;")
[void]$sb.AppendLine("")

foreach ($f in $files) {
    $content = Get-Content -Path $f.FullName -Raw
    [void]$sb.AppendLine("-- ────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine("-- MIGRATION: $($f.Name)")
    [void]$sb.AppendLine("-- ────────────────────────────────────────────────────────────")
    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine("")
    Write-Host "  ✅ $($f.Name)" -ForegroundColor Green
}

[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("-- All migrations complete. Run verify_schema.sql to confirm.")
[void]$sb.AppendLine("-- ============================================================")

# Ensure output directory exists
$outDir = Split-Path -Parent $outFile
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$sb.ToString() | Out-File -FilePath $outFile -Encoding UTF8

$fileSize = [math]::Round((Get-Item $outFile).Length / 1KB, 1)
Write-Host "`n✅ Written to: $outFile ($fileSize KB)" -ForegroundColor Green
Write-Host "`nNext: Open Supabase SQL Editor → Paste → Run" -ForegroundColor Yellow
