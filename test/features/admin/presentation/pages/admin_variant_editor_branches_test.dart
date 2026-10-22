import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_variant_editor_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_only_admin_repository.dart';

void main() {
  late TestOnlyAdminRepository repo;

  setUp(() {
    repo = TestOnlyAdminRepository();
  });

  Widget harness() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminVariantEditorPage(productId: 'pid', repository: repo),
      );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('failed load renders the error and retries into the list',
      (tester) async {
    repo.variantsResult = const Failure(AppError('variants down'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('variants down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.variantsResult = const Success(<AdminVariant>[
      AdminVariant(
        variantId: 'v-1',
        size: 'M',
        color: 'Navy',
        stock: 4,
        priceOverride: Money(1250),
      ),
    ]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('variants down'), findsNothing);
    expect(find.text('M / Navy'), findsOneWidget);
    expect(find.text('Stock: 4 • Override: 12.50 EGP'), findsOneWidget);
  });

  testWidgets('empty state opens the add dialog, whose cancel closes it',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('No variants yet'), findsOneWidget);

    await tester.tap(find.text('Add Variant'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Add Variant'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.upsertVariantCalls, 0);
  });

  testWidgets('add dialog validates size/color, stock and price override',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Size and color are required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Size'), 'M');
    await tester.enterText(find.widgetWithText(TextField, 'Color'), 'Navy');
    await tester.enterText(find.widgetWithText(TextField, 'Stock'), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Invalid stock'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Stock'), '3');
    await tester.enterText(
      find.widgetWithText(TextField, 'Price Override (optional)'),
      'abc',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Invalid price override'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Price Override (optional)'),
      '0',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Price override cannot be negative'), findsOneWidget);

    expect(repo.upsertVariantCalls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'a failed save surfaces the repository error and keeps the dialog',
      (tester) async {
    repo.upsertVariantHandler = ({
      required productId,
      required size,
      required color,
      required stock,
      priceOverride,
    }) async =>
        const Failure(AppError('save rejected'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Size'), 'L');
    await tester.enterText(find.widgetWithText(TextField, 'Color'), 'Gold');
    await tester.enterText(find.widgetWithText(TextField, 'Stock'), '9');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('save rejected'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save'), findsOneWidget,
        reason: 'the saving spinner must reset after a failed write');
    expect(repo.lastUpsertSize, 'L');
    expect(repo.lastUpsertColor, 'Gold');
    expect(repo.lastUpsertStock, 9);
  });

  testWidgets('FAB opens the dialog and a valid save closes it',
      (tester) async {
    repo.variantsResult = const Success(<AdminVariant>[
      AdminVariant(variantId: 'v-1', size: 'M', color: 'Navy', stock: 1),
    ]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openDialog(tester);

    expect(find.text('Add Variant'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Size'), 'XL');
    await tester.enterText(find.widgetWithText(TextField, 'Color'), 'Bone');
    await tester.enterText(find.widgetWithText(TextField, 'Stock'), '2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.upsertVariantCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Variant saved'), findsOneWidget);
  });
}
