import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coupon = AdminCoupon(
    id: 'c1',
    code: 'EID25',
    discountMinor: 1000,
    active: true,
    description: 'Eid promo',
  );

  test('copyWith toggles active and preserves every other field', () {
    final disabled = coupon.copyWith(active: false);

    expect(disabled.active, isFalse);
    expect(disabled.id, coupon.id);
    expect(disabled.code, coupon.code);
    expect(disabled.discountMinor, coupon.discountMinor);
    expect(disabled.description, coupon.description);

    expect(coupon.copyWith().active, isTrue,
        reason: 'a null override keeps the current value');
  });

  test('equality and props cover all five fields', () {
    expect(
      coupon,
      const AdminCoupon(
        id: 'c1',
        code: 'EID25',
        discountMinor: 1000,
        active: true,
        description: 'Eid promo',
      ),
    );
    expect(coupon.props, ['c1', 'EID25', 1000, true, 'Eid promo']);
    expect(coupon.copyWith(active: false), isNot(coupon));
    expect(
      coupon.copyWith(active: false),
      isNot(const AdminCoupon(
        id: 'c1',
        code: 'EID25',
        discountMinor: 1000,
        active: true,
        description: 'Eid promo',
      )),
    );
  });
}
