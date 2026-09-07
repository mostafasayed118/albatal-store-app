import 'fixtures/local_catalog_repository.dart';
import 'helpers/memory_storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Retired-product deep links must offer a way back to a REGISTERED route.
///
/// Regression: the notFound CTA called `go('/')`, but `/` was never
/// registered, so the button dead-ended on "Page Not Found".
void main() {
  testWidgets('notFound CTA navigates to /home', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/product/retired-xyz',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home stub')),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, s) {
            final persistence = MemoryStorefrontPersistence();
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => WishlistCubit(persistence)),
                BlocProvider(create: (_) => CartCubit(persistence)),
              ],
              child: DetailsPage(
                id: s.pathParameters['id']!,
                catalogRepository: LocalCatalogRepository(),
              ),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Return to home'), findsOneWidget);
    await tester.tap(find.text('Return to home'));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
    expect(find.textContaining('Page Not Found'), findsNothing);
  });
}
