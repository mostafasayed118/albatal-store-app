import 'package:flutter_test/flutter_test.dart';

import 'package:al_batal_elite/core/entities/money.dart';

void main() {
  test('subtractClamped floors at zero when discount exceeds total', () {
    expect(const Money(1000).subtractClamped(const Money(1500)), Money.zero);
    expect(
        const Money(1000).subtractClamped(const Money(400)), const Money(600));
    expect(const Money(1000) - const Money(400), const Money(600));
  });
}
