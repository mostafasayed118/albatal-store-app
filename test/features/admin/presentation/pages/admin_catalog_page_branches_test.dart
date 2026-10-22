import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_catalog_page.dart';
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

  Widget harness() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCatalogPage(repository: repo),
      );

  testWidgets('an AppError from the admin probe shows its message',
      (tester) async {
    repo.adminCheckError = const AppError('probe rejected');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Products'));
    await tester.pumpAndSettle();

    expect(find.text('probe rejected'), findsOneWidget);
  });

  testWidgets('a generic probe failure shows the safe fallback copy',
      (tester) async {
    repo.adminCheckError = StateError('boom');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Products'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to verify admin access. Please try again.'),
        findsOneWidget);
  });

  testWidgets('review, customer, and sales tiles reach their routes',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/admin/catalog',
      routes: [
        GoRoute(
          path: '/admin/catalog',
          builder: (_, __) => AdminCatalogPage(repository: repo),
        ),
        GoRoute(
          path: '/admin/reviews',
          builder: (_, __) => const Scaffold(body: Text('reviews page')),
        ),
        GoRoute(
          path: '/admin/customers',
          builder: (_, __) => const Scaffold(body: Text('customers page')),
        ),
        GoRoute(
          path: '/admin/sales',
          builder: (_, __) => const Scaffold(body: Text('sales page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review moderation'));
    await tester.pumpAndSettle();
    expect(find.text('reviews page'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customers').first);
    await tester.pumpAndSettle();
    expect(find.text('customers page'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sales Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('sales page'), findsOneWidget);
    expect(repo.adminChecks, 3);
  });
}
