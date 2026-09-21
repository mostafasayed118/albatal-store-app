import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger.dart';
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
    } catch (e) {
      // Fail-safe: a broken keystore or prefs only means the session
      // is not restored — auth proceeds as signed-out. The error travels
      // via `error:` so release breadcrumbs only carry the safe summary
      // (audit P5: never interpolate the raw exception at the call site).
      Log.w('Secure session migration failed; continuing signed-out.',
          error: e, category: LogCategory.auth);
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _store.read(persistSessionKey) != null;
    } catch (e) {
      Log.w('Secure session check failed; assuming signed-out.',
          error: e, category: LogCategory.auth);
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _store.read(persistSessionKey);
    } catch (e) {
      Log.w('Secure session read failed; treating as signed-out.',
          error: e, category: LogCategory.auth);
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _store.delete(persistSessionKey);
    } catch (e) {
      // Sign-out must never fail on a keystore error.
      Log.w('Secure session delete failed during sign-out.',
          error: e, category: LogCategory.auth);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _store.write(persistSessionKey, persistSessionString);
    } catch (e) {
      // Fail-safe like every other method here (audit P5 — this was the
      // only unwrapped write): a broken keystore at sign-in time surfaces
      // as signed-out on next launch instead of throwing into the
      // Supabase auth flow. The value is never logged (session material);
      // the error travels via `error:` for the release-safe summary.
      Log.w('Secure session persist failed; continuing unsigned.',
          error: e, category: LogCategory.auth);
    }
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
    } catch (e) {
      Log.w('PKCE verifier read failed.', error: e, category: LogCategory.auth);
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
    } catch (e) {
      // Removing a stale verifier must never throw into the auth flow.
      Log.w('PKCE verifier cleanup failed.',
          error: e, category: LogCategory.auth);
    }
  }
}
