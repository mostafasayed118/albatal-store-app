import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accent style paints the secondary/onSecondary pair',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.green),
      home: Scaffold(
        body: AppButton(
          label: 'Continue',
          icon: Icons.arrow_forward,
          style: AppButtonStyle.accent,
          onPressed: () {},
        ),
      ),
    ));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final context = tester.element(find.byType(FilledButton));
    final scheme = Theme.of(context).colorScheme;

    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}),
        scheme.secondary);
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onSecondary);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
