import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_store.dart';

/// Supabase session persistence on top of the encrypted [SecureStore].
///
/// Replaces the default `SharedPreferencesLocalStorage` (cleartext
/// session JSON on disk) with hardware-backed storage, using the same
/// persist-session key format Supabase generates so upgrades keep the
/// existing key namespace. A one-time migration in [initialize] lifts a
/// cleartext session left by older builds into the secure store and
/// removes the prefs copy — existing users stay signed in, and no
/// session material remains in cleartext afterwards.
///
/// All I/O is fail-safe: a keystore failure surfaces as "no session"
/// (the user signs in again) and must never crash startup or auth.
final class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this.persistSessionKey,
    SecureStore? secureStore,
  }) : _store = secureStore ?? FlutterSecureStore();

  final String persistSessionKey;
  final SecureStore _store;

  @override
  Future<void> initialize() async {
    try {
      if (await _store.read(persistSessionKey) != null) return;
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null) return;
      await _store.write(persistSessionKey, legacy);
      await prefs.remove(persistSessionKey);
    } catch (_) {
      // Fail-safe: a broken keystore or prefs only means the session
      // is not restored — auth proceeds as signed-out.
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _store.read(persistSessionKey) != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _store.read(persistSessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _store.delete(persistSessionKey);
    } catch (_) {
      // Sign-out must never fail on a keystore error.
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _store.write(persistSessionKey, persistSessionString);
  }
}

/// PKCE code-verifier storage on top of the encrypted [SecureStore].
///
/// Replaces the default `SharedPreferencesGotrueAsyncStorage` so the
/// OAuth/PKCE verifier never sits in cleartext prefs either. Fail-safe
/// on reads/removes (a missing verifier just aborts the auth callback);
/// writes propagate so a broken store surfaces loudly instead of
/// silently dropping the login flow.
final class SecureGotrueStorage extends GotrueAsyncStorage {
  SecureGotrueStorage({SecureStore? secureStore})
      : _store = secureStore ?? FlutterSecureStore();

  final SecureStore _store;

  @override
  Future<String?> getItem({required String key}) async {
    try {
      return await _store.read(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write(key, value);

  @override
  Future<void> removeItem({required String key}) async {
    try {
      await _store.delete(key);
    } catch (_) {
      // Removing a stale verifier must never throw into the auth flow.
    }
  }
}
