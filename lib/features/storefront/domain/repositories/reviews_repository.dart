import '../../../../core/error/result.dart';
import '../entities/product_review.dart';

/// Reviews port (feature-batch §9). Reads are public (approved only);
/// submissions are gated server-side by RLS "buy-to-review" policies
/// (the user must have a delivered order containing the product).
abstract interface class ReviewsRepository {
  /// Approved reviews for [productId], newest first.
  Future<Result<List<ProductReview>>> fetchForProduct(String productId);

  /// Submits [rating]/[text] with an optional customer photo. Rows
  /// start in `pending` state.
  Future<Result<ProductReview>> submit({
    required String productId,
    required int rating,
    required String text,

    /// Already-compressed photo bytes (§4) — the submission sheet holds
    /// them in memory, so no second file read happens on the submit
    /// path (audit 2026-09-13).
    List<int>? photoBytes,
  });
}
