import 'package:al_batal_elite/shared/components/app_card.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The app theme carries the Stitch tokens (surface, outlineVariant), so these
  // assertions compare against the real scheme rather than hand-copied colours.
  // Omitting `clipBehavior` here leaves it unset on AppCard too, so the
  // default is exercised rather than passed back in (a pinch of setup that
  // would otherwise make the "defaults to Clip.none" pin vacuous).
  Future<void> pumpCard(
    WidgetTester tester, {
    Clip? clipBehavior,
    Widget child = const Text('body'),
  }) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: clipBehavior == null
              ? AppCard(child: child)
              : AppCard(clipBehavior: clipBehavior, child: child),
        ),
      ));

  Card cardOf(WidgetTester tester) => tester.widget<Card>(find.byType(Card));

  // The component exists so the decoration has one definition: twelve call
  // sites used to repeat it, four of them with a literal `circular(16)` that
  // can drift from the token.
  testWidgets('renders the Stitch card surface from the design tokens',
      (tester) async {
    await pumpCard(tester);

    final scheme = Theme.of(tester.element(find.byType(AppCard))).colorScheme;
    final card = cardOf(tester);

    expect(card.color, scheme.surface,
        reason: 'card fill must be scheme.surface, not a literal colour');

    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, AppTheme.cardRadius,
        reason: 'radius must come from AppTheme.cardRadius, not a literal 16');
    expect(shape.side.color, scheme.outlineVariant);
    expect(shape.side.width, 1);
  });

  // Defaults mirror Card's own, so swapping `Card` for `AppCard` at a call site
  // cannot silently start clipping a child.
  testWidgets('defaults to Clip.none, as Card does', (tester) async {
    await pumpCard(tester);

    expect(cardOf(tester).clipBehavior, Clip.none,
        reason: 'a call site that changes nothing must keep not clipping');
  });

  testWidgets('propagates an explicit clip for ink surfaces', (tester) async {
    await pumpCard(tester, clipBehavior: Clip.antiAlias);

    expect(cardOf(tester).clipBehavior, Clip.antiAlias);
  });

  // Padding stays the call site's business, so a caller keeps full control of
  // the inner layout while the surface stays shared.
  testWidgets('renders its child on the card surface', (tester) async {
    await pumpCard(
      tester,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('inner'),
      ),
    );

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('inner')),
      findsOneWidget,
    );
  });
}
