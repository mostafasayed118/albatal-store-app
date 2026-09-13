import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/product_review.dart';

/// Maps a `product_reviews` row (joined with the author display name)
/// to [ProductReview]. Fail-soft: invalid rows become null.
ProductReview? reviewFromRow(Map<String, dynamic> row) {
  final id = safeString(row, 'id');
  final productId = safeString(row, 'product_id');
  final rating = safeInt(row, 'rating');
  if (id.isEmpty || productId.isEmpty || rating < 1 || rating > 5) {
    return null;
  }
  final createdAtMs = safeInt(row, 'created_at_ms');
  return ProductReview(
    id: id,
    productId: productId,
    authorName: safeString(row, 'author_name', fallback: 'Al Batal'),
    rating: rating,
    text: safeString(row, 'text'),
    createdAt: createdAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0),
    photoUrl: safeString(row, 'photo_url').isEmpty
        ? null
        : safeString(row, 'photo_url'),
  );
}

/// Maps an admin moderation row (pending queue).
ProductReview? adminReviewToReview(Map<String, dynamic> row) =>
    reviewFromRow(row);

/// Stable machine codes for submit outcomes.
const kReviewBuyRequired = 'review_buy_required';
const kReviewInvalid = 'review_invalid';
const kReviewUnavailable = 'review_unavailable';
