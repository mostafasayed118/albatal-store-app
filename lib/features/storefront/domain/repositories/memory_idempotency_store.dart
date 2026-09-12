import 'idempotency_store.dart';

/// Non-persisted [IdempotencyStore] for tests and for cubits
/// constructed without a persisted store.
///
/// Keys live only for the instance lifetime, so crash-restart recovery
/// is unavailable — retries within the session still reuse the key.
///
/// Domain-located (PR #53 + audit 2026-09-13): a pure-Dart in-memory
/// double of a domain port, so presentation cubits never need a
/// data-layer import to default-construct.
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
