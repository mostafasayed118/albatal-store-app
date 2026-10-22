import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required int quantity,
  required ValueChanged<int> onChanged,
  int min = 1,
  int max = 99,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: QuantityStepper(
            quantity: quantity,
            onChanged: onChanged,
            min: min,
            max: max,
          ),
        ),
      ),
    );

void main() {
  testWidgets('increment and decrement fire onChanged', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(
      _harness(quantity: 2, onChanged: values.add),
    );

    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.remove_circle_outline));

    expect(values, [3, 1]);
  });

  testWidgets('both buttons disable at the bounds', (tester) async {
    await tester.pumpWidget(
      _harness(quantity: 5, onChanged: (_) {}, min: 5, max: 5),
    );

    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.add_circle_outline),
        matching: find.byType(IconButton),
      ),
    );
    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove_circle_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.onPressed, isNull);
    expect(remove.onPressed, isNull);
  });

  testWidgets('exposes the current value as one adjustable semantics node',
      (tester) async {
    final handle = tester.ensureSemantics();
    final values = <int>[];
    await tester.pumpWidget(
      _harness(quantity: 3, onChanged: values.add),
    );

    final node = tester.getSemantics(find.byType(QuantityStepper));
    expect(node.value, '3');
    expect(node.increasedValue, '4');
    expect(node.decreasedValue, '2');

    final actionIds = node.getSemanticsData().customSemanticsActionIds!;
    expect(actionIds, hasLength(2));
    final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
    for (final actionId in actionIds) {
      owner.performAction(
        node.id,
        SemanticsAction.customAction,
        actionId,
      );
    }
    expect(values, containsAll(<int>[4, 2]));

    handle.dispose();
  });
}
