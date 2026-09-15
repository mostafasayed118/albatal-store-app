import 'package:al_batal_elite/shared/components/app_lock_gate.dart';
import 'package:al_batal_elite/shared/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Complements `platform_config_test.dart`: that file proves the platform can
/// authenticate; this one proves the Dart gate fails CLOSED — the previous
/// implementation cleared the lock flag on a failed/cancelled prompt, so an
/// enabled app lock protected nothing.
void main() {
  const childKey = Key('shell');
  const lockedTitle = 'App locked';

  Widget wrap({
    required bool prefEnabled,
    required _FakeBiometrics biometrics,
    Future<void> Function()? onSignOut,
  }) =>
      MaterialApp(
        home: AppLockGate(
          biometrics: biometrics,
          prefs: _FakeAppLockPrefs(prefEnabled),
          onSignOut: onSignOut,
          child: const Scaffold(key: childKey, body: Text('shell')),
        ),
      );

  testWidgets('opt-in off → renders the shell, never prompts', (tester) async {
    final biometrics = _FakeBiometrics();
    await tester.pumpWidget(
      wrap(prefEnabled: false, biometrics: biometrics),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
    expect(biometrics.authenticateCalls, 0);
  });

  testWidgets('no biometric service → pass-through (tests / unsupported)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppLockGate(
        prefs: _FakeAppLockPrefs(true),
        child: const Scaffold(key: childKey),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('device cannot authenticate → released, not trapped',
      (tester) async {
    final biometrics = _FakeBiometrics(supports: false);
    await tester.pumpWidget(wrap(prefEnabled: true, biometrics: biometrics));
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
    expect(biometrics.authenticateCalls, 0);
  });

  testWidgets('enabled + successful auth → unlocks', (tester) async {
    final biometrics = _FakeBiometrics(accept: true);
    await tester.pumpWidget(wrap(prefEnabled: true, biometrics: biometrics));
    await tester.pumpAndSettle();

    expect(biometrics.authenticateCalls, 1);
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('enabled + refused auth → STAYS LOCKED with a retry',
      (tester) async {
    final biometrics = _FakeBiometrics(accept: false);
    await tester.pumpWidget(wrap(prefEnabled: true, biometrics: biometrics));
    await tester.pumpAndSettle();

    // Fail-closed: the shell must not be reachable.
    expect(biometrics.authenticateCalls, 1);
    expect(find.byKey(childKey), findsNothing);
    expect(find.text(lockedTitle), findsOneWidget);

    // The retry re-prompts and unlocks once the user succeeds.
    biometrics.accept = true;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(biometrics.authenticateCalls, 2);
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('lock is applied on the FIRST frame, before any await',
      (tester) async {
    final biometrics = _FakeBiometrics(accept: true);
    await tester.pumpWidget(wrap(prefEnabled: true, biometrics: biometrics));
    // No pumpAndSettle: the first frame must already be locked even though
    // the capability probe / prompt are still pending.
    expect(find.byKey(childKey), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('sign-out escape clears the session before unlocking',
      (tester) async {
    var signedOut = false;
    final biometrics = _FakeBiometrics(accept: false);
    await tester.pumpWidget(wrap(
      prefEnabled: true,
      biometrics: biometrics,
      onSignOut: () async => signedOut = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sign out instead'), findsOneWidget);
    await tester.tap(find.text('Sign out instead'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('a failing sign-out keeps the app locked (no bypass)',
      (tester) async {
    final biometrics = _FakeBiometrics(accept: false);
    await tester.pumpWidget(wrap(
      prefEnabled: true,
      biometrics: biometrics,
      onSignOut: () async => throw StateError('offline'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out instead'));
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsNothing);
    expect(find.text(lockedTitle), findsOneWidget);
  });
}

class _FakeAppLockPrefs implements AppLockPrefsStore {
  _FakeAppLockPrefs(this.enabled);
  @override
  bool enabled;
  @override
  void setEnabled(bool value) => enabled = value;
}

class _FakeBiometrics implements BiometricService {
  _FakeBiometrics({this.supports = true, this.accept = true});

  /// Value returned by [canAuthenticate] (device can authenticate at all).
  bool supports;
  bool accept;
  int authenticateCalls = 0;

  @override
  Future<bool> canAuthenticate() async => supports;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    return accept;
  }
}
