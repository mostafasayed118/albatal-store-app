import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/onboarding/data/local_onboarding_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The legacy `SharedPreferences` store talks over this channel; failing
/// the write is the only way to reach the repository's failure branch.
const _prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_prefsChannel, (call) async {
      switch (call.method) {
        case 'getAll':
        case 'getAllWithParameters':
          return <String, Object>{};
        case 'setBool':
          throw PlatformException(code: 'write_failed');
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_prefsChannel, null);
    SharedPreferences.resetStatic();
  });

  test('a refused write is reported as a failure', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalOnboardingRepository(preferences);

    final result = await repository.complete();

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error.message,
        'Unable to save onboarding state.');
  });

  test('a readable store reports the onboarding state', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalOnboardingRepository(preferences);

    final completed = await repository.hasCompleted();

    expect(completed, isA<Success<bool>>());
    expect((completed as Success<bool>).value, isFalse);
  });
}
