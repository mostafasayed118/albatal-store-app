import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger.dart';

/// Compile-time flag enabling the controlled E2E Sentry probe.
///
/// Set via `--dart-define-from-file` (key `E2E_SENTRY_PROBE`) or
/// `--dart-define=E2E_SENTRY_PROBE=true`. Absent/false in every normal
/// build, so the probe is dead code in release and CI artifacts.
const bool kE2ESentryProbe = bool.fromEnvironment('E2E_SENTRY_PROBE');

/// Pure gate decision for the E2E Sentry probe.
///
/// The probe fires ONLY when BOTH conditions hold:
/// 1. the compile-time [probeFlag] (`E2E_SENTRY_PROBE`) is true, AND
/// 2. we are running a debug build ([debugMode] mirrors `kDebugMode`).
///
/// Defaults are wired to the real build-time constants so callers need
/// no arguments; tests inject both to exercise every combination.
bool shouldFireE2ESentryProbe({
  bool debugMode = kDebugMode,
  bool probeFlag = kE2ESentryProbe,
}) {
  return debugMode && probeFlag;
}

/// One-shot guard — the probe fires at most once per process.
bool _probeFired = false;

/// Fires exactly ONE tagged exception into Sentry when
/// [shouldFireE2ESentryProbe] passes.
///
/// The event is `Exception('[E2E-PROBE] controlled sentry event')`
/// tagged `{source: e2e-probe}` so it is trivially identifiable on the
/// dashboard. Never call this outside an E2E evidence run.
void fireE2ESentryProbe() {
  if (!shouldFireE2ESentryProbe()) return;
  if (_probeFired) return;
  _probeFired = true;

  Log.i('[E2E-PROBE] firing controlled sentry event',
      category: LogCategory.app);
  // ignore: discarded_futures
  Sentry.captureException(
    Exception('[E2E-PROBE] controlled sentry event'),
    stackTrace: StackTrace.current,
    withScope: (scope) {
      scope.setTag('source', 'e2e-probe');
    },
  ).then((id) {
    Log.i('[E2E-PROBE] event submitted id=$id', category: LogCategory.app);
  }).catchError((Object error) {
    Log.e('[E2E-PROBE] submission failed', error: error);
  });
}
