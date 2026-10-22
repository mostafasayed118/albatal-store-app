import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_product_edit_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_only_admin_repository.dart';

void main() {
  late TestOnlyAdminRepository repo;

  setUp(() {
    repo = TestOnlyAdminRepository();
  });

  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget harness() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductEditPage(repository: repo),
      );

  Future<void> fillIdentity(WidgetTester tester, {String? price}) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Silk Scarf');
    await tester.enterText(find.byType(TextFormField).at(1), 'silk-scarf');
    await tester.enterText(find.byType(TextFormField).at(4), price ?? '450');
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Product'));
  }

  testWidgets(
      'edit prefill saves through the page and pops with the update ack',
      (tester) async {
    repo.categoriesResult = const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('list')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, __) => AdminProductEditPage(
            productId: 'p-1',
            initialData: const {
              'name': 'Royal Emerald Silk',
              'slug': 'royal-emerald-silk',
              'description': 'Woven in the delta',
              'composition': '100% silk',
              'care': 'Dry clean',
              'origin': 'Egypt',
              'width_cm': '140',
              'gsm': '95',
              'min_cut_meters': '0.5',
              'sell_by_length': 'true',
              'base_price': 189000,
              'is_active': false,
              'category_id': 'c-1',
            },
            repository: repo,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    tallViewport(tester);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    unawaited(router.push('/edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Product'), findsOneWidget);
    final nameField =
        tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    expect(nameField.controller?.text, 'Royal Emerald Silk');
    expect(find.text('Minimum cut (meters)'), findsOneWidget,
        reason: 'sell_by_length prefill exposes the cut field');

    await tester.ensureVisible(find.text('Update Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Product'));
    await tester.pumpAndSettle();

    expect(repo.upsertProductCalls, 1);
    expect(repo.lastUpsertProductId, 'p-1');
    expect(repo.lastUpsertCategoryId, 'c-1');
    expect(repo.lastUpsertBasePrice, const Money.egp(1890));
    expect(find.text('Product updated'), findsOneWidget);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('submitting while categories load reports the missing category',
      (tester) async {
    final pending = Completer<Result<List<AdminCategory>>>();
    repo.categoriesHandler = () => pending.future;
    tallViewport(tester);

    await tester.pumpWidget(harness());
    await tester.pump();

    await fillIdentity(tester);
    // The category spinner animates forever while the read is pending, so
    // this test cannot use pumpAndSettle to reveal the submit button.
    await tester.ensureVisible(find.text('Create Product'));
    await tester.pump();
    await tester.tap(find.text('Create Product'));
    await tester.pump();

    expect(find.text('Please select a category'), findsOneWidget);
    expect(repo.upsertProductCalls, 0);

    pending.complete(const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]));
    await tester.pumpAndSettle();
  });

  testWidgets('a sub-piastre price is rejected as invalid', (tester) async {
    repo.categoriesResult = const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]);
    tallViewport(tester);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await fillIdentity(tester, price: '1.234');
    await tapCreate(tester);
    await tester.pump();

    expect(find.text('Invalid price'), findsOneWidget);
    expect(repo.upsertProductCalls, 0);
  });

  testWidgets('a zero price is rejected before the repository', (tester) async {
    repo.categoriesResult = const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]);
    tallViewport(tester);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await fillIdentity(tester, price: '0');
    await tapCreate(tester);
    await tester.pump();

    expect(find.text('Price cannot be negative'), findsOneWidget);
    expect(repo.upsertProductCalls, 0);
  });

  testWidgets('a failed create surfaces the repository error and stays up',
      (tester) async {
    repo.categoriesResult = const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]);
    repo.upsertProductResult = const Failure(AppError('create rejected'));
    tallViewport(tester);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await fillIdentity(tester);
    await tapCreate(tester);
    await tester.pumpAndSettle();

    expect(repo.upsertProductCalls, 1);
    expect(find.text('create rejected'), findsOneWidget);
    expect(find.byType(AdminProductEditPage), findsOneWidget);
  });

  testWidgets('the switches drive sell-by-length and active state',
      (tester) async {
    repo.categoriesResult = const Success(<AdminCategory>[
      AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
    ]);
    tallViewport(tester);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Minimum cut (meters)'), findsNothing);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Minimum cut (meters)'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    final active = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).last,
    );
    expect(active.value, isFalse);
  });
}
