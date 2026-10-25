import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/instapay_proof.dart';
import '../../domain/repositories/admin_instapay_port.dart';

enum AdminInstapayStatus { initial, loading, ready, error }

/// One completed review attempt, consumed by the page's snackbar listener.
///
/// [seq] makes two identical outcomes distinct states: Bloc drops an emit
/// whose state equals the previous one, which would silently swallow the
/// second "approved" confirmation.
final class AdminInstapayAction extends Equatable {
  const AdminInstapayAction({
    required this.proofId,
    required this.approve,
    required this.seq,
    this.failed = false,
  });

  final String proofId;
  final bool approve;
  final int seq;
  final bool failed;

  @override
  List<Object?> get props => [proofId, approve, seq, failed];
}

final class AdminInstapayState extends Equatable {
  const AdminInstapayState({
    this.status = AdminInstapayStatus.initial,
    this.proofs = const [],
    this.reviewingIds = const {},
    this.errorCode,
    this.errorMessage,
    this.lastAction,
  });

  final AdminInstapayStatus status;
  final List<InstapayProof> proofs;

  /// Proofs with a review write in flight — drives the per-row spinner and
  /// disables the row's buttons.
  final Set<String> reviewingIds;

  final String? errorCode;
  final String? errorMessage;
  final AdminInstapayAction? lastAction;

  /// Whether a review for [proofId] is currently in flight.
  bool isReviewing(String proofId) => reviewingIds.contains(proofId);

  AdminInstapayState copyWith({
    AdminInstapayStatus? status,
    List<InstapayProof>? proofs,
    Set<String>? reviewingIds,
    String? errorCode,
    String? errorMessage,
    AdminInstapayAction? lastAction,
    bool clearError = false,
  }) =>
      AdminInstapayState(
        status: status ?? this.status,
        proofs: proofs ?? this.proofs,
        reviewingIds: reviewingIds ?? this.reviewingIds,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        lastAction: lastAction ?? this.lastAction,
      );

  @override
  List<Object?> get props =>
      [status, proofs, reviewingIds, errorCode, errorMessage, lastAction];
}

/// InstaPay proof moderation for the admin hub.
///
/// Loads the server-side pending queue and reviews one proof at a time per
/// row. Approval is decisive server-side (payment → success, order → paid in
/// one transaction), so on success the row leaves the queue; on failure it
/// stays — the stale row is retryable and the page shows the coded error.
class AdminInstapayCubit extends Cubit<AdminInstapayState> {
  AdminInstapayCubit({required AdminInstapayPort repository})
      : _repository = repository,
        super(const AdminInstapayState());

  final AdminInstapayPort _repository;

  /// Proof ids with a write in flight: re-entry for the same row is dropped,
  /// so a double tap cannot send two reviews (the second would hit the
  /// server's `proof_already_reviewed` and error a row already gone).
  final Set<String> _reviewing = {};

  /// Monotonic load token: a slow earlier read must not overwrite a newer
  /// queue (pull-to-refresh while the first load is still resolving).
  int _loadGeneration = 0;

  int _actionSeq = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    if (isClosed) return;
    emit(state.copyWith(status: AdminInstapayStatus.loading, clearError: true));
    final result = await _repository.listPendingProofs();
    if (isClosed || generation != _loadGeneration) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AdminInstapayStatus.ready,
          proofs: value,
          clearError: true,
        ));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminInstapayStatus.error,
          errorCode: error.code,
          errorMessage: error.message,
        ));
    }
  }

  Future<void> approve(String proofId) => _review(proofId, approve: true);

  Future<void> reject(String proofId, {String? note}) =>
      _review(proofId, approve: false, note: note);

  Future<void> _review(
    String proofId, {
    required bool approve,
    String? note,
  }) async {
    if (isClosed || !_reviewing.add(proofId)) return;
    emit(state.copyWith(reviewingIds: {..._reviewing}));
    final result =
        await _repository.reviewProof(proofId, approve: approve, note: note);
    _reviewing.remove(proofId);
    if (isClosed) return;
    switch (result) {
      case Success():
        emit(state.copyWith(
          status: AdminInstapayStatus.ready,
          proofs: state.proofs.where((p) => p.proofId != proofId).toList(),
          reviewingIds: {..._reviewing},
          clearError: true,
          lastAction: AdminInstapayAction(
            proofId: proofId,
            approve: approve,
            seq: ++_actionSeq,
          ),
        ));
      case Failure(:final error):
        emit(state.copyWith(
          // The row stays (and stays actionable): a failed write must be
          // retryable, and the queue itself is still loaded.
          reviewingIds: {..._reviewing},
          errorCode: error.code,
          errorMessage: error.message,
          lastAction: AdminInstapayAction(
            proofId: proofId,
            approve: approve,
            seq: ++_actionSeq,
            failed: true,
          ),
        ));
    }
  }
}
