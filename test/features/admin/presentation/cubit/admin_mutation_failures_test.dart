import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_coupons_port.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_reviews_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_coupons_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_reviews_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _CouponsRepository extends Mock implements AdminCouponsPort {}

class _ReviewsRepository extends Mock implements AdminReviewsPort {}

class _AdminRepository extends Mock implements AdminRepository {}

void main() {
  test('coupon create failure keeps its message and machine code', () async {
    final repository = _CouponsRepository();
    when(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        )).thenAnswer((_) async => const Failure(AppError(
          'coupon rejected',
          code: kAdminCouponCreateFailed,
        )));
    final cubit = AdminCouponsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.createCoupon(code: 'SAVE', discountMinor: 500);

    expect(cubit.state.status, AdminCouponsStatus.error);
    expect(cubit.state.errorMessage, 'coupon rejected');
    expect(cubit.state.errorCode, kAdminCouponCreateFailed);
  });

  test('coupon toggle failure is no longer silently discarded', () async {
    final repository = _CouponsRepository();
    when(() => repository.setCouponActive('c1', false)).thenAnswer(
      (_) async => const Failure(AppError(
        'toggle rejected',
        code: kAdminCouponUpdateFailed,
      )),
    );
    final cubit = AdminCouponsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.setActive('c1', false);

    expect(cubit.state.status, AdminCouponsStatus.error);
    expect(cubit.state.errorMessage, 'toggle rejected');
    expect(cubit.state.errorCode, kAdminCouponUpdateFailed);
  });

  test('review moderation failure is no longer silently discarded', () async {
    final repository = _ReviewsRepository();
    when(() => repository.setReviewStatus('r1', 'approved')).thenAnswer(
      (_) async => const Failure(AppError(
        'review rejected',
        code: kAdminReviewUpdateFailed,
      )),
    );
    final cubit = AdminReviewsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.moderate('r1', approve: true);

    expect(cubit.state.status, AdminReviewsStatus.error);
    expect(cubit.state.errorMessage, 'review rejected');
    expect(cubit.state.errorCode, kAdminReviewUpdateFailed);
  });

  test('stock failure keeps its machine code for localized feedback', () async {
    final repository = _AdminRepository();
    when(() => repository.updateStock('v1', 7)).thenAnswer(
      (_) async => const Failure(AppError(
        'stock rejected',
        code: kAdminStockUpdateFailed,
      )),
    );
    final cubit = AdminCubit(repository);
    addTearDown(cubit.close);

    await cubit.updateStock('v1', 7);

    expect(cubit.state.status, AdminStatus.error);
    expect(cubit.state.errorMessage, 'stock rejected');
    expect(cubit.state.errorCode, kAdminStockUpdateFailed);
  });
}
