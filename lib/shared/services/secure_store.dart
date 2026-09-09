import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted at-rest key-value store for PII and session material.
///
/// Backed by the platform hardware keystore (Android Keystore via
/// EncryptedSharedPreferences, iOS Keychain) — unlike
/// `SharedPreferences`, values never sit as cleartext on disk. Only
/// PII-bearing payloads live here (address book, local order snapshots,
/// Supabase session); cart, wishlist, and other non-sensitive caches
/// stay in plain `SharedPreferences`.
///
/// Depends on the [SecureStore] abstraction so tests inject an in-memory
/// fake and production code never touches the plugin directly.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production [SecureStore] on top of `flutter_secure_storage`.
///
/// iOS items use `accessibleAfterFirstUnlockThisDeviceOnly`
/// ([KeychainAccessibility.first_unlock_this_device]): readable after
/// the first unlock post-restart, never migrated to a new device via
/// backup. Android uses EncryptedSharedPreferences (AES-256-GCM,
/// hardware-backed master key where available).
final class FlutterSecureStore implements SecureStore {
  FlutterSecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: iosOptions,
              aOptions: androidOptions,
            );

  /// Android: EncryptedSharedPreferences (Keystore-backed master key).
  static const androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  /// iOS: accessible after first unlock, this device only (no backup
  /// migration, no pre-unlock access).
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(
        key: key,
        iOptions: iosOptions,
        aOptions: androidOptions,
      );

  @override
  Future<void> write(String key, String value) => _storage.write(
        key: key,
        value: value,
        iOptions: iosOptions,
        aOptions: androidOptions,
      );

  @override
  Future<void> delete(String key) => _storage.delete(
        key: key,
        iOptions: iosOptions,
        aOptions: androidOptions,
      );
}
