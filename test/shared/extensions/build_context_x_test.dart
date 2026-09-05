import 'package:al_batal_elite/shared/extensions/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the icon a [pick] getter resolves to under a given text
/// direction, so tests can pin the LTR/RTL glyph contract.
Future<IconData> _iconUnder(
  WidgetTester tester,
  IconData Function(BuildContext) pick,
  TextDirection direction,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return pick(captured);
}

void main() {
  group('directional icons (UX-032)', () {
    testWidgets('forward arrow points right in LTR and left in RTL',
        (tester) async {
      final ltr = await _iconUnder(
          tester, (c) => c.directionalForwardIcon, TextDirection.ltr);
      final rtl = await _iconUnder(
          tester, (c) => c.directionalForwardIcon, TextDirection.rtl);

      expect(ltr.codePoint, Icons.arrow_forward.codePoint);
      // Icons.arrow_forward never mirrors on its own; under RTL the helper
      // swaps in the real left-pointing glyph so Arabic CTAs read forward.
      expect(rtl.codePoint, Icons.arrow_back.codePoint);
    });

    testWidgets('trailing chevron mirrors under RTL', (tester) async {
      final ltr = await _iconUnder(
          tester, (c) => c.directionalTrailingIcon, TextDirection.ltr);
      final rtl = await _iconUnder(
          tester, (c) => c.directionalTrailingIcon, TextDirection.rtl);

      expect(ltr.codePoint, Icons.chevron_right.codePoint);
      expect(rtl.codePoint, Icons.chevron_left.codePoint);
    });
  });
}
