import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// Biometric app-lock port (feature-batch §15).
abstract interface class BiometricService {
  /// Whether this device can authenticate the user at all — biometrics OR a
  /// device credential (PIN / pattern / passcode).
  ///
  /// Deliberately NOT `canCheckBiometrics` (biometrics only): gating on
  /// biometrics alone made the app lock unreachable on passcode-only
  /// devices, and made it release itself the moment a user removed their
  /// enrolled fingerprints. `isDeviceSupported()` covers both cases.
  Future<bool> canAuthenticate();

  /// Prompts the user; resolves true on success. Failures (cancel, lockout,
  /// unsupported) resolve false — the gate treats false as "stay locked".
  Future<bool> authenticate({required String reason});
}

/// `local_auth` implementation.
final class LocalBiometricService implements BiometricService {
  LocalBiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception catch (e) {
      Log.w('biometric capability probe failed: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Device-credential fallback is intentional: `biometricOnly: true`
        // silently made the app lock unusable whenever biometrics were
        // unavailable (and, combined with the old fail-open gate, let the
        // app through). The lock must be enforceable on passcode-only
        // devices too.
        biometricOnly: false,
      );
    } on Exception catch (e) {
      Log.w('biometric auth failed: $e');
      return false;
    }
  }
}

/// Opt-in persistence for the app lock.
abstract interface class AppLockPrefsStore {
  bool get enabled;
  void setEnabled(bool value);
}

const _kAppLockEnabled = 'app_lock_enabled_v1';

final class PrefsAppLockStore implements AppLockPrefsStore {
  PrefsAppLockStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool get enabled => _prefs.getBool(_kAppLockEnabled) ?? false;

  @override
  void setEnabled(bool value) => _prefs.setBool(_kAppLockEnabled, value);
}
