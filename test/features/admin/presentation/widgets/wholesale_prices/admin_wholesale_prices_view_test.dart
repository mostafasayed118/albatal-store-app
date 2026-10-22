import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_catalog_port.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_wholesale_prices_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_wholesale_prices_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/wholesale_prices/admin_wholesale_prices_view.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPricesRepository extends Mock implements AdminWholesalePricesPort {}

class _MockCatalogRepository extends Mock implements AdminCatalogPort {}

AdminProduct _product(String id, String name) => AdminProduct(
      id: id,
      name: name,
      slug: 'slug-$id',
      categoryId: 'cat',
      categoryName: 'Fabrics',
      basePrice: const Money(20000),
      isActive: true,
    );

const _silk = AdminWholesalePriceEntry(
    productId: 'p1', productName: 'Silk', priceMinor: 15000);
const _linen = AdminWholesalePriceEntry(
    productId: 'p2', productName: 'Linen', priceMinor: 9000);

Widget _harness(AdminWholesalePricesCubit cubit) =>
    BlocProvider<AdminWholesalePricesCubit>.value(
      value: cubit,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminWholesalePricesView(),
      ),
    );

Future<void> _openAddSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump();
}

/// Submits a valid form. The view disposes its controller as soon as the
/// sheet pops, before the exit animation ends — rebuilding that exiting
/// sheet would trip a disposed-controller assertion (lib defect, not the
/// test target). Replacing the tree drops the route without rebuilding it.
Future<void> _submitAndDismiss(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump();
}

void main() {
  late _MockPricesRepository repository;
  late _MockCatalogRepository catalog;
  late AdminWholesalePricesCubit cubit;

  setUp(() {
    repository = _MockPricesRepository();
    catalog = _MockCatalogRepository();
    cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);
    when(() => catalog.getAllProducts()).thenAnswer((_) async =>
        Success([_product('p1', 'Silk'), _product('p2', 'Linen')]));
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([_silk, _linen]));
  });

  testWidgets('renders the shared loading state while both reads are pending',
      (tester) async {
    final pending = Completer<Result<List<AdminWholesalePriceEntry>>>();
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) => pending.future);
    unawaited(cubit.load());

    await tester.pumpWidget(_harness(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const Success([]));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error body offers a retry that reloads the price list',
      (tester) async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Failure(AppError('prices offline')));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('prices offline'), findsOneWidget);

    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([_silk]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => repository.fetchWholesalePrices()).called(2);
    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('prices offline'), findsNothing);
  });

  testWidgets('empty list renders the empty state and keeps the add FAB',
      (tester) async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([]));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    final empty = tester.widget<FeedbackView>(find.byType(FeedbackView));
    expect(empty.type, FeedbackViewType.empty);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add wholesale price'), findsNWidgets(2),
        reason: 'FAB label plus the empty-state body');
  });

  testWidgets('lists negotiated prices with edit/delete affordances',
      (tester) async {
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('Linen'), findsOneWidget);
    expect(find.text('EGP 150.00'), findsOneWidget);
    expect(find.text('EGP 90.00'), findsOneWidget);
    expect(find.byTooltip('Save price'), findsNWidgets(2));
    expect(find.byTooltip('Delete price'), findsNWidgets(2));
  });

  testWidgets('add sheet validates product + positive price before upserting',
      (tester) async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([]));
    when(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        )).thenAnswer((_) async => const Success(null));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));
    await _openAddSheet(tester);

    // No product, no price.
    await _tapSubmit(tester, 'Add wholesale price');
    verifyNever(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        ));

    // Price but still no product.
    await tester.enterText(find.byType(TextField).last, '50');
    await _tapSubmit(tester, 'Add wholesale price');
    verifyNever(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        ));

    // Product but a non-positive price.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silk').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0');
    await _tapSubmit(tester, 'Add wholesale price');
    verifyNever(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        ));

    // Product but an unparseable price.
    await tester.enterText(find.byType(TextField).last, 'invalid');
    await _tapSubmit(tester, 'Add wholesale price');
    verifyNever(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        ));

    // Valid submit sends minor units and drops the sheet.
    await tester.enterText(find.byType(TextField).last, '125');
    await _submitAndDismiss(tester, 'Add wholesale price');

    verify(() => repository.upsertWholesalePrice(
          productId: 'p1',
          priceMinor: 12500,
        )).called(1);
    verify(() => repository.fetchWholesalePrices()).called(2);
  });

  testWidgets('edit sheet pins the product and upserts minor units',
      (tester) async {
    when(() => repository.upsertWholesalePrice(
          productId: any(named: 'productId'),
          priceMinor: any(named: 'priceMinor'),
        )).thenAnswer((_) async => const Success(null));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(find.byTooltip('Save price').first);
    await tester.pumpAndSettle();

    final productField =
        tester.widget<TextFormField>(find.byType(TextFormField));
    expect(productField.enabled, isFalse,
        reason: 'the edit row targets the existing product id');
    expect(
      find.descendant(
          of: find.byType(TextFormField), matching: find.text('Silk')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, '200');
    await _submitAndDismiss(tester, 'Save price');

    verify(() => repository.upsertWholesalePrice(
          productId: 'p1',
          priceMinor: 20000,
        )).called(1);
  });

  testWidgets('delete cancel leaves the row, confirm removes it',
      (tester) async {
    when(() => repository.deleteWholesalePrice('p1'))
        .thenAnswer((_) async => const Success(null));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(find.byTooltip('Delete price').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete price'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteWholesalePrice(any()));
    expect(find.text('Silk'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete price').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteWholesalePrice('p1')).called(1);
    expect(find.text('Silk'), findsNothing);
    expect(find.text('Linen'), findsOneWidget);
  });

  testWidgets('delete failure surfaces the machine message with a retry',
      (tester) async {
    when(() => repository.deleteWholesalePrice('p1'))
        .thenAnswer((_) async => const Failure(AppError('delete rejected')));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(find.byTooltip('Delete price').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('delete rejected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
