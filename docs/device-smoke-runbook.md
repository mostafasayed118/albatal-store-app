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

## Run

```bash
# 0. Keep the device awake while plugged in — OEM hibernation (XOS "Hiber")
#    freezes the app process mid-run when the screen sleeps, and the run
#    silently stops after launch. Reset with `svc power stayon false`.
adb shell svc power stayon true

# 1. Build with the smoke entry point (staging config shown; production
#    config works too). The --target IS the gate.
flutter build apk --debug \
  --target=lib/main_smoke.dart \
  --dart-define-from-file=config/env.staging.local.json

# 2. Install & launch
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb shell am start -n com.albatal.elite/.MainActivity

# 3. Watch the verification channel
adb logcat -s flutter | grep SMOKE
```

Expected output:

```
[SMOKE] PASS admin_dashboard_data
[SMOKE] PASS admin_routes_live
[SMOKE] SUMMARY 2/2 scenarios passed
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
  channel is the source of truth.- **Stale APK without the harness**: the binary must be rebuilt with
  `--target=lib/main_smoke.dart` — a leftover install from a normal build
  mounts no harness and exits never. Rebuild rather than debugging why
  "nothing happens". A successful run ends the process by itself; if
  logcat shows `SUMMARY` but the process lives, something replaced the
  exit hook (it is injected in `main_smoke.dart`, never inline).

## Related

- `lib/shared/smoke/` — harness, runner, scenarios
- `test/shared/smoke/smoke_harness_test.dart` — gating, isolation,
  pass/fail and 043-contract regression tests
- `supabase/migrations/043_low_stock_returns_variant_id.sql` — the
  Inventory contract the default scenarios pin
