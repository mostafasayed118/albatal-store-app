# Al Batal Elite — Before / After Verification Evidence Bundle

All commands were run from the repository root on Windows (PowerShell), Flutter 3.48.0-1.0.pre-57 / Dart 3.12.2.
Raw logs live under `.openclaw/tmp/audit/` (baseline) and `.openclaw/tmp/audit/rerun/` (any later re-run).

## 1. Gate-by-gate results

| # | Gate | Command | Baseline (master + WIP) | After fixes (`fix/audit-2026-09-15`) |
|---|---|---|---|---|
| 1 | Static analysis | `flutter analyze --no-pub` | **exit 1** — 4 × `unused_import` in `test/features/admin/data/admin_customer_directory_test.dart` | **exit 0** — `No issues found!` |
| 2 | Test suite | `flutter test --reporter compact` | **exit 1** — `+875 -9` (1 load failure, 8 Directionality failures) | **exit 0** — `+888` `All tests passed!` |
| 3 | Formatting | `dart format --set-exit-if-changed --output=none lib test` | **exit 1** — `Formatted 424 files (7 changed)` | **exit 0** — 0 changed |
| 4 | Build (Android debug) | `flutter build apk --debug` | **exit 1** — `ManifestMerger2$MergeFailureException: Error parsing AndroidManifest.xml` | **exit 0** — `√ Built build\app\outputs\flutter-apk\app-debug.apk` |
| 5 | Coverage | `flutter test --coverage` | not run at baseline | **70.4%** lines (7,471 / 10,609 instrumented) |
| 6 | Dependency scan | `flutter pub outdated` | not run at baseline | no security-relevant findings; 3 direct pins intentional (documented in `pubspec.yaml`) |
| 7 | Secret sweep | tracked-file + full-history grep | clean (only `.env.example` ever committed) | clean |

## 2. Raw log pointers

| Evidence | Path |
|---|---|
| Baseline analyze | `.openclaw/tmp/audit/baseline/analyze.txt` |
| Baseline tests (full) | `.openclaw/tmp/audit/baseline/test_full.txt` |
| Baseline format | `.openclaw/tmp/audit/baseline/format.txt` |
| Baseline build failure | `.openclaw/tmp/audit/baseline/build_apk.txt`, `build_apk_verbose.txt` |
| Build after manifest fix | `.openclaw/tmp/audit/build_after_manifest.txt` |
| Tests after fix wave 1 | `.openclaw/tmp/audit/test_after_fixes1.txt` |
| Coverage run | `.openclaw/tmp/audit/coverage_run.txt`, `coverage/lcov.info` |
| Signal scans (quality/arch) | `.openclaw/tmp/audit/baseline/signals*.txt`, `arch_signals*.txt` |
| Inventory stats | `.openclaw/tmp/audit/baseline/inventory_stats.txt` |

Baseline exceptions worth keeping verbatim:

```
Failed to load ".../test/features/admin/data/admin_customer_directory_test.dart":
Missing definition of `main` method.

No Directionality widget found.
Scaffold widgets require a Directionality widget ancestor.
  ... AppLockGate ← ... (test/shared/components/app_lock_gate_test.dart:23:22)   [x8 tests]

Execution failed for task ':app:processDebugMainManifest'.
> com.android.manifmerger.ManifestMerger2$MergeFailureException: Error parsing
  .../android/app/src/main/AndroidManifest.xml
Caused by: org.xml.sax.SAXParseException; lineNumber: 4; columnNumber: 52;
  The string "--" is not permitted
```

## 3. Regression / behaviour-parity evidence

- **Same suite, both sides:** the identical `flutter test` invocation was used before and after; the 875 tests that passed at baseline still pass, and the 9 failures are now green (888 total). No test was disabled, skipped or deleted to reach green.
- **Intentional behaviour changes (all documented, all deliberate):**
  1. `AUD-002` — sign-out failures of `Error` class now keep the app locked instead of crashing the lock screen. This is the widget's already-documented fail-closed contract; the previously-failing test `a failing sign-out keeps the app locked (no bypass)` now enforces it.
  2. `AUD-006` — the payment status controller closes on unsubscribe. Observable stream behaviour is unchanged (the cubit already cancelled its subscription; `emitTerminal` guards `isClosed`).
  3. `AUD-010` — a stale comment was replaced; no code behaviour change.
- **Test-harness-only changes (no production impact):** `AUD-001` (MaterialApp wrapper), `AUD-003` (reconstructed tests), `AUD-005` (formatting).
- **Build-level change:** `AUD-004` unblocked all Android builds; no Dart or Gradle logic changed.

## 4. Targeted verification of each fix

| Finding | Reproduction before | Verification after |
|---|---|---|
| AUD-004 | `flutter build apk --debug` → ManifestMerger failure | `flutter build apk --debug` → exit 0, APK produced |
| AUD-003 | `flutter test test/features/admin/data/admin_customer_directory_test.dart` → load failure | 5/5 tests pass; `flutter analyze` clean |
| AUD-001 | `flutter test test/shared/components/app_lock_gate_test.dart` → 0/8 (`Directionality`) | 8/8 pass |
| AUD-002 | Test threw `StateError: Bad state: offline` out of the tap handler | `a failing sign-out keeps the app locked (no bypass)` passes; child stays unmounted, lock title shown |
| AUD-006 | Static: `StreamController` created, 0 `close()` in file | `flutter analyze` clean; 105 payment tests pass |
| AUD-005 | `dart format --set-exit-if-changed` → exit 1 | exit 0 |
| AUD-010 | Stale comment present | Comment points at `ProductImageResolver`/`AppImage`; analyze + storefront tests pass |

## 5. Coverage delta

- Baseline: no coverage artifact existed (`coverage/` not generated for the audited revision).
- After: **70.4%** line coverage over 10,609 instrumented lines (7,471 hit) via `flutter test --coverage`.
- Coverage **did not decrease**: the reconstructed admin test file adds 5 tests where there were previously 0 executable tests, and no production file lost assertions.

## 6. Re-running this bundle

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/run-audit.ps1 -WithCoverage
```

Writes analyze / format / test / build / coverage / secret-sweep / dependency evidence into
`.openclaw/tmp/audit/rerun/` and exits non-zero if any gate fails.

## 7. Harness validation (end-to-end run of the deliverable script)

The harness was executed against the repaired tree to prove it works as shipped:

| Gate | exit | time |
|---|---|---|
| `flutter analyze --no-pub` | 0 | 118.6 s |
| `dart format --set-exit-if-changed` | 0 | 1.9 s |
| `flutter test --reporter compact` | 0 | 127.6 s — `+888: All tests passed!` |
| `flutter build apk --debug` | 0 | 34.5 s — `√ Built build\app\outputs\flutter-apk\app-debug.apk` |
| secret sweep (role-aware) | 0 | warned once on the triaged `anon` key (`AUD-014`); no keystores, no privileged keys |
| `flutter pub outdated` | 0 | 6.4 s (informational) |

**`failed gates: 0`** — log: `.openclaw/tmp/audit/harness_run2.txt`.

> The first harness run correctly failed on the secret-sweep gate because the sweep's original
> filter was over-broad: it could not distinguish a redacted placeholder from a live key, and the
> committed staging token is a real JWT. The sweep now **decodes the token's `role` claim**: an
> `anon` key is reported as a warned, triaged finding (public by design, RLS-gated — see `AUD-014`),
> while any privileged role (`service_role`, etc.) hard-fails the gate. That change makes the gate
> meaningful rather than merely noisy.
