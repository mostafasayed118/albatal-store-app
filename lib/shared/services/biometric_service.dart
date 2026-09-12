import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// Biometric app-lock port (feature-batch §15).
abstract interface class BiometricService {
  /// Whether the device has enrolled biometrics (or the plugin can ask).
  Future<bool> canAuthenticate();

  /// Prompts the user; resolves true on success. Failures resolve
  /// false — the gate never crashes the shell.
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
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } on Exception catch (e) {
      Log.w('biometrics check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
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
