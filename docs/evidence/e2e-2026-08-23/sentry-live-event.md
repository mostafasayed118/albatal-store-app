# E2E Evidence — Sentry Live Event Probe

**Date:** 2026-08-23
**Device:** `emulator-5556` (sdk gphone64 x86 64)
**Worktree:** `C:\flutter_projects\albatal-e2e` @ branch `fix/e2e-gates-evidence` (ac69c54 + working-tree changes)
**Supabase target:** isolated staging ref `zvpjngdgbpnkkqrorkul` (production ref never touched)
**Sentry DSN:** REDACTED — host only: `o4511583962333184.ingest.us.sentry.io`

## What shipped (working tree, uncommitted)

| File | Change |
| --- | --- |
| `lib/shared/services/e2e_sentry_probe.dart` | NEW — compile-time const `kE2ESentryProbe = bool.fromEnvironment('E2E_SENTRY_PROBE')`; pure gate `shouldFireE2ESentryProbe({debugMode = kDebugMode, probeFlag = kE2ESentryProbe})`; one-shot `fireE2ESentryProbe()` capturing `Exception('[E2E-PROBE] controlled sentry event')` tagged `{source: 'e2e-probe'}` |
| `lib/main.dart` | Import added; `fireE2ESentryProbe()` wired immediately after `crashReporter.init()` inside the bootstrap try-block |
| `test/e2e_sentry_probe_test.dart` | NEW — 4 gate tests: fires ONLY when BOTH true; no-fire for flag-false / release / both-false |

NoOpCrashReportingService untouched.

## Commands used (DSN redacted to host)

1. Build combined env JSON at `%TEMP%\ab-staging-combined.json` via a silent throwaway merge script:
   - base: worktree `config/env.staging.json`
   - override: main-tree `config/env.staging.local.json`
   - final override: `SENTRY_DSN` parsed from main-tree `.env.staging`
   - plus `"E2E_SENTRY_PROBE": "true"` (first run without this key produced no probe — defines are compile-time; relaunch required)
   - script printed only key names and the DSN host, never values; JSON deleted after the run.
2. Worktree dependency resolution:
   ```
   flutter pub get
   ```
3. Launch (via hub supervised process `sentry-probe`, cwd = worktree):
   ```
   cmd.exe /c C:\src\flutter\bin\flutter.bat run ^
     --dart-define-from-file=%TEMP%\ab-staging-combined.json ^
     -d emulator-5556
   ```
4. Log collection:
   ```
   adb -s emulator-5556 logcat -d --pid=<app-pid>
   ```

## Result — SDK initialised (logcat, pid 13905)

```
08-23 20:51:56.546 I nativeloader: Load .../com.albatal.elite-.../base.apk!/lib/x86_64/libsentry.so ... : ok
08-23 20:51:56.548 I nativeloader: Load .../base.apk!/lib/x86_64/libsentry-android.so ... : ok
08-23 20:51:56.704 I sentry-native: using database path "/data/data/com.albatal.elite/cache/sentry/af91dd95.../.sentry-native"
08-23 20:51:56.715 D sentry-native: starting backend
08-23 20:51:56.725 D sentry-native: Starting batching thread
```

Isolation check (staging ref confirmed, not production):

```
08-23 20:51:56.951 I flutter : ✅ Supabase initialized: https://zvpjngdgbpnkkqrorkul.supabase.co
```

## Result — probe event submitted successfully

```
08-23 20:51:57.014 I flutter : ℹ️ [APP] [E2E-PROBE] firing controlled sentry event
08-23 20:51:59.186 I flutter : ℹ️ [APP] [E2E-PROBE] event submitted id=1ef12b03f24d413ab3850bbd0ffb81d2
```

Event id: **`1ef12b03f24d413ab3850bbd0ffb81d2`**, tagged `source=e2e-probe`.

## Verification

- `flutter analyze lib/shared/services/e2e_sentry_probe.dart lib/main.dart test/e2e_sentry_probe_test.dart` → `No issues found!`
- `flutter test test/e2e_sentry_probe_test.dart` → `All tests passed!` (4/4)
- Gate proven dead by default: first launch WITHOUT `E2E_SENTRY_PROBE` in the define file produced zero `[E2E-PROBE]` markers while Sentry still initialised.

## Note

**Sentry dashboard confirmation is an owner-side visual check** — verify event `1ef12b03f24d413ab3850bbd0ffb81d2` appears on the dashboard with tag `source=e2e-probe`.
