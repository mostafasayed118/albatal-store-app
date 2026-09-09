import 'package:al_batal_elite/shared/services/secure_store.dart';

/// In-memory [SecureStore] fake for tests.
///
/// Records every key written so tests can assert PII lands in the
/// encrypted store (never in cleartext prefs) and that the auth wipe
/// actually deletes the keys, not just "calls clear".
///
/// Lives in `test/` so it never ships in the production binary.
final class MemorySecureStore implements SecureStore {
  MemorySecureStore([Map<String, String>? seed]) : _values = {...?seed};

  final Map<String, String> _values;

  /// Current snapshot of the encrypted store (for assertions).
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// [SecureStore] double that throws on every operation, simulating a
/// broken platform keystore. Session/PKCE adapters must degrade to
/// "no session" instead of crashing auth.
final class ThrowingSecureStore implements SecureStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore down');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('keystore down');

  @override
  Future<void> delete(String key) async => throw StateError('keystore down');
}
