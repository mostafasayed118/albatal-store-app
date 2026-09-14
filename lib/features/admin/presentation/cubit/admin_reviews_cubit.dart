import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/repositories/admin_repository.dart';

enum AdminReviewsStatus { initial, loading, ready, error }

/// One pending-review row: (id, product name, review text, rating).
typedef PendingReview = ({String id, String product, String text, int rating});

final class AdminReviewsState extends Equatable {
  const AdminReviewsState({
    this.status = AdminReviewsStatus.initial,
    this.pending = const [],
    this.errorMessage,
    this.errorCode,
  });

  final AdminReviewsStatus status;
  final List<PendingReview> pending;
  final String? errorMessage;

  /// Machine-readable error classification from [AppError.code] for
  /// UI localization (audit 2026-09-14); null when the failure carried
  /// no code — pages fall back to [errorMessage] verbatim.
  final String? errorCode;

  AdminReviewsState copyWith({
    AdminReviewsStatus? status,
    List<PendingReview>? pending,
    String? errorMessage,
    String? errorCode,
  }) =>
      AdminReviewsState(
        status: status ?? this.status,
        pending: pending ?? this.pending,
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

  @override
  List<Object?> get props => [status, pending, errorMessage, errorCode];
}

/// Review moderation for the admin hub (feature-batch §9). The page no
/// longer drives the repository directly (audit 2026-09-13) — it
/// renders this cubit, exactly like the coupons surface.
class AdminReviewsCubit extends Cubit<AdminReviewsState> {
  AdminReviewsCubit({required AdminRepository repository})
      : _repository = repository,
        super(const AdminReviewsState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminReviewsStatus.loading));
    final result = await _repository.fetchPendingReviews();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: AdminReviewsStatus.ready, pending: value));
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminReviewsStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
    }
  }

  /// Approve/reject a row; on success it leaves the pending queue.
  Future<void> moderate(String id, {required bool approve}) async {
    final result = await _repository.setReviewStatus(
        id, approve ? 'approved' : 'rejected');
    if (isClosed) return;
    if (result is Success<void>) {
      emit(state.copyWith(
          pending: state.pending.where((r) => r.id != id).toList()));
    }
  }
}
