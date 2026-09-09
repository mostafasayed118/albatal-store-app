/// Device-local store for the checkout idempotency key.
///
/// Abstracts the persisted key (plus its write timestamp for TTL expiry)
/// so the checkout use-case never touches [SharedPreferences] directly.
/// Implementations live in the data layer; the in-memory fallback is for
/// tests and for cubits constructed without persistence.
abstract interface class IdempotencyStore {
  /// Returns the persisted key, or null when none was saved.
  String? loadKey();

  /// Returns the persisted write timestamp (milliseconds since epoch),
  /// or null when none was saved.
  int? loadTimestampMs();

  /// Persists [key] with its write [timestampMs].
  Future<void> saveKey(String key, int timestampMs);

  /// Discards any persisted key.
  Future<void> clear();
}
