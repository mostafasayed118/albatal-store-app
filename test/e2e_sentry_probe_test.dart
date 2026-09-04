import 'package:al_batal_elite/shared/services/e2e_sentry_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldFireE2ESentryProbe', () {
    test('fires only when BOTH debug mode and probe flag are true', () {
      final result = shouldFireE2ESentryProbe(
        debugMode: true,
        probeFlag: true,
      );
      expect(result, isTrue);
    });

    test('does not fire when probe flag is false', () {
      final result = shouldFireE2ESentryProbe(
        debugMode: true,
        probeFlag: false,
      );
      expect(result, isFalse);
    });

    test('does not fire outside debug builds (release)', () {
      final result = shouldFireE2ESentryProbe(
        debugMode: false,
        probeFlag: true,
      );
      expect(result, isFalse);
    });

    test('does not fire when both are false', () {
      final result = shouldFireE2ESentryProbe(
        debugMode: false,
        probeFlag: false,
      );
      expect(result, isFalse);
    });
  });
}
