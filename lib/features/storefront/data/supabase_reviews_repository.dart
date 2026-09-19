import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../../../../shared/services/storage_service.dart';
import '../domain/entities/product_review.dart';
import '../domain/repositories/reviews_repository.dart';
import 'review_mapper.dart';

/// Supabase-backed reviews (feature-batch §9).
///
/// Reads the review-gated `product_reviews` table (proposal 050).
/// Before the migration is applied every call degrades to a
/// `review_unavailable` failure and the details page hides the section.
final class SupabaseReviewsRepository implements ReviewsRepository {
  SupabaseReviewsRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async {
    try {
      final rows = await _client
          .from('product_reviews')
          .select(
              'id, product_id, rating, text, created_at, author_name, photo_url')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(50);
      final list = rows as List<dynamic>;
      final reviews = list
          .map((row) => reviewFromRow(row as Map<String, dynamic>))
          .whereType<ProductReview>()
          .toList();
      return Success(reviews);
    } on PostgrestException catch (e, st) {
      Log.w('reviews fetch failed: ${e.code}', category: LogCategory.network);
      return Failure(AppError(kReviewUnavailable, cause: e, stackTrace: st));
    } on Exception catch (e, st) {
      return Failure(AppError(kReviewUnavailable, cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<ProductReview>> submit({
    required String productId,
    required int rating,
    required String text,
    List<int>? photoBytes,
  }) async {
    if (rating < 1 || rating > 5) {
      return const Failure(AppError(kReviewInvalid));
    }
    try {
      String? photoUrl;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        // Review photos arrive already compressed from the submission
        // sheet (§4) and upload to the product-images bucket; the row
        // stores the storage path and moderation approval flips the row
        // to `approved`. No synchronous file re-read on submit
        // (audit 2026-09-13).
        // Composition-root client (audit P1): reuse the injected client
        // rather than a hidden global fallback.
        final storage = StorageService(client: _client);
        final path = await storage.uploadProductImage(
          productId,
          photoBytes,
          'review_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'image/jpeg',
        );
        photoUrl = _client.storage.from('product-images').getPublicUrl(path);
      }
      final row = await _client
          .from('product_reviews')
          .insert({
            'product_id': productId,
            'rating': rating,
            'text': text.trim(),
            if (photoUrl != null) 'photo_url': photoUrl,
          })
          .select(
              'id, product_id, rating, text, created_at, author_name, photo_url')
          .single();
      final review = reviewFromRow(row);
      if (review == null) {
        return const Failure(AppError(kReviewInvalid));
      }
      return Success(review);
    } on PostgrestException catch (e, st) {
      // RLS buy-to-review rejection lands here as a 42501/403.
      final buyRequired =
          e.code == '42501' || e.code == '403' || e.message.contains('policy');
      Log.w('review submit failed: ${e.code}', category: LogCategory.network);
      return Failure(AppError(
        buyRequired ? kReviewBuyRequired : kReviewUnavailable,
        cause: e,
        stackTrace: st,
      ));
    } on Exception catch (e, st) {
      return Failure(AppError(kReviewUnavailable, cause: e, stackTrace: st));
    }
  }
}
