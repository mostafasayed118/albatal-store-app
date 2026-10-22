import 'package:al_batal_elite/features/storefront/presentation/widgets/catalog_empty_state.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the empty copy and fires the clear callback',
      (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CatalogEmptyState(onClear: () => cleared = true),
        ),
      ),
    );

    expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    expect(find.text('No fabrics found'), findsOneWidget);
    expect(find.text('Try another search'), findsOneWidget);
    expect(find.text('View all fabrics'), findsOneWidget);
    expect(cleared, isFalse);

    await tester.tap(find.text('View all fabrics'));
    expect(cleared, isTrue);
  });
}
