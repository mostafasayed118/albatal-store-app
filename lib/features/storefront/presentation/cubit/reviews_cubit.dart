import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/repositories/reviews_repository.dart';

enum ReviewsStatus { initial, loading, ready, unavailable, error }

final class ReviewsState extends Equatable {
  const ReviewsState({
    this.status = ReviewsStatus.initial,
    this.reviews = const [],
    this.submitting = false,
    this.submitMessage,
  });

  final ReviewsStatus status;
  final List<ProductReview> reviews;

  /// True while a submit is in flight (photo upload can take a beat).
  final bool submitting;

  /// Machine code of the last submit outcome
  /// (`review_buy_required` / `review_invalid` / `review_unavailable`),
  /// null when the submit was accepted (it then awaits moderation).
  final String? submitMessage;

  ReviewsState copyWith({
    ReviewsStatus? status,
    List<ProductReview>? reviews,
    bool? submitting,
    String? submitMessage,
  }) =>
      ReviewsState(
        status: status ?? this.status,
        reviews: reviews ?? this.reviews,
        submitting: submitting ?? this.submitting,
        submitMessage: submitMessage,
      );

  @override
  List<Object?> get props => [status, reviews, submitting, submitMessage];
}

/// Product reviews for the details page (feature-batch §9).
///
/// When no repository is injected (pre-DI widget tests, or the 050
/// migration not yet registered) the cubit reports `unavailable` and
/// the details page hides the section.
class ReviewsCubit extends Cubit<ReviewsState> {
  ReviewsCubit({ReviewsRepository? repository})
      : _repository = repository,
        super(const ReviewsState());

  final ReviewsRepository? _repository;
  String _productId = '';

  Future<void> load(String productId) async {
    final repo = _repository;
    _productId = productId;
    if (repo == null || productId.isEmpty) {
      emit(state.copyWith(status: ReviewsStatus.unavailable));
      return;
    }
    emit(state.copyWith(status: ReviewsStatus.loading));
    final result = await repo.fetchForProduct(productId);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: ReviewsStatus.ready, reviews: value));
      case Failure(:final error):
        emit(state.copyWith(
          status: error.message == kReviewUnavailableCode
              ? ReviewsStatus.unavailable
              : ReviewsStatus.error,
        ));
    }
  }

  Future<void> submit({
    required int rating,
    required String text,
    String? photoPath,
  }) async {
    final repo = _repository;
    if (repo == null || _productId.isEmpty) {
      emit(state.copyWith(
          submitting: false, submitMessage: kReviewUnavailableCode));
      return;
    }
    emit(state.copyWith(submitting: true, submitMessage: null));
    final result = await repo.submit(
      productId: _productId,
      rating: rating,
      text: text,
      photoPath: photoPath,
    );
    if (isClosed) return;
    switch (result) {
      case Success():
        // Accepted → pending moderation. Reload the approved list; the
        // new row stays hidden by RLS until an admin approves it.
        emit(state.copyWith(submitting: false, submitMessage: null));
        await load(_productId);
      case Failure(:final error):
        emit(state.copyWith(submitting: false, submitMessage: error.message));
    }
  }
}

/// Copied machine code so the cubit can classify without importing the
/// data layer.
const kReviewUnavailableCode = 'review_unavailable';
const kReviewBuyRequiredCode = 'review_buy_required';
