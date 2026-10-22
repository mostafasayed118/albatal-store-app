import 'package:al_batal_elite/features/storefront/presentation/widgets/home/recent_queries.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<String> queries,
  required ValueChanged<String> onDelete,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HomeRecentQueries(queries: queries, onDelete: onDelete),
      ),
    );

void main() {
  testWidgets('renders one deletable chip per recent query', (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      _harness(queries: const ['silk', 'gold'], onDelete: deleted.add),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('silk'), findsOneWidget);
    expect(find.text('gold'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.close).first);
    expect(deleted, ['silk']);
  });

  testWidgets('no history renders no chips', (tester) async {
    await tester.pumpWidget(
      _harness(queries: const [], onDelete: (_) {}),
    );

    expect(find.byType(Chip), findsNothing);
  });
}
