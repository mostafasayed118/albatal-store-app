import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_coupon.dart';
import '../../domain/repositories/admin_repository.dart';

enum AdminCouponsStatus { initial, loading, ready, error }

final class AdminCouponsState extends Equatable {
  const AdminCouponsState({
    this.status = AdminCouponsStatus.initial,
    this.coupons = const [],
    this.errorMessage,
    this.errorCode,
  });

  final AdminCouponsStatus status;
  final List<AdminCoupon> coupons;
  final String? errorMessage;

  /// Machine-readable error classification from [AppError.code] for
  /// UI localization (audit 2026-09-14); null when the failure carried
  /// no code — pages fall back to [errorMessage] verbatim.
  final String? errorCode;

  AdminCouponsState copyWith({
    AdminCouponsStatus? status,
    List<AdminCoupon>? coupons,
    String? errorMessage,
    String? errorCode,
  }) =>
      AdminCouponsState(
        status: status ?? this.status,
        coupons: coupons ?? this.coupons,
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

  @override
  List<Object?> get props => [status, coupons, errorMessage, errorCode];
}

/// Coupon management for the admin hub (feature-batch §8).
class AdminCouponsCubit extends Cubit<AdminCouponsState> {
  AdminCouponsCubit({required AdminRepository repository})
      : _repository = repository,
        super(const AdminCouponsState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCouponsStatus.loading));
    final result = await _repository.fetchCoupons();
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: AdminCouponsStatus.ready, coupons: value));
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminCouponsStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
    }
  }

  Future<void> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) async {
    final result = await _repository.createCoupon(
      code: code,
      discountMinor: discountMinor,
      description: description,
    );
    if (result is Success<AdminCoupon>) {
      await load();
    }
  }

  Future<void> setActive(String id, bool active) async {
    final result = await _repository.setCouponActive(id, active);
    switch (result) {
      case Success():
        emit(state.copyWith(
            coupons: state.coupons
                .map((c) => c.id == id ? c.copyWith(active: active) : c)
                .toList()));
      case Failure():
        break; // row keeps its previous toggle state in the UI
    }
  }
}
