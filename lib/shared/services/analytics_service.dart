import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger.dart';

/// Analytics event sink — swappable so tests can capture events
/// without platform/Supabase access.
abstract interface class AnalyticsSink {
  Future<void> send(String name, Map<String, dynamic> props);
}

/// First-party analytics (feature-batch §11): fire-and-forget funnel
/// events into the `analytics_events` table (proposal 052). Failures
/// are swallowed and throttled to one log line — analytics must never
/// break a user flow.
class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink, bool enabled = true})
      : _sink = sink ?? SupabaseAnalyticsSink(),
        _enabled = enabled;

  final AnalyticsSink _sink;
  final bool _enabled;

  /// Logged funnel events: product_view, add_to_cart, checkout_start,
  /// purchase. Event names are stable snake_case constants.
  static const productView = 'product_view';
  static const addToCart = 'add_to_cart';
  static const checkoutStart = 'checkout_start';
  static const purchase = 'purchase';

  void log(String name, [Map<String, Object?> props = const {}]) {
    if (!_enabled) return;
    _sink.send(name, props).then((_) {}, onError: (Object _) {
      // Swallow: analytics failures never reach the user or Sentry.
    });
  }
}

/// Writes one row per event via direct insert. Column shape matches the
/// LIVE `analytics_events` table (id, user_id, event, properties,
/// created_at — verified via REST OpenAPI 2026-09-13): `event` +
/// `properties`, user_id left null-able per the insert-own RLS.
class SupabaseAnalyticsSink implements AnalyticsSink {
  SupabaseAnalyticsSink({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> send(String name, Map<String, dynamic> props) async {
    await _client.from('analytics_events').insert({
      'event': name,
      'properties': props,
    });
    Log.d('analytics: $name', category: LogCategory.app);
  }
}
