import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../../../../shared/services/service_locator.dart';
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
  SupabaseReviewsRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage;

  final SupabaseClient _client;

  /// Optional injected storage; resolved from [getIt] lazily at upload
  /// time so tests can construct the repo without configuring the DI
  /// container (the shared StorageService singleton registered in
  /// service_locator.dart).
  final StorageService? _storage;

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) =>
      Result.guard(() async {
        final rows = await _client
            .from('product_reviews')
            .select(
                'id, product_id, rating, text, created_at, author_name, photo_url')
            .eq('product_id', productId)
            .order('created_at', ascending: false)
            .limit(50);
        final list = rows as List<dynamic>;
        return list
            .map((row) => reviewFromRow(row as Map<String, dynamic>))
            .whereType<ProductReview>()
            .toList();
      }, kReviewUnavailable, onError: _fetchError);

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
    final row = await Result.guard(() async {
      String? photoUrl;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        // Review photos arrive already compressed from the submission
        // sheet (§4) and upload to the product-images bucket; the row
        // stores the storage path and moderation approval flips the row
        // to `approved`. No synchronous file re-read on submit
        // (audit 2026-09-13).
        final storage = _storage ?? getIt<StorageService>();
        final path = await storage.uploadProductImage(
          productId,
          photoBytes,
          'review_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'image/jpeg',
        );
        photoUrl = _client.storage.from('product-images').getPublicUrl(path);
      }
      return _client
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
    }, kReviewUnavailable, onError: _submitError);

    return row.when(
      success: (data) {
        final review = reviewFromRow(data);
        if (review == null) {
          return const Failure<ProductReview>(AppError(kReviewInvalid));
        }
        return Success<ProductReview>(review);
      },
      failure: (error) => Failure<ProductReview>(error),
    );
  }

  /// [Result.guard] error-mapper for review fetches: the Postgrest code
  /// is logged (network category) and every failure degrades to
  /// [kReviewUnavailable] so the details page hides the section.
  AppError _fetchError(Object e, StackTrace st) {
    if (e is PostgrestException) {
      Log.w('reviews fetch failed: ${e.code}', category: LogCategory.network);
    }
    return AppError(kReviewUnavailable, cause: e, stackTrace: st);
  }

  /// [Result.guard] error-mapper for review submits. RLS buy-to-review
  /// rejection lands here as a 42501/403.
  AppError _submitError(Object e, StackTrace st) {
    if (e is PostgrestException) {
      final buyRequired =
          e.code == '42501' || e.code == '403' || e.message.contains('policy');
      Log.w('review submit failed: ${e.code}', category: LogCategory.network);
      return AppError(
        buyRequired ? kReviewBuyRequired : kReviewUnavailable,
        cause: e,
        stackTrace: st,
      );
    }
    return AppError(kReviewUnavailable, cause: e, stackTrace: st);
  }
}
