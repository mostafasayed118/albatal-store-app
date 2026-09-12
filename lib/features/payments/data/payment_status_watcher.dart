import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/entities/payment.dart';

/// Watches the `payments` row for an order via Supabase Realtime.
///
/// Extracted from [PaymobPaymentService] so the realtime + fallback-poll
/// machinery lives in one place. Same emissions, same timing, same
/// payloads — the service delegates to this watcher.
final class PaymentStatusWatcher {
  PaymentStatusWatcher({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Maps a `payments` row to its terminal [PaymentResult].
  ///
  /// Single shared mapping for BOTH the realtime callback and the 45s
  /// fallback poll in [watch] — identical rows always yield
  /// identical payloads. Returns null for non-terminal rows
  /// (`pending`/unknown/missing status) so both callers keep polling.
  /// Payloads are byte-identical to the pre-refactor inline branches
  /// (no `code` on the gateway-decline failure — codes unchanged).
  /// `cancelled`/`expired` (and `canceled`) map to [PaymentCancelled] so
  /// the cubit ends its wait instead of polling until the 15min timeout.
  static PaymentResult? terminalResultForRow(Map<String, dynamic> row) {
    final status = safeString(row, 'status').toLowerCase();
    if (status == 'success') {
      return PaymentSuccess(
        transactionId: safeString(row, 'transaction_id'),
        amount: Money.zero,
      );
    }
    if (status == 'failed') {
      return const PaymentFailed(
        message: 'Payment was declined by the gateway',
      );
    }
    if (status == 'cancelled' || status == 'canceled' || status == 'expired') {
      return const PaymentCancelled();
    }
    return null;
  }

  /// Subscribe to the `payments` row for [orderId] via Supabase Realtime.
  ///
  /// The `/paymob-callback` webhook updates the row server-side; this
  /// stream observes those updates and emits a terminal [PaymentResult]
  /// when `status` becomes `success` or `failed`. The returned stream
  /// is single-subscription — the cubit owns its subscription and
  /// cancels it on terminal status or [close]. Cancelling the
  /// subscription also unsubscribes the Realtime channel so we don't
  /// leak DB listeners.
  Stream<PaymentResult> watch(String orderId) {
    final controller = StreamController<PaymentResult>();
    RealtimeChannel? channel;
    Timer? fallbackTimer;
    final completer = Completer<void>();
    bool hasEmitted = false;

    // Single shared terminal-emission path for the realtime callback
    // and the fallback poll below: exactly-once add, cancels the
    // fallback timer, completes the `done` completer.
    void emitTerminal(PaymentResult result) {
      if (completer.isCompleted || controller.isClosed || hasEmitted) return;
      hasEmitted = true;
      if (!completer.isCompleted) completer.complete();
      fallbackTimer?.cancel();
      controller.add(result);
    }

    controller.onListen = () {
      channel = _client
          .channel('payment-$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              if (completer.isCompleted) return;
              final result =
                  PaymentStatusWatcher.terminalResultForRow(payload.newRecord);
              if (result != null) emitTerminal(result);
              // Other status values (e.g. 'pending') are ignored — the
              // webhook will update the row again when terminal.
            },
          )
          .subscribe();

      // Periodic fallback poll (was one-shot). Supabase Realtime
      // postgres_changes delivery was observed silently broken on
      // staging (subscriptions accepted, realtime.subscription never
      // populated, zero events — see
      // docs/evidence/ffaa420/STAGING_E2E_INSTAPAY.md). A single
      // 45s poll cannot cover InstaPay, where admin approval happens
      // at an arbitrary later time, so keep polling until a terminal
      // status is observed. The 15-minute watch timeout in
      // PaymentCubit still bounds the total wait; cancelling the
      // subscription (onListen/onCancel) cancels this timer. The
      // in-flight guard prevents overlapping polls if a poll is
      // slower than the interval.
      var pollInFlight = false;
      fallbackTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (pollInFlight ||
            completer.isCompleted ||
            controller.isClosed ||
            hasEmitted) {
          return;
        }
        pollInFlight = true;
        try {
          final row = await _client
              .from('payments')
              .select('status, transaction_id')
              .eq('order_id', orderId)
              .maybeSingle();
          if (completer.isCompleted || controller.isClosed || hasEmitted) {
            return;
          }
          if (row == null) return; // keep polling — nothing yet
          final result = PaymentStatusWatcher.terminalResultForRow(row);
          if (result != null) emitTerminal(result);
          // Other statuses (e.g. 'pending') keep the poll running.
        } catch (e) {
          Log.w('Payment status fallback poll failed: $e',
              category: LogCategory.payment);
        } finally {
          pollInFlight = false;
        }
      });
    };

    controller.onCancel = () {
      fallbackTimer?.cancel();
      channel?.unsubscribe();
    };

    return controller.stream;
  }
}
