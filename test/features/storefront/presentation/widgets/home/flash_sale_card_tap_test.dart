import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/home/flash_sale_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/memory_storefront_persistence.dart';

const _flashProduct = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF176B57,
);

/// The flash-sale card is a second route into the product — tapping it must
/// push the product route, not just the add-to-cart button.
final _countdown = Stream<Duration>.value(const Duration(minutes: 5));

void main() {
  testWidgets('tapping the flash sale card pushes the product route',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => BlocProvider(
            create: (_) => CartCubit(MemoryStorefrontPersistence()),
            child: HomeFlashSaleCard(
              product: _flashProduct,
              discountLabel: '-20%',
              countdown: _countdown,
            ),
          ),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, s) =>
              Scaffold(body: Text('Product stub ${s.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsOneWidget);

    await tester.tap(find.text('Royal Emerald Silk'));
    await tester.pumpAndSettle();

    expect(find.text('Product stub silk-01'), findsOneWidget);
  });
}
