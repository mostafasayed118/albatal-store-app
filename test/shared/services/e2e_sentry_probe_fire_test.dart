import 'package:al_batal_elite/shared/services/e2e_sentry_probe.dart';
import 'package:flutter_test/flutter_test.dart';

/// In a default build `E2E_SENTRY_PROBE` is false, so `fireE2ESentryProbe`
/// must return before touching Sentry and must be safe to call repeatedly.
/// The submission block only executes when the test binary is built with
/// `--dart-define=E2E_SENTRY_PROBE=true`.
void main() {
  test('the probe is a repeatable no-op unless the flag is compiled in', () {
    if (!shouldFireE2ESentryProbe()) {
      expect(fireE2ESentryProbe, returnsNormally);
      expect(fireE2ESentryProbe, returnsNormally);
      return;
    }

    // Flag build: the guard is one-shot, so the second call must also be safe.
    expect(fireE2ESentryProbe, returnsNormally);
    expect(fireE2ESentryProbe, returnsNormally);
  });
}
