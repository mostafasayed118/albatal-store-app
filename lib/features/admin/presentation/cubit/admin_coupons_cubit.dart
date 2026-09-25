import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_coupon.dart';
import '../../domain/repositories/admin_coupons_port.dart';

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

  /// App-authored failure code; drives localization at the render site.
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
  AdminCouponsCubit({required AdminCouponsPort repository})
      : _repository = repository,
        super(const AdminCouponsState());

  final AdminCouponsPort _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: AdminCouponsStatus.loading));
    final result = await _repository.fetchCoupons();
    if (isClosed) return;
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
    if (isClosed) return;
    switch (result) {
      case Success():
        await load();
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminCouponsStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  Future<void> setActive(String id, bool active) async {
    final result = await _repository.setCouponActive(id, active);
    if (isClosed) return;
    switch (result) {
      case Success():
        emit(state.copyWith(
            coupons: state.coupons
                .map((c) => c.id == id ? c.copyWith(active: active) : c)
                .toList()));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminCouponsStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }
}
