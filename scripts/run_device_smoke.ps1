#Requires -Version 5.1
<#
.SYNOPSIS
    Builds, installs and runs the debug smoke harness on an Android device,
    then raises or fails on the [SMOKE] logcat verdict.

.DESCRIPTION
    Uses lib/main_smoke.dart as the build target (that entry point is the
    harness gate) and --dart-define-from-file for real backend credentials.
    The harness is READ-ONLY: it exercises the admin dashboard data path and
    admin routes. It does not cover checkout, payment, or any write path.

    Exit codes: 0 = every scenario passed, 1 = failure / timeout / preflight.

.PARAMETER EnvFile
    Build-time env JSON, relative to the repo root by default.

.PARAMETER DeviceId
    adb serial (for example emulator-5554). Required when more than one
    Android device is attached.

.PARAMETER TimeoutSeconds
    How long to wait for the [SMOKE] SUMMARY line after launch.

.PARAMETER SkipBuild
    Reuse build\app\outputs\flutter-apk\app-debug.apk instead of rebuilding.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1 -DeviceId emulator-5554 -SkipBuild
#>
[CmdletBinding()]
param(
    [string]$EnvFile = 'config/env.staging.local.json',
    [string]$DeviceId = '',
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 180,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Continue'

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'pubspec.yaml'))) {
    Fail "Could not locate the repo root: expected pubspec.yaml in the parent directory of scripts."
}

if ([System.IO.Path]::IsPathRooted($EnvFile)) {
    $envPath = [System.IO.Path]::GetFullPath($EnvFile)
}
else {
    $envPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $EnvFile))
}

Write-Host ""
Write-Host "Al Batal Elite - device smoke runner" -ForegroundColor White
Write-Host "Repo:    $repoRoot"
Write-Host "Env:     $envPath"
Write-Host "Timeout: $TimeoutSeconds s"

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Step 'Preflight'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
    Fail "flutter is not on PATH. Install the Flutter SDK and reopen the terminal so PATH is refreshed."
}

$adbExe = $null
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCommand) {
    $adbExe = $adbCommand.Source
}
else {
    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($root in $sdkRoots) {
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate) {
            $adbExe = $candidate
            $env:Path = (Split-Path -Parent $candidate) + ';' + $env:Path
            break
        }
    }
}
if (-not $adbExe) {
    Fail "adb is not on PATH and was not found under ANDROID_SDK_ROOT or ANDROID_HOME. Install Android platform-tools (or add platform-tools to PATH), then re-run."
}

if (-not (Test-Path -LiteralPath $envPath)) {
    Fail @"
Env file not found: $envPath

Create it from the committed template and fill in the real staging values:
  Copy-Item config\env.staging.json config\env.staging.local.json
  notepad config\env.staging.local.json

Set SUPABASE_URL and SUPABASE_ANON_KEY. SENTRY_DSN and ONESIGNAL_APP_ID are optional.
Get the values from the owner-gated Supabase dashboard or the team secret store.
The .local.json file is gitignored: never commit it and never paste its values into a ticket.
"@
}

try {
    $envJson = Get-Content -LiteralPath $envPath -Raw -ErrorAction Stop | ConvertFrom-Json
}
catch {
    Fail "Env file is not valid JSON: $envPath. Recreate it from config\env.staging.json and re-enter the values."
}

$envKeys = @($envJson.PSObject.Properties.Name)
foreach ($requiredKey in @('SUPABASE_URL', 'SUPABASE_ANON_KEY')) {
    if ($envKeys -notcontains $requiredKey) {
        Fail "Env file is missing $requiredKey. Recreate it from config\env.staging.json and fill in the value (value intentionally not shown)."
    }
    $value = [string]$envJson.$requiredKey
    if ([string]::IsNullOrWhiteSpace($value) -or $value -like 'REPLACE_WITH*') {
        Fail "Env file still has a placeholder or empty $requiredKey. Edit $envPath and fill in the real value (value intentionally not shown)."
    }
}

$serial = ([string]$DeviceId).Trim()
$deviceName = ''

if ([string]::IsNullOrWhiteSpace($serial)) {
    $adbStates = @()
    try {
        $adbStates = @(& $adbExe devices 2>&1 | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' })
    }
    catch {
        $adbStates = @()
    }
    $unauthorized = @($adbStates | Where-Object { $_ -match '\bunauthorized\b' })
    if ($unauthorized.Count -gt 0) {
        Fail "An Android device is attached but not authorized. Unlock the phone and approve the 'Allow USB debugging' prompt, then re-run. (adb devices: $($unauthorized -join '; '))"
    }

    # adb is the source of truth for serials: on some Flutter versions
    # `flutter devices --machine` merges multiple devices into one object,
    # which produced a bogus concatenated serial.
    $adbDevices = @($adbStates | Where-Object { $_ -match '^\S+\s+device$' })
    if ($adbDevices.Count -eq 0) {
        Fail "No supported Android device found. Connect a phone with USB debugging enabled (unlocked and authorized) or start an emulator, then re-run. This runner is Android-only because it installs with adb."
    }
    if ($adbDevices.Count -gt 1) {
        $ids = @($adbDevices | ForEach-Object { ($_ -split '\s+')[0] })
        Fail "Multiple Android devices are attached: $($ids -join ', '). Re-run with -DeviceId <serial>."
    }

    $serial = ($adbDevices[0] -split '\s+')[0]
    $deviceName = (& $adbExe -s $serial shell getprop ro.product.model 2>$null | Out-String).Trim()
}

$adbDeviceLine = @(& $adbExe devices 2>&1 | Where-Object { $_ -match ('^' + [regex]::Escape($serial) + '\s+') }) | Select-Object -First 1
if (-not $adbDeviceLine) {
    Fail "Device '$serial' is not attached according to adb. Run 'adb devices'; reconnect the phone and authorize USB debugging, or pass the correct -DeviceId."
}
$deviceState = [regex]::Match($adbDeviceLine, '^\S+\s+(\S+)').Groups[1].Value
if ($deviceState -ne 'device') {
    Fail "Device '$serial' is in state '$deviceState'. Unlock the phone, approve USB debugging, or reconnect it, then re-run."
}

if ([string]::IsNullOrWhiteSpace($deviceName)) {
    Write-Host "Device:  $serial"
}
else {
    Write-Host "Device:  $deviceName ($serial)"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
$apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'

if ($SkipBuild) {
    Write-Step 'Build skipped (-SkipBuild)'
}
else {
    Write-Step 'Building debug APK with the smoke entry point'
    Push-Location -LiteralPath $repoRoot
    try {
        & flutter build apk --debug --target=lib/main_smoke.dart "--dart-define-from-file=$envPath"
        $buildExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($buildExit -ne 0) {
        Fail "flutter build failed (exit $buildExit). Fix the build first; the smoke target is lib/main_smoke.dart and must stay a debug build."
    }
}

if (-not (Test-Path -LiteralPath $apkPath)) {
    Fail "APK not found at $apkPath. Re-run without -SkipBuild to build it."
}

$apkMb = [math]::Round(((Get-Item -LiteralPath $apkPath).Length / 1MB), 1)
Write-Host "APK:     $apkPath ($apkMb MB)"

# ---------------------------------------------------------------------------
# Install and run
# ---------------------------------------------------------------------------
Write-Step "Installing on $serial"
$installOutput = (& $adbExe -s $serial install -r $apkPath 2>&1 | Out-String)
if (($LASTEXITCODE -ne 0) -or ($installOutput -match '\bFailure\b')) {
    Write-Host $installOutput.Trim()
    Fail "adb install failed. If the message says INSTALL_FAILED_UPDATE_INCOMPATIBLE, the installed app uses a different signing key: uninstall com.albatal.elite on the device, then re-run (this also removes the saved admin session)."
}

Write-Step "Launching com.albatal.elite/.MainActivity and capturing [SMOKE] logcat"
& $adbExe -s $serial shell am force-stop com.albatal.elite | Out-Null
& $adbExe -s $serial logcat -c | Out-Null

$logFile = Join-Path $env:TEMP ('albatal-smoke-' + [guid]::NewGuid().ToString('N') + '.log')
$errFile = $logFile + '.err'
$logcat = $null

try {
    # The Flutter tag carries every debugPrint line, including [SMOKE].
    try {
        $logcat = Start-Process -FilePath $adbExe `
            -ArgumentList @('-s', $serial, 'logcat', '-v', 'time', '-s', 'flutter') `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError $errFile `
            -PassThru -WindowStyle Hidden
    }
    catch {
        Fail "Could not start adb logcat: $($_.Exception.Message)"
    }

    # Give logcat a moment to attach before the app can log its first line.
    Start-Sleep -Milliseconds 750

    $launchOutput = (& $adbExe -s $serial shell am start -W -n com.albatal.elite/.MainActivity 2>&1 | Out-String)
    if (($LASTEXITCODE -ne 0) -or ($launchOutput -match 'Error:|Warning: Activity not started')) {
        Write-Host $launchOutput.Trim()
        Fail "Failed to launch com.albatal.elite/.MainActivity. Confirm the APK is installed and the launcher activity is still .MainActivity."
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $sawSummary = $false
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $logFile) {
            $tail = @()
            try {
                $tail = @(Get-Content -LiteralPath $logFile -Tail 200 -ErrorAction Stop)
            }
            catch {
                $tail = @()
            }
            if (@($tail | Where-Object { $_ -match '\[SMOKE\]\s+SUMMARY\s+\d+/\d+\s+scenarios passed' }).Count -gt 0) {
                $sawSummary = $true
                break
            }
        }
        if ($logcat.HasExited) {
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if ($sawSummary) {
        # Let the trailing per-scenario verdict lines flush before stopping.
        Start-Sleep -Milliseconds 1200
    }

    $exitedBeforeStop = $logcat.HasExited
    if (-not $logcat.HasExited) {
        Stop-Process -Id $logcat.Id -Force -ErrorAction SilentlyContinue
        $null = $logcat.WaitForExit(2000)
    }

    $smokeLines = @()
    if (Test-Path -LiteralPath $logFile) {
        try {
            $smokeLines = @(Get-Content -LiteralPath $logFile -ErrorAction Stop | Where-Object { $_ -match '\[SMOKE\]' })
        }
        catch {
            $smokeLines = @()
        }
    }

    $stderrText = ''
    if (Test-Path -LiteralPath $errFile) {
        try {
            $rawError = Get-Content -LiteralPath $errFile -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($rawError)) {
                $stderrText = $rawError.Trim()
            }
        }
        catch {
            $stderrText = ''
        }
    }

    $summaryLine = $smokeLines | Where-Object { $_ -match '\[SMOKE\]\s+SUMMARY\s+\d+/\d+\s+scenarios passed' } | Select-Object -Last 1

    if (-not $summaryLine) {
        Write-Host ""
        Write-Host "ERROR: No [SMOKE] SUMMARY within $TimeoutSeconds s." -ForegroundColor Red
        if ($exitedBeforeStop) {
            Write-Host "adb logcat exited before the run completed (device disconnected or logcat was killed)." -ForegroundColor Yellow
        }
        if ($smokeLines.Count -gt 0) {
            Write-Host "Last [SMOKE] lines:"
            foreach ($line in ($smokeLines | Select-Object -Last 30)) {
                $index = $line.IndexOf('[SMOKE]')
                if ($index -ge 0) {
                    Write-Host ("  " + $line.Substring($index))
                }
            }
        }
        else {
            Write-Host "No [SMOKE] lines were captured."
            Write-Host "Check that the screen stayed awake, the device is online, and the app was not frozen by OEM hibernation."
            Write-Host "Rebuild without -SkipBuild if the installed APK may predate lib/main_smoke.dart."
        }
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            Write-Host "adb logcat stderr:"
            Write-Host $stderrText
        }
        exit 1
    }

    $match = [regex]::Match($summaryLine, 'SUMMARY\s+(\d+)/(\d+)\s+scenarios passed')
    if (-not $match.Success) {
        Write-Host ""
        Write-Host "ERROR: Could not parse the SUMMARY line: $summaryLine" -ForegroundColor Red
        exit 1
    }
    $passed = [int]$match.Groups[1].Value
    $total = [int]$match.Groups[2].Value
    $failLines = @($smokeLines | Where-Object { $_ -match '\[SMOKE\]\s+FAIL\b' })

    Write-Host ""
    Write-Host "Smoke result:" -ForegroundColor Cyan
    foreach ($line in $smokeLines) {
        $index = $line.IndexOf('[SMOKE]')
        if ($index -ge 0) {
            Write-Host ("  " + $line.Substring($index))
        }
    }
    Write-Host ""

    if (($passed -eq $total) -and ($total -gt 0) -and ($failLines.Count -eq 0)) {
        Write-Host "PASS: $passed/$total scenarios passed." -ForegroundColor Green
        exit 0
    }

    Write-Host "FAIL: $passed/$total scenarios passed; $($failLines.Count) FAIL line(s)." -ForegroundColor Red
    exit 1
}
finally {
    try {
        if ($null -ne $logcat) {
            if (-not $logcat.HasExited) {
                Stop-Process -Id $logcat.Id -Force -ErrorAction SilentlyContinue
                $null = $logcat.WaitForExit(2000)
            }
            $logcat.Dispose()
        }
    }
    catch {
        # Cleanup must never mask the smoke verdict.
    }
    Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
}
