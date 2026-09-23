import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../domain/repositories/admin_reviews_port.dart';

/// Review moderation reads/writes for [SupabaseAdminRepository].
///
/// Implements [AdminReviewsPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminReviews implements AdminReviewsPort {
  SupabaseAdminReviews({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() => Result.guard(() async {
            final rows = await _client
                .from('product_reviews')
                .select('id, product_id, text, rating')
                .eq('status', 'pending')
                .order('created_at', ascending: false)
                .limit(100);
            // Total decode parity with the customers fetch: mistyped rows
            // degrade to skips instead of one malformed review failing the
            // whole pending queue. Rows without a usable id/product_id
            // cannot be moderated or navigated to, so they are skipped.
            final list = (rows as List)
                .whereType<Map<String, dynamic>>()
                .where(
                    (row) => row['id'] is String && row['product_id'] is String)
                .map((row) => (
                      id: row['id'] as String,
                      product: row['product_id'] as String,
                      text: safeString(row, 'text'),
                      rating: safeInt(row, 'rating'),
                    ))
                .toList();
            return list;
          }, 'Failed to fetch pending reviews', code: kAdminReviewsLoadFailed);

  @override
  Future<Result<void>> setReviewStatus(String id, String status) =>
      Result.guard<void>(() async {
        await _client
            .from('product_reviews')
            .update({'status': status}).eq('id', id);
      }, 'Failed to update review status', code: kAdminReviewUpdateFailed);
}
