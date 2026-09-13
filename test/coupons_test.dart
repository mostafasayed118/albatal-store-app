import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/coupon_mapper.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/coupon_discount.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart'
    as checkout_repository;
import 'package:al_batal_elite/features/storefront/domain/repositories/coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCouponsRepo extends Mock implements CouponsRepository {}

/// The cubit only reaches the repository through the injected use-case;
/// coupon tests never trigger placeOrder so no stubs are needed.
class _MockCheckoutRepo extends Mock
    implements checkout_repository.CheckoutRepository {}

void main() {
  group('couponFromRow (§8)', () {
    test('maps a valid row', () {
      final coupon = couponFromRow({
        'code': 'silk10',
        'discount_minor': 10000,
        'description': '10 EGP off',
      });
      expect(coupon, isNotNull);
      expect(coupon!.code, 'SILK10');
      expect(coupon.discountMinor, 10000);
      expect(coupon.description, '10 EGP off');
    });

    test('fails closed on zero/negative discount', () {
      expect(
        couponFromRow({'code': 'X', 'discount_minor': 0}),
        isNull,
      );
      expect(
        couponFromRow({'code': 'X', 'discount_minor': -5}),
        isNull,
      );
    });

    test('fails closed on missing code', () {
      expect(couponFromRow({'discount_minor': 100}), isNull);
    });
  });

  group('CheckoutCubit.applyCoupon (§8)', () {
    test('attaches a validated coupon', () async {
      final repo = _MockCouponsRepo();
      final coupon = const CouponDiscount(code: 'SILK10', discountMinor: 10000);
      when(() => repo.validate('silk10'))
          .thenAnswer((_) async => Success(coupon));
      final cubit = CheckoutCubit(_MockCheckoutRepo(), coupons: repo);

      await cubit.applyCoupon('silk10');
      expect(cubit.state.appliedCoupon, coupon);
      expect(cubit.state.couponMessage, isNull);
      await cubit.close();
    });

    test('rejects an invalid coupon without throwing', () async {
      final repo = _MockCouponsRepo();
      when(() => repo.validate(any()))
          .thenAnswer((_) async => const Failure(AppError(kCouponInvalid)));
      final cubit = CheckoutCubit(_MockCheckoutRepo(), coupons: repo);

      await cubit.applyCoupon('nope');
      expect(cubit.state.appliedCoupon, isNull);
      expect(cubit.state.couponMessage, kCouponInvalid);
      await cubit.close();
    });

    test('unavailable backend degrades to a message', () async {
      final repo = _MockCouponsRepo();
      when(() => repo.validate(any()))
          .thenAnswer((_) async => const Failure(AppError(kCouponUnavailable)));
      final cubit = CheckoutCubit(_MockCheckoutRepo(), coupons: repo);

      await cubit.applyCoupon('silk10');
      expect(cubit.state.appliedCoupon, isNull);
      expect(cubit.state.couponMessage, kCouponUnavailable);
      await cubit.close();
    });

    test('clearCoupon detaches the coupon', () async {
      final repo = _MockCouponsRepo();
      const coupon = CouponDiscount(code: 'SILK10', discountMinor: 10000);
      when(() => repo.validate(any()))
          .thenAnswer((_) async => const Success(coupon));
      final cubit = CheckoutCubit(_MockCheckoutRepo(), coupons: repo);

      await cubit.applyCoupon('silk10');
      cubit.clearCoupon();
      expect(cubit.state.appliedCoupon, isNull);
      await cubit.close();
    });
  });
}
