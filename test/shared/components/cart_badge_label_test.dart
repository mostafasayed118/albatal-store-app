import 'package:al_batal_elite/shared/components/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cartBadgeLabel (UX-046)', () {
    test('shows the exact count up to 99', () {
      expect(cartBadgeLabel(0), '0');
      expect(cartBadgeLabel(1), '1');
      expect(cartBadgeLabel(99), '99');
    });

    test('caps at 99+ so the badge never blows out', () {
      expect(cartBadgeLabel(100), '99+');
      expect(cartBadgeLabel(250), '99+');
      expect(cartBadgeLabel(9999), '99+');
    });
  });
}
