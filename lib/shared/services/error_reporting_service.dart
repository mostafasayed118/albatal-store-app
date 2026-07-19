import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error reporting service.
///
/// In production, integrate with Sentry, Crashlytics, or similar.
/// For now, logs errors to Supabase for debugging.
class ErrorReportingService {
  ErrorReportingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Report a non-fatal error.
  Future<void> reportError(
    String message, {
    String? context,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    if (kDebugMode) {
      debugPrint('🔴 Error: $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   Stack: $stackTrace');
    }

    try {
      await _client.from('error_logs').insert({
        'message': message,
        'context': context,
        'error': error?.toString(),
        'stack_trace': stackTrace?.toString(),
        'user_id': _client.auth.currentUser?.id,
        'environment': kDebugMode ? 'development' : 'production',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Error reporting should never crash the app
      if (kDebugMode) debugPrint('Error reporting failed: $e');
    }
  }

  /// Report a payment failure.
  Future<void> reportPaymentFailure({
    required String orderId,
    required String method,
    required String reason,
  }) =>
      reportError(
        'Payment failed: $method',
        context: 'checkout',
        error: 'Order: $orderId, Reason: $reason',
      );

  /// Report an Edge Function error.
  Future<void> reportEdgeFunctionError({
    required String function,
    required String error,
  }) =>
      reportError(
        'Edge Function error: $function',
        context: 'edge-functions',
        error: error,
      );
}
