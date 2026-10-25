# Device Smoke Runbook

Reusable, debug-only on-device smoke harness. Replaces throwaway overlays
and manual adb tap scripts.

## Why

On some devices (observed on an Infinix X6882 / Android 14), OEM process
hibernation kills the Flutter semantics tree for the whole session:
every `uiautomator dump` returns a single empty node even while the app
renders fine. Screen-scraping is then impossible. The harness verifies
through **greppable logcat lines** instead, so it works with or without a
live accessibility tree.

## Safety model

- Armed by the **dedicated entry point** `lib/main_smoke.dart`: building
  with `--target=lib/main_smoke.dart` passes a process-exit hook into the
  app, and that hook is both the mount signal and the gate. No dart-define
  is involved, so a normal debug or release build cannot mount the harness.
  (A define-based gate was tried first and failed on-device —
  `bool.fromEnvironment` only bakes in const contexts — so the entry point
  itself is the gate now, and the harness also refuses `kReleaseMode`.)
- Scenarios are **read-only** by policy — they exercise real cubits,
  repositories, and routes, but never mutate data. Keep it that way.
- Each scenario is isolated: one throwing scenario cannot mask another.
- The run exits the process via the injected hook (exit code `0` pass,
  `1` fail) so CI-style invocations get a result without screen access.

## Prerequisites

- Flutter SDK on `PATH` and Android platform-tools (`adb`) on `PATH`. The
  runner also finds `adb` under `ANDROID_SDK_ROOT\platform-tools` or
  `ANDROID_HOME\platform-tools`.
- An **Android** device with USB debugging enabled, unlocked, and
  authorized (`adb devices` shows `device`). Emulators work too. iOS is
  not supported by the runner because it installs an APK with `adb`.
- `config/env.staging.local.json`, created from the committed template:

  ```powershell
  Copy-Item config\env.staging.json config\env.staging.local.json
  notepad config\env.staging.local.json
  ```

  It needs a real `SUPABASE_URL` and `SUPABASE_ANON_KEY`; `SENTRY_DSN` and
  `ONESIGNAL_APP_ID` are optional. The file is gitignored: get the values
  from the owner-gated Supabase dashboard or the team secret store, and
  never commit them or paste them into a ticket.
- The backend in that env file must be reachable from the device (Wi-Fi or
  mobile data).
- An **admin session already saved on the device**. Sign in to the app as an
  admin once before the smoke run; `adb install -r` keeps app data. A fresh
  install has no session and the admin scenarios will fail.
- Keep the screen awake while plugged in. OEM hibernation (XOS "Hiber")
  freezes the app process mid-run when the screen sleeps. Apply once with
  `adb shell svc power stayon true`; reset with
  `adb shell svc power stayon false`.

## Runner (recommended)

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1
```

Defaults: `config/env.staging.local.json`, 180 s timeout, and a fresh debug
build. Useful variations:

```powershell
# Several devices attached: use a serial from `adb devices`
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1 -DeviceId emulator-5554

# Reuse the existing app-debug.apk (no rebuild)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1 -SkipBuild

# Another env file or a longer timeout
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_device_smoke.ps1 -EnvFile config\env.production.local.json -TimeoutSeconds 300
```

The runner performs the preflight, builds `lib/main_smoke.dart` in debug,
installs with `adb install -r`, force-stops and relaunches
`com.albatal.elite/.MainActivity`, streams logcat filtered to `[SMOKE]`, and
exits `0` only when the summary is a full pass with no `FAIL` line. It never
prints env values.

### Reading the result

Exit code `0` plus `PASS: n/n scenarios passed` means every registered
scenario passed against the backend in the env file:

```
[SMOKE] PASS admin_dashboard_data
[SMOKE] PASS admin_routes_live
[SMOKE] SUMMARY 2/2 scenarios passed
```

A non-zero exit means preflight, build, install, launch, timeout, or a
scenario failure. The script prints the last `[SMOKE]` lines and any adb
stderr. `failed_checks=...` names the check that broke. `No [SMOKE] SUMMARY`
means the run never completed; see Troubleshooting.

## Coverage boundary

The harness is deliberately **read-only**. It covers:

- `admin_dashboard_data` - admin orders and low-stock products load through
  the real cubit/repository/RPC path.
- `admin_routes_live` - admin routes mount instead of redirecting to
  sign-in or a go_router error page.

It does **not** cover checkout, payment initiation or callbacks, order
creation, InstaPay proof submission, stock decrements, account mutations,
or any other write path. Automating those needs disposable test
accounts/orders plus cleanup and is out of scope for this harness by policy.
Do not bolt writes onto an existing scenario; add a separate, explicitly
cleaned-up suite instead.

## Manual fallback

The same steps by hand (use `-s <serial>` when more than one device is
attached):

```bash
# 0. Keep the device awake while plugged in.
adb shell svc power stayon true

# 1. Build with the smoke entry point (staging config shown; production
#    config works too). The --target IS the gate.
flutter build apk --debug \
  --target=lib/main_smoke.dart \
  --dart-define-from-file=config/env.staging.local.json

# 2. Install, force-stop any previous process, clear and watch logcat
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.albatal.elite
adb logcat -c
adb logcat -s flutter | grep SMOKE

# 3. In a second terminal, launch the smoke build
adb shell am start -n com.albatal.elite/.MainActivity
```

The process exits automatically when the run completes.

### Selecting scenarios

Build with `--dart-define=E2E_SCENARIOS=admin_routes_live` to run a
subset (comma-separated). Empty means all registered scenarios. The value
is read as a top-level const, so it bakes correctly at compile time.

## Adding a scenario

1. Open `lib/shared/smoke/admin_read_scenarios.dart` (or create a sibling
   registry and merge it in `smoke_harness.dart`).
2. Add a `(SmokeContext ctx) async => List<SmokeCheck>` entry. Rules:
   - Navigate with `ctx.router` (real routes — guards and dead ends are
     part of what's tested), settle with `ctx.pump()`.
   - Capture cubits/repositories before the first `await`.
   - Checks must hold on **any** environment: row counts, product names,
     and stock values belong in `detail`, never in `ok`.
   - Read-only. If a scenario must write, it must restore, and that
     needs a runbook note here explaining what and why.
3. Register an app-scope cubit by adding it to `SmokeContext` if needed.

## Troubleshooting

- **Nothing in logcat**: the app was frozen by OEM hibernation before the
  first frame. Wake the screen, launch again, and consider
  `adb shell dumpsys deviceidle whitelist +com.albatal.elite` (already
  applied once on the Infinix test device; survives reboots).
- **Semantics are empty but app renders**: expected on XOS after a
  hibernation cycle. The harness calls `ensureSemantics()` at start,
  which revives dumps on some devices; when it does not, the logcat
  channel is the source of truth.
- **Stale APK without the harness**: the binary must be rebuilt with
  `--target=lib/main_smoke.dart` — a leftover install from a normal build
  mounts no harness and exits never. Rebuild rather than debugging why
  "nothing happens". A successful run ends the process by itself; if
  logcat shows `SUMMARY` but the process lives, something replaced the
  exit hook (it is injected in `main_smoke.dart`, never inline).
- **Runner times out with no SUMMARY**: check the screen stayed awake, then
  re-run. `-TimeoutSeconds` only extends the wait; it does not fix a frozen
  app. If the device hibernates aggressively, whitelist the package with
  `adb shell dumpsys deviceidle whitelist +com.albatal.elite`.
- **Admin scenarios fail with a ready/error mismatch**: the device has no
  saved admin session. Sign in as an admin, force-stop, and re-run; do not
  relax the check.

## Related

- `scripts/run_device_smoke.ps1` — build, install, launch, capture, verdict
- `lib/shared/smoke/` — harness, runner, scenarios
- `test/shared/smoke/smoke_harness_test.dart` — gating, isolation,
  pass/fail and 043-contract regression tests
- `supabase/migrations/043_low_stock_returns_variant_id.sql` — the
  Inventory contract the default scenarios pin
