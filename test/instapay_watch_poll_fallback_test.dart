import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages – transitive via supabase, needed for the invoke override signature
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';

// ─── Fakes ─────────────────────────────────────────────────────────
//
// Staging defect (docs/evidence/ffaa420/STAGING_E2E_INSTAPAY.md):
// Supabase Realtime accepted subscriptions but never delivered
// postgres_changes events. These fakes reproduce that world: the
// Realtime channel subscribes fine and NEVER fires its callback, so
// the only path to a terminal state is the REST fallback poll. The
// test drives the REAL PaymobPaymentService through the REAL cubit
// InstaPay flow (initiate → awaitingProof → poll → terminal).

/// Realtime channel that subscribes but never delivers any event —
/// the observed staging behavior (defect D-B).
class _SilentRealtimeChannel extends Fake implements RealtimeChannel {
  bool subscribed = false;
  bool unsubscribed = false;
  int registeredChanges = 0;

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
    registeredChanges++;
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
}

/// Edge Functions fake. Returns queued responses in order; the first
/// call is expected to be `instapay-initiate`.
class _FakeFunctionsClient extends Fake implements FunctionsClient {
  _FakeFunctionsClient(List<Map<String, Object?>> responses)
      : _responses = List.of(responses);

  final List<Map<String, Object?>> _responses;
  final List<String> calledFunctions = [];

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) async {
    calledFunctions.add(functionName);
    final response = _responses.removeAt(0);
    return FunctionResponse(
      data: response['data'],
      status: response['status'] as int,
    );
  }
}

/// Mutable stand-in for the `payments` row the fallback poll reads,
/// plus counters asserting the poll's query shape.
class _PollRow {
  Map<String, dynamic>? row;
  int queryCount = 0;
  String? lastSelect;
  String? lastEqColumn;
  Object? lastEqValue;
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({
    required this.silentChannel,
    required this.functions,
    required this.pollRow,
  });

  final _SilentRealtimeChannel silentChannel;

  @override
  final _FakeFunctionsClient functions;
  final _PollRow pollRow;

  @override
  RealtimeChannel channel(String name,
          {RealtimeChannelConfig opts = const RealtimeChannelConfig()}) =>
      silentChannel;

  @override
  SupabaseQueryBuilder from(String table) => _FakeQueryBuilder(pollRow);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.pollRow);

  final _PollRow pollRow;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    pollRow.lastSelect = columns;
    return _FakeFilterBuilder(pollRow);
  }
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder(this.pollRow);

  final _PollRow pollRow;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, dynamic value) {
    pollRow.lastEqColumn = column;
    pollRow.lastEqValue = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      _FakeMaybeSingle(pollRow);
}

class _FakeMaybeSingle extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  _FakeMaybeSingle(this.pollRow);

  final _PollRow pollRow;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    pollRow.queryCount++;
    return Future.value(pollRow.row).then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>?> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return Future.value(pollRow.row).catchError(onError, test: test);
  }

  @override
  Future<Map<String, dynamic>?> whenComplete(FutureOr<void> Function() action) {
    return Future.value(pollRow.row).whenComplete(action);
  }

  @override
  Stream<Map<String, dynamic>?> asStream() => Future.value(pollRow.row).asStream();

  @override
  Future<Map<String, dynamic>?> timeout(
    Duration timeLimit, {
    FutureOr<dynamic> Function()? onTimeout,
  }) =>
      Future.value(pollRow.row);
}

// ─── Tests ─────────────────────────────────────────────────────────

void main() {
  group('InstaPay approval detection while Realtime is silent', () {
    test(
      'cubit reaches success via the periodic REST poll with zero realtime events',
      () {
        fakeAsync((fake) {
          final pollRow = _PollRow();
          final functions = _FakeFunctionsClient([
            {
              'status': 200,
              'data': {
                'payment_id': 'pay-1',
                'instapay_address': 'instapay@merchant',
                'amount': 129000,
              },
            },
          ]);
          final channel = _SilentRealtimeChannel();
          final client = _FakeSupabaseClient(
            silentChannel: channel,
            functions: functions,
            pollRow: pollRow,
          );
          final service = PaymobPaymentService(client: client);
          final cubit = PaymentCubit(service);

          fake.run((_) {
            cubit.initPayment(amount: Money.egp(1290), orderId: 'ord-1');
            cubit.selectMethod(PaymentMethod.instapay);
            unawaited(cubit.processPayment(customerEmail: 'e2e@test.dev'));
          });
          fake.flushMicrotasks();

          // Flow reached awaitingProof; the watch is armed; exactly one
          // edge function (initiate) was called.
          expect(cubit.state.status, PaymentStatus.awaitingProof);
          expect(cubit.state.instructions!.instapayAddress, 'instapay@merchant');
          expect(cubit.state.instructions!.amount, Money(129000));
          expect(channel.subscribed, isTrue);
          expect(channel.registeredChanges, 1);
          expect(functions.calledFunctions, ['instapay-initiate']);

          // t=45s: first poll — admin has not reviewed yet (pending row).
          // No terminal state, no emission.
          pollRow.row = {'status': 'pending', 'transaction_id': null};
          fake.elapse(const Duration(seconds: 45));
          fake.flushMicrotasks();
          expect(pollRow.queryCount, 1);
          expect(pollRow.lastSelect, 'status, transaction_id');
          expect(pollRow.lastEqColumn, 'order_id');
          expect(pollRow.lastEqValue, 'ord-1');
          expect(cubit.state.status, PaymentStatus.awaitingProof);

          // t=90s: the admin approved meanwhile (server flips the row to
          // success with the instapay_<proofId> transaction id). The
          // Realtime channel stays SILENT — only the poll can observe it.
          pollRow.row = {
            'status': 'success',
            'transaction_id': 'instapay_proof_1',
          };
          fake.elapse(const Duration(seconds: 45));
          fake.flushMicrotasks();
          fake.flushMicrotasks();

          expect(cubit.state.status, PaymentStatus.success,
              reason: 'approval must be detected by the REST fallback poll');
          expect(cubit.state.transactionId, 'instapay_proof_1');

          // Terminal state stops the poll — no further queries.
          final pollsAtTerminal = pollRow.queryCount;
          fake.elapse(const Duration(minutes: 5));
          fake.flushMicrotasks();
          expect(pollRow.queryCount, pollsAtTerminal);

          fake.run((_) {
            unawaited(cubit.close());
          });
          fake.flushMicrotasks();
          expect(channel.unsubscribed, isTrue);
        });
      },
    );

    test('admin rejection observed via the poll fails the flow', () {
      fakeAsync((fake) {
        final pollRow = _PollRow();
        final functions = _FakeFunctionsClient([
          {
            'status': 200,
            'data': {
              'payment_id': 'pay-2',
              'instapay_address': 'instapay@merchant',
              'amount': 69000,
            },
          },
        ]);
        final channel = _SilentRealtimeChannel();
        final client = _FakeSupabaseClient(
          silentChannel: channel,
          functions: functions,
          pollRow: pollRow,
        );
        final service = PaymobPaymentService(client: client);
        final cubit = PaymentCubit(service);

        fake.run((_) {
          cubit.initPayment(amount: Money.egp(690), orderId: 'ord-2');
          cubit.selectMethod(PaymentMethod.instapay);
          unawaited(cubit.processPayment(customerEmail: 'e2e@test.dev'));
        });
        fake.flushMicrotasks();
        expect(cubit.state.status, PaymentStatus.awaitingProof);

        // Admin rejects the proof server-side; the silent channel never
        // tells us — the poll must surface the failure.
        pollRow.row = {'status': 'failed', 'transaction_id': null};
        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        fake.flushMicrotasks();

        expect(cubit.state.status, PaymentStatus.failed);
        expect(cubit.state.errorMessage, 'Payment was declined by the gateway');

        // Poll stopped after the terminal emission.
        final pollsAtTerminal = pollRow.queryCount;
        fake.elapse(const Duration(minutes: 3));
        fake.flushMicrotasks();
        expect(pollRow.queryCount, pollsAtTerminal);

        fake.run((_) {
          unawaited(cubit.close());
        });
        fake.flushMicrotasks();
      });
    });

    test('poll keeps running while the row is absent or pending (periodic, '
        'not one-shot) and stops on close', () {
      fakeAsync((fake) {
        final pollRow = _PollRow();
        final functions = _FakeFunctionsClient([
          {
            'status': 200,
            'data': {
              'payment_id': 'pay-3',
              'instapay_address': 'instapay@merchant',
              'amount': 129000,
            },
          },
        ]);
        final channel = _SilentRealtimeChannel();
        final client = _FakeSupabaseClient(
          silentChannel: channel,
          functions: functions,
          pollRow: pollRow,
        );
        final service = PaymobPaymentService(client: client);
        final cubit = PaymentCubit(service);

        fake.run((_) {
          cubit.initPayment(amount: Money.egp(1290), orderId: 'ord-3');
          cubit.selectMethod(PaymentMethod.instapay);
          unawaited(cubit.processPayment(customerEmail: 'e2e@test.dev'));
        });
        fake.flushMicrotasks();
        expect(cubit.state.status, PaymentStatus.awaitingProof);

        // Row absent (e.g. RLS hiccup / eventual consistency): no
        // emission, but the poll MUST keep ticking — a one-shot timer
        // would strand the user here forever (the pre-fix behavior).
        pollRow.row = null;
        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        expect(pollRow.queryCount, 1);
        expect(cubit.state.status, PaymentStatus.awaitingProof);

        // Still pending at the next tick: second poll, still no
        // terminal emission. This proves the poll is periodic.
        pollRow.row = {'status': 'pending', 'transaction_id': null};
        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        expect(pollRow.queryCount, 2);
        expect(cubit.state.status, PaymentStatus.awaitingProof);

        fake.elapse(const Duration(seconds: 45));
        fake.flushMicrotasks();
        expect(pollRow.queryCount, 3);

        // Closing the cubit cancels the poll — no more queries after.
        fake.run((_) {
          unawaited(cubit.close());
        });
        fake.flushMicrotasks();
        expect(channel.unsubscribed, isTrue);

        final pollsAtClose = pollRow.queryCount;
        fake.elapse(const Duration(minutes: 5));
        fake.flushMicrotasks();
        expect(pollRow.queryCount, pollsAtClose);
      });
    });
  });
}
