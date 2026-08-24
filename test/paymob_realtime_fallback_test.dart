// ignore: depend_on_referenced_packages
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';

// ─── Fakes ─────────────────────────────────────────────────────────

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  void Function(PostgresChangePayload)? capturedCallback;
  PostgresChangeEvent? capturedEvent;
  String? capturedSchema;
  String? capturedTable;
  PostgresChangeFilter? capturedFilter;
  bool subscribed = false;
  bool unsubscribed = false;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    capturedEvent = event;
    capturedSchema = schema;
    capturedTable = table;
    capturedFilter = filter;
    capturedCallback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    subscribed = true;
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    unsubscribed = true;
    return 'ok';
  }

  void triggerPostgresChange(PostgresChangePayload payload) {
    capturedCallback?.call(payload);
  }

}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeRealtimeChannel fakeChannel;
  Map<String, dynamic>? fallbackRow;
  int fromCallCount = 0;
  String? lastFromTable;
  String? lastSelectColumns;
  String? lastEqColumn;
  dynamic lastEqValue;
  bool maybeSingleCalled = false;

  FakeSupabaseClient({required this.fakeChannel, this.fallbackRow});

  @override
  RealtimeChannel channel(String name,
          {RealtimeChannelConfig opts = const RealtimeChannelConfig()}) =>
      fakeChannel;

  @override
  SupabaseQueryBuilder from(String table) {
    fromCallCount++;
    lastFromTable = table;
    return _FakeQueryBuilder(this);
  }
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final FakeSupabaseClient _client;
  _FakeQueryBuilder(this._client);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    _client.lastSelectColumns = columns;
    return _FakeFilterBuilder(_client);
  }
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final FakeSupabaseClient _client;
  _FakeFilterBuilder(this._client);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, dynamic value) {
    _client.lastEqColumn = column;
    _client.lastEqValue = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    _client.maybeSingleCalled = true;
    return _FakeMaybeSingle(_client.fallbackRow);
  }
}

class _FakeMaybeSingle extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Map<String, dynamic>? _row;
  _FakeMaybeSingle(this._row);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    return Future.value(_row).then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>?> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return Future.value(_row).catchError(onError, test: test);
  }

  @override
  Future<Map<String, dynamic>?> whenComplete(
      FutureOr<void> Function() action) {
    return Future.value(_row).whenComplete(action);
  }

  @override
  Stream<Map<String, dynamic>?> asStream() =>
      Future.value(_row).asStream();

  @override
  Future<Map<String, dynamic>?> timeout(
    Duration timeLimit, {
    FutureOr<dynamic> Function()? onTimeout,
  }) =>
      Future.value(_row);
}

// ─── Tests ─────────────────────────────────────────────────────────

void main() {
  group('PaymobPaymentService.watchPaymentStatus fallback', () {
    test('falls back to poll after 45s without realtime — success', () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'success', 'transaction_id': 'txn-42'},
        );

        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-123').listen(results.add);

        fake.flushMicrotasks();
        expect(results, isEmpty, reason: 'no emission before timer');
        expect(channel.subscribed, isTrue);
        expect(channel.capturedEvent, PostgresChangeEvent.update);
        expect(channel.capturedSchema, 'public');
        expect(channel.capturedTable, 'payments');
        expect(channel.capturedFilter?.column, 'order_id');
        expect(channel.capturedFilter?.value, 'order-123');

        // 44s -> still no poll
        fake.elapse(const Duration(seconds: 44));
        fake.flushMicrotasks();
        expect(results, isEmpty);
        expect(client.maybeSingleCalled, isFalse);

        // 45s -> poll fires
        fake.elapse(const Duration(seconds: 1));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(client.fromCallCount, 1);
        expect(client.lastFromTable, 'payments');
        expect(client.lastSelectColumns, 'status, transaction_id');
        expect(client.lastEqColumn, 'order_id');
        expect(client.lastEqValue, 'order-123');
        expect(client.maybeSingleCalled, isTrue);

        expect(results, hasLength(1));
        expect(results.first, isA<PaymentSuccess>());
        expect((results.first as PaymentSuccess).transactionId, 'txn-42');

        fake.elapse(Duration.zero);
        sub.cancel();
        fake.flushMicrotasks();
      });
    });

    test('falls back to poll after 45s — failed status emits PaymentFailed',
        () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'failed', 'transaction_id': null},
        );

        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-999').listen(results.add);

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(results, hasLength(1));
        expect(results.first, isA<PaymentFailed>());

        sub.cancel();
      });
    });

    test('fallback does not emit when status is pending or row is null', () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'pending'},
        );

        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-pending').listen(results.add);

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(results, isEmpty, reason: 'pending should not emit terminal');

        sub.cancel();
        fake.flushMicrotasks();

        // now test null row
        final channel2 = FakeRealtimeChannel();
        final client2 = FakeSupabaseClient(
          fakeChannel: channel2,
          fallbackRow: null,
        );

        final service2 = PaymobPaymentService(client: client2);
        final results2 = <PaymentResult>[];
        final sub2 = service2.watchPaymentStatus('order-null').listen(results2.add);
        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();
        expect(results2, isEmpty);
        sub2.cancel();
      });
    });

    test('timer is cancelled on subscription cancel — no poll after cancel',
        () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'success', 'transaction_id': 'txn-should-not'},
        );

        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-cancel').listen(results.add);

        fake.flushMicrotasks();
        sub.cancel();
        fake.flushMicrotasks();
        expect(channel.unsubscribed, isTrue);

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(client.fromCallCount, 0);
        expect(client.maybeSingleCalled, isFalse);
        expect(results, isEmpty);
      });
    });

    test('realtime success before fallback prevents duplicate poll emission',
        () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'success', 'transaction_id': 'txn-fallback'},
        );

        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-realtime').listen(results.add);
        fake.flushMicrotasks();

        expect(channel.capturedCallback, isNotNull);
        channel.triggerPostgresChange(
          PostgresChangePayload(
            schema: 'public',
            table: 'payments',
            commitTimestamp: DateTime.now(),
            eventType: PostgresChangeEvent.update,
            newRecord: {'status': 'success', 'transaction_id': 'txn-realtime'},
            oldRecord: {},
            errors: null,
          ),
        );
        fake.flushMicrotasks();
        expect(results, hasLength(1));
        expect((results.first as PaymentSuccess).transactionId, 'txn-realtime');

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(results, hasLength(1));
        sub.cancel();
      });
    });

    test('realtime failed before fallback also cancels timer', () {
      fakeAsync((fake) {
        final channel = FakeRealtimeChannel();
        final client = FakeSupabaseClient(
          fakeChannel: channel,
          fallbackRow: {'status': 'success', 'transaction_id': 'txn-fallback2'},
        );
        final service = PaymobPaymentService(client: client);
        final results = <PaymentResult>[];
        final sub = service.watchPaymentStatus('order-realtime-fail').listen(results.add);
        fake.flushMicrotasks();

        channel.triggerPostgresChange(
          PostgresChangePayload(
            schema: 'public',
            table: 'payments',
            commitTimestamp: DateTime.now(),
            eventType: PostgresChangeEvent.update,
            newRecord: {'status': 'failed', 'transaction_id': null},
            oldRecord: {},
            errors: null,
          ),
        );
        fake.flushMicrotasks();
        expect(results, hasLength(1));
        expect(results.first, isA<PaymentFailed>());

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();
        // should not have polled after realtime failure; timer cancelled
        expect(client.fromCallCount, 0);
        expect(results, hasLength(1));
        sub.cancel();
      });
    });
  });
}
