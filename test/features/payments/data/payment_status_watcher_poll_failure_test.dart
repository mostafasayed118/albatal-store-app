import 'package:al_batal_elite/features/payments/data/payment_status_watcher.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime channel double: the watcher only needs a subscription.
class _StubChannel extends Fake implements RealtimeChannel {
  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload payload) callback,
  }) =>
      this;

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) =>
      this;

  @override
  Future<String> unsubscribe([Duration? timeout]) async => 'ok';
}

/// Query builder whose terminal call fails, so the fallback poll hits
/// its own error path.
class _FailingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FailingFilterBuilder();
}

class _FailingFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, dynamic value) =>
      this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      throw StateError('offline');
}

/// Supabase double whose payments query always fails.
class _FailingSupabaseClient extends Fake implements SupabaseClient {
  int fromCalls = 0;

  @override
  RealtimeChannel channel(String name,
          {RealtimeChannelConfig opts = const RealtimeChannelConfig()}) =>
      _StubChannel();

  @override
  SupabaseQueryBuilder from(String table) {
    fromCalls++;
    return _FailingQueryBuilder();
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
}

void main() {
  test('a failing fallback poll is swallowed and the watcher stays alive', () {
    fakeAsync((fake) {
      final client = _FailingSupabaseClient();
      final watcher = PaymentStatusWatcher(client: client);
      final results = <PaymentResult>[];

      final sub = watcher.watch('order-1').listen(results.add);
      fake.flushMicrotasks();

      fake.elapse(const Duration(seconds: 44));
      fake.flushMicrotasks();
      expect(client.fromCalls, 0, reason: 'the poll waits 45s');

      fake.elapse(const Duration(seconds: 1));
      fake.flushMicrotasks();
      fake.flushMicrotasks();

      expect(client.fromCalls, 1, reason: 'the fallback poll ran');
      expect(results, isEmpty, reason: 'a failed poll emits no result');

      // The watcher survives the failure and keeps polling.
      fake.elapse(const Duration(seconds: 45));
      fake.flushMicrotasks();
      fake.flushMicrotasks();
      expect(client.fromCalls, 2);

      sub.cancel();
      fake.flushMicrotasks();
    });
  });
}
