import 'idempotency_store.dart';

/// Non-persisted [IdempotencyStore] for tests and for cubits
/// constructed without a persistent store.
///
/// Keys live only for the instance lifetime, so crash-restart recovery
/// is unavailable — retries within the session still reuse the key.
final class MemoryIdempotencyStore implements IdempotencyStore {
  String? _key;
  int? _timestampMs;

  @override
  String? loadKey() => _key;

  @override
  int? loadTimestampMs() => _timestampMs;

  @override
  Future<void> saveKey(String key, int timestampMs) async {
    _key = key;
    _timestampMs = timestampMs;
  }

  @override
  Future<void> clear() async {
    _key = null;
    _timestampMs = null;
  }
}
