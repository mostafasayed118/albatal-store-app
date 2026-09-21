import '../../../../core/error/result.dart';

/// Narrow port for review moderation (ISP).
///
/// Split out of [AdminRepository] (audit). [AdminReviewsCubit] depends on
/// this instead of the ~20-method facade.
abstract interface class AdminReviewsPort {
  /// Pending review rows: (id, product, text, rating).
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews();

  /// Sets a review's moderation status (`approved` / `rejected`).
  Future<Result<void>> setReviewStatus(String id, String status);
}
