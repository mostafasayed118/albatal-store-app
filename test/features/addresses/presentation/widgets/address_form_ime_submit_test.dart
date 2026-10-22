import 'package:al_batal_elite/features/addresses/presentation/widgets/address_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The country field carries the keyboard "done" action, so the IME path
/// is a second, independent way to submit the address form.
Widget _harness() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final address = await AddressForm.show(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(address?.toString() ?? 'cancelled')),
                );
              }
            },
            child: const Text('Open Form'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the keyboard done action submits the address form',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'), 'Sara Ahmed');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'), '01012345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Street address'),
        '45 Nile Corniche');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Cairo');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Country'), 'Egypt');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Sara Ahmed'), findsOneWidget);
    expect(find.textContaining('45 Nile Corniche'), findsOneWidget);
    expect(find.textContaining('Egypt'), findsOneWidget);
  });
}
