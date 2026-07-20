<#
.SYNOPSIS
    Runs all Al Batal Elite database migrations against a Supabase project.

.DESCRIPTION
    Two modes:
    1. --Mode File   — Concatenates all migration SQL files into one output file
                       you paste into the Supabase SQL Editor. No API key needed.
    2. --Mode API    — Executes each migration via the Supabase Management API.
                       Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.

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

    # API mode — executes migrations directly
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

# ─── Get ordered migration files ────────────────────────────
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

# ════════════════════════════════════════════════════════════
#  MODE 1: FILE — Concatenate into a single SQL file
# ════════════════════════════════════════════════════════════
if ($Mode -eq "File") {

    $outputFile = Join-Path (Split-Path -Parent $scriptDir) $OutputPath
    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("-- Al Batal Elite — Combined Migration Script")
    [void]$sb.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("--")
    [void]$sb.AppendLine("-- Paste this into Supabase SQL Editor and click Run.")
    [void]$sb.AppendLine("-- For existing databases, only run NEW migrations.")
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
    [void]$sb.AppendLine("-- All migrations applied successfully!")
    [void]$sb.AppendLine("-- Run verify_schema.sql to confirm the schema is correct.")
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

# ════════════════════════════════════════════════════════════
#  MODE 2: API — Execute via Supabase Management API
# ════════════════════════════════════════════════════════════
if ($Mode -eq "API") {

    # ─── Validate credentials ────────────────────────────────
    $serviceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
    if (-not $ProjectRef -or -not $serviceRoleKey) {
        Write-Error @"
API mode requires environment variables:
  SUPABASE_PROJECT_REF   = your project reference ID
  SUPABASE_SERVICE_ROLE_KEY = your service role key

Set them and retry:
  `$env:SUPABASE_PROJECT_REF = "your-ref"
  `$env:SUPABASE_SERVICE_ROLE_KEY = "your-key"
  .\scripts\run_migrations.ps1 -Mode API
"@
        exit 1
    }

    $apiUrl = "https://api.supabase.com/v1/projects/$ProjectRef/database/query"
    $headers = @{
        "Authorization" = "Bearer $serviceRoleKey"
        "Content-Type"  = "application/json"
    }

    Write-Host "`nTarget: project $ProjectRef" -ForegroundColor Yellow
    Write-Host ""

    $success = 0
    $failed = 0

    foreach ($f in $migrationFiles) {
        $sql = Get-Content -Path $f.FullName -Raw
        Write-Host "  Running $($f.Name)... " -NoNewline -ForegroundColor White

        try {
            $body = @{ query = $sql } | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Host "✅" -ForegroundColor Green
            $success++
        }
        catch {
            $errMsg = $_.ErrorDetails.Message ?? $_.Exception.Message
            Write-Host "❌ FAILED" -ForegroundColor Red
            Write-Host "     $errMsg" -ForegroundColor DarkRed
            $failed++

            # Continue on non-fatal errors (e.g., "already exists")
            if ($errMsg -match "already exists|IF NOT EXISTS") {
                Write-Host "     (non-fatal, continuing...)" -ForegroundColor DarkYellow
                $failed--
                $success++
            }
        }
    }

    Write-Host "`n=== Results ===" -ForegroundColor Cyan
    Write-Host "  ✅ Succeeded: $success" -ForegroundColor Green
    Write-Host "  ❌ Failed:    $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

    if ($failed -gt 0) {
        Write-Host "`n⚠️  Some migrations failed. Check errors above." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "`n✅ All migrations applied successfully!" -ForegroundColor Green
    exit 0
}
