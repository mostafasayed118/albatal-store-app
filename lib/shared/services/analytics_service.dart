import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger.dart';

/// Analytics event sink — swappable so tests can capture events
/// without platform/Supabase access.
abstract interface class AnalyticsSink {
  Future<void> send(String name, Map<String, dynamic> props);

  /// Bulk send for flushed batches. Default fans out to [send] so
  /// existing fakes keep working; the Supabase sink overrides with a
  /// single bulk insert (audit 2026-09-14 P0-4).
  Future<void> sendBatch(
      List<({String name, Map<String, dynamic> props})> events) async {
    for (final event in events) {
      await send(event.name, event.props);
    }
  }
}

/// First-party analytics (feature-batch §11): funnel events into the
/// `analytics_events` table (proposal 052).
///
/// Batched (audit 2026-09-14 P0-4): `product_view` storms used to cost one
/// round-trip per event. Events now buffer and flush as a single bulk
/// insert on 20 events, every 10s, or [flush] (app pause). Failures are
/// swallowed — analytics must never break a user flow.
class AnalyticsService {
  /// Audit P1 (2026-09-19): [sink] is required — the composition root
  /// injects the [SupabaseAnalyticsSink]; a hidden default would have
  /// silently re-bound to the global Supabase client in tests.
  AnalyticsService({required AnalyticsSink sink, bool enabled = true})
      : _sink = sink,
        _enabled = enabled;

  final AnalyticsSink _sink;
  final bool _enabled;

  /// Logged funnel events: product_view, add_to_cart, checkout_start,
  /// purchase. Event names are stable snake_case constants.
  static const productView = 'product_view';
  static const addToCart = 'add_to_cart';
  static const checkoutStart = 'checkout_start';
  static const purchase = 'purchase';

  /// Flush thresholds: 20 buffered events or 10 seconds, whichever first.
  static const batchSize = 20;
  static const flushInterval = Duration(seconds: 10);

  final List<({String name, Map<String, dynamic> props})> _buffer = [];
  Timer? _flushTimer;
  bool _flushing = false;

  void log(String name, [Map<String, Object?> props = const {}]) {
    if (!_enabled) return;
    _buffer.add((name: name, props: Map<String, dynamic>.from(props)));
    if (_buffer.length >= batchSize) {
      unawaited(flush());
      return;
    }
    _flushTimer ??= Timer(flushInterval, () => unawaited(flush()));
  }

  /// Flushes the buffer as one bulk insert. Safe to call when empty.
  Future<void> flush() async {
    if (_buffer.isEmpty || _flushing) return;
    _flushing = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    final batch = List.of(_buffer);
    _buffer.clear();
    try {
      await _sink.sendBatch(batch);
    } catch (_) {
      // Swallow: analytics failures never reach the user or Sentry.
    } finally {
      _flushing = false;
    }
  }

  /// Cancels the pending flush timer. Call on dispose in long-lived owners.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}

/// Writes one row per event via direct insert. Column shape matches the
/// LIVE `analytics_events` table (id, user_id, event, properties,
/// created_at — verified via REST OpenAPI 2026-09-13): `event` +
/// `properties`, user_id left null-able per the insert-own RLS.
class SupabaseAnalyticsSink implements AnalyticsSink {
  /// Audit P1 (2026-09-19): the client is required — resolved at the
  /// composition root, never pulled from the global.
  SupabaseAnalyticsSink({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<void> send(String name, Map<String, dynamic> props) async {
    await sendBatch([(name: name, props: props)]);
  }

  @override
  Future<void> sendBatch(
    List<({String name, Map<String, dynamic> props})> events,
  ) async {
    if (events.isEmpty) return;
    await _client.from('analytics_events').insert(
          events.map((e) => {'event': e.name, 'properties': e.props}).toList(),
        );
    if (events.length == 1) {
      Log.d('analytics: ${events.first.name}', category: LogCategory.app);
    } else {
      Log.d('analytics: batch of ${events.length}', category: LogCategory.app);
    }
  }
}
