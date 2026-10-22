import 'package:al_batal_elite/shared/components/app_lock_gate.dart';
import 'package:al_batal_elite/shared/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Prefs implements AppLockPrefsStore {
  _Prefs(this.enabled);

  @override
  bool enabled;

  @override
  void setEnabled(bool value) => enabled = value;
}

final class _Biometrics implements BiometricService {
  _Biometrics({
    this.throwOnProbe = false,
    this.throwOnAuth = false,
  });

  final bool supports = true;
  final bool throwOnProbe;
  final bool throwOnAuth;
  int authenticateCalls = 0;

  @override
  Future<bool> canAuthenticate() async {
    if (throwOnProbe) throw Exception('probe failed');
    return supports;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    if (throwOnAuth) throw Exception('prompt failed');
    return false;
  }
}

void main() {
  const childKey = Key('shell');

  Widget wrap(_Biometrics biometrics) => MaterialApp(
        home: AppLockGate(
          biometrics: biometrics,
          prefs: _Prefs(true),
          child: const Scaffold(key: childKey),
        ),
      );

  testWidgets('a throwing capability probe releases instead of trapping',
      (tester) async {
    final biometrics = _Biometrics(throwOnProbe: true);
    await tester.pumpWidget(wrap(biometrics));
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
    expect(biometrics.authenticateCalls, 0);
  });

  testWidgets('a throwing authentication prompt keeps the app locked',
      (tester) async {
    final biometrics = _Biometrics(throwOnAuth: true);
    await tester.pumpWidget(wrap(biometrics));
    await tester.pumpAndSettle();

    expect(biometrics.authenticateCalls, 1);
    expect(find.byKey(childKey), findsNothing);
    expect(find.text('App locked'), findsOneWidget);
  });
}
