import 'package:al_batal_elite/features/storefront/presentation/widgets/color_swatches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('swatchColorFor', () {
    test('maps a curated color name to its fabric hue', () {
      expect(swatchColorFor('Emerald'), const Color(0xFF0B7A4D));
      expect(swatchColorFor('Burgundy'), const Color(0xFF6E1423));
    });

    test('matching is case-insensitive and trims whitespace', () {
      expect(swatchColorFor('  emerald '), swatchColorFor('EMERALD'));
    });

    test('unknown names resolve deterministically', () {
      final a = swatchColorFor('Zanzibar Weave');
      final b = swatchColorFor('zanzibar weave');
      expect(a, b);
      expect(a, isNot(const Color(0x00000000))); // fully opaque
      expect(a.a, 1.0);
    });

    test('different unknown names do not silently share a hue', () {
      // Extremely unlikely for two distinct seeds to collide on 8 low bits.
      expect(
        deterministicTint('Zanzibar') != deterministicTint('Kashmir'),
        isTrue,
      );
    });
  });

  group('ColorSwatchDot', () {
    testWidgets('paints a circle in the resolved fabric color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorSwatchDot(name: 'Emerald'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ColorSwatchDot),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, const Color(0xFF0B7A4D));
      expect(decoration.border, isNotNull);
    });
  });
}
