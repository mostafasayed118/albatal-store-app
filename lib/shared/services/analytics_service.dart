import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight analytics service for funnel tracking.
///
/// Tracks key events without external dependencies.
/// In production, integrate with Firebase Analytics or similar.
class AnalyticsService {
  AnalyticsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Track a funnel event.
  Future<void> trackEvent(String event, {Map<String, dynamic>? properties}) async {
    if (kDebugMode) {
      debugPrint('📊 Analytics: $event ${properties ?? ''}');
    }

    try {
      await _client.from('analytics_events').insert({
        'event': event,
        'properties': properties ?? {},
        'user_id': _client.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Analytics should never crash the app
      if (kDebugMode) debugPrint('Analytics error: $e');
    }
  }

  // ─── Funnel Events ──────────────────────────────────────

  void trackProductView(String productId, String productName) =>
      trackEvent('product_view', properties: {
        'product_id': productId,
        'product_name': productName,
      });

  void trackAddToCart(String productId, double price) =>
      trackEvent('add_to_cart', properties: {
        'product_id': productId,
        'price': price,
      });

  void trackBeginCheckout(double total) =>
      trackEvent('begin_checkout', properties: {'total': total});

  void trackPaymentMethod(String method) =>
      trackEvent('payment_method_selected', properties: {'method': method});

  void trackPaymentCompleted(String orderId, double amount, String method) =>
      trackEvent('payment_completed', properties: {
        'order_id': orderId,
        'amount': amount,
        'method': method,
      });

  void trackPaymentFailed(String orderId, String reason) =>
      trackEvent('payment_failed', properties: {
        'order_id': orderId,
        'reason': reason,
      });

  void trackOrderPlaced(String orderId, double total) =>
      trackEvent('order_placed', properties: {
        'order_id': orderId,
        'total': total,
      });

  void trackSearch(String query, int resultsCount) =>
      trackEvent('search', properties: {
        'query': query,
        'results_count': resultsCount,
      });

  void trackFilter(String filterType, String value) =>
      trackEvent('filter_applied', properties: {
        'filter_type': filterType,
        'value': value,
      });
}
