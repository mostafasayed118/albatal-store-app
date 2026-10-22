import 'package:al_batal_elite/shared/services/biometric_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({
    this.authenticated = true,
    this.throwsOnProbe = false,
    this.throwsOnAuth = false,
  });

  final bool supported = true;
  bool authenticated;
  bool throwsOnProbe;
  bool throwsOnAuth;
  String? lastReason;
  bool? lastBiometricOnly;

  @override
  Future<bool> isDeviceSupported() async {
    if (throwsOnProbe) throw Exception('probe failed');
    return supported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Object? authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    lastReason = localizedReason;
    lastBiometricOnly = biometricOnly;
    if (throwsOnAuth) throw Exception('auth failed');
    return authenticated;
  }
}

void main() {
  group('LocalBiometricService', () {
    test('canAuthenticate forwards the device-support probe', () async {
      final service = LocalBiometricService(auth: _FakeLocalAuth());

      expect(await service.canAuthenticate(), isTrue);
    });

    test('canAuthenticate degrades to false on a platform error', () async {
      final service =
          LocalBiometricService(auth: _FakeLocalAuth(throwsOnProbe: true));

      expect(await service.canAuthenticate(), isFalse);
    });

    test('authenticate forwards the reason and allows device credentials',
        () async {
      final auth = _FakeLocalAuth();
      final service = LocalBiometricService(auth: auth);

      expect(
        await service.authenticate(reason: 'Unlock Al Batal'),
        isTrue,
      );
      expect(auth.lastReason, 'Unlock Al Batal');
      expect(auth.lastBiometricOnly, isFalse);
    });

    test('authenticate returns false when the user cancels', () async {
      final service =
          LocalBiometricService(auth: _FakeLocalAuth(authenticated: false));

      expect(await service.authenticate(reason: 'Unlock'), isFalse);
    });

    test('authenticate degrades to false on a platform error', () async {
      final service =
          LocalBiometricService(auth: _FakeLocalAuth(throwsOnAuth: true));

      expect(await service.authenticate(reason: 'Unlock'), isFalse);
    });
  });

  group('PrefsAppLockStore', () {
    test('defaults to disabled and persists toggles', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PrefsAppLockStore(prefs);

      expect(store.enabled, isFalse);

      store.setEnabled(true);
      expect(store.enabled, isTrue);

      store.setEnabled(false);
      expect(store.enabled, isFalse);
    });
  });
}
