import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
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
      : _client = client,
        _storage = StorageService(client: client);

  final SupabaseClient _client;
  final StorageService _storage;

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async {
    try {
      final rows = await _client
          .from('product_reviews_public')
          .select(
              'id, product_id, rating, text, created_at, author_name, photo_url')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(50);
      final reviews = <ProductReview>[];
      for (final raw in rows as List<dynamic>) {
        if (raw is! Map) continue;
        final review = reviewFromRow(safeMap(raw));
        if (review == null) continue;
        reviews.add(await _withSignedPhoto(review));
      }
      return Success(reviews);
    } on PostgrestException catch (e, st) {
      Log.w('reviews fetch failed: ${e.code}', category: LogCategory.network);
      return Failure(AppError(kReviewUnavailable,
          cause: e, stackTrace: st, code: kReviewUnavailable));
    } on Exception catch (e, st) {
      return Failure(AppError(kReviewUnavailable,
          cause: e, stackTrace: st, code: kReviewUnavailable));
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
      return const Failure(AppError(kReviewInvalid, code: kReviewInvalid));
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxReviewTextLength) {
      return const Failure(AppError(kReviewInvalid, code: kReviewInvalid));
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const Failure(
          AppError(kReviewUnavailable, code: kReviewUnavailable));
    }

    String? photoPath;
    try {
      if (photoBytes != null && photoBytes.isNotEmpty) {
        photoPath = await _storage.uploadReviewImage(
          userId: userId,
          productId: productId,
          bytes: photoBytes,
          fileName: 'review_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
      }
      final response = await _client.rpc('submit_product_review', params: {
        'p_product_id': productId,
        'p_rating': rating,
        'p_text': trimmed,
        'p_photo_path': photoPath,
      });
      final row = safeMap(response);
      final review = reviewFromRow(row);
      if (review == null) {
        if (photoPath != null) await _storage.deleteReviewImage(photoPath);
        return const Failure(AppError(kReviewInvalid, code: kReviewInvalid));
      }
      return Success(await _withSignedPhoto(review));
    } on PostgrestException catch (e, st) {
      if (photoPath != null) {
        try {
          await _storage.deleteReviewImage(photoPath);
        } on Exception catch (cleanupError, cleanupStack) {
          Log.e('review photo cleanup failed',
              error: cleanupError, stackTrace: cleanupStack);
        }
      }
      final message = e.message.toLowerCase();
      final buyRequired = e.code == '42501' ||
          e.code == '403' ||
          message.contains('purchase') ||
          message.contains('buy');
      Log.w('review submit failed: ${e.code}', category: LogCategory.network);
      final outcome = buyRequired ? kReviewBuyRequired : kReviewUnavailable;
      return Failure(AppError(
        outcome,
        cause: e,
        stackTrace: st,
        code: outcome,
      ));
    } on Exception catch (e, st) {
      if (photoPath != null) {
        try {
          await _storage.deleteReviewImage(photoPath);
        } on Exception catch (cleanupError, cleanupStack) {
          Log.e('review photo cleanup failed',
              error: cleanupError, stackTrace: cleanupStack);
        }
      }
      return Failure(AppError(kReviewUnavailable,
          cause: e, stackTrace: st, code: kReviewUnavailable));
    }
  }

  Future<ProductReview> _withSignedPhoto(ProductReview review) async {
    final path = review.photoUrl;
    if (path == null || path.isEmpty || path.startsWith('http')) return review;
    try {
      final signed = await _storage.createReviewImageUrl(path);
      if (signed == null || signed.isEmpty) return _withoutPhoto(review);
      return ProductReview(
        id: review.id,
        productId: review.productId,
        authorName: review.authorName,
        rating: review.rating,
        text: review.text,
        createdAt: review.createdAt,
        photoUrl: signed,
      );
    } on Exception catch (e, st) {
      Log.e('review photo URL signing failed', error: e, stackTrace: st);
      return _withoutPhoto(review);
    }
  }

  ProductReview _withoutPhoto(ProductReview review) => ProductReview(
        id: review.id,
        productId: review.productId,
        authorName: review.authorName,
        rating: review.rating,
        text: review.text,
        createdAt: review.createdAt,
      );
}

/// Client-side upper bound for review text (see [submit]): the server text
/// column is unbounded, so one submission could otherwise stage megabytes
/// for the insert. Generous on purpose — confirm the server contract
/// before lowering it.
const maxReviewTextLength = 2000;
