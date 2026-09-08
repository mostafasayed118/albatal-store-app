import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/cart_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_item_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'helpers/memory_storefront_persistence.dart';
import 'fixtures/products_data.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

CatalogState _seeded() => CatalogState(
      status: CatalogStatus.ready,
      allProducts: products,
      categories: categories,
      filters: const CatalogFilters(),
    );

Order _order(String id, OrderStatus status) => Order(
      id: id,
      items: const [],
      subtotal: Money.egp(100),
      shipping: Money.egp(10),
      total: Money.egp(110),
      status: status,
      placedAt: DateTime(2026, 9, 1),
      paymentMethod: 'cod',
    );

void main() {
  group('P4 — catalog idle cost', () {
    test('idle cubit emits no periodic states (legacy ticker removed)',
        () async {
      final cubit = CatalogCubit(MockCatalogRepository());
      final states = <CatalogState>[];
      final sub = cubit.stream.listen(states.add);

      await Future.delayed(const Duration(milliseconds: 1100));

      await cubit.close();
      await sub.cancel();
      expect(states, isEmpty);
    });

    test('derived views survive countdown-only emits (memo adopt)', () {
      final state = _seeded();
      final visible = state.visible;

      final ticked = state.copyWith(flashRemaining: const Duration(seconds: 5));

      expect(identical(ticked.visible, visible), isTrue);
    });
  });

  group('P4 — query debounce', () {
    blocTest<CatalogCubit, CatalogState>(
      'rapid queries emit once with the last value',
      build: () => CatalogCubit(MockCatalogRepository()),
      seed: _seeded,
      act: (cubit) {
        cubit.updateQuery('s');
        cubit.updateQuery('si');
        cubit.updateQuery('silk');
      },
      wait: const Duration(milliseconds: 500),
      expect: () => [
        _seeded().copyWith(
          filters: const CatalogFilters(query: 'silk'),
          recentQueries: const ['silk'],
        ),
      ],
    );
  });

  group('P4 — orders memo', () {
    test('tab views memoize per state instance', () {
      final state = OrdersState(
        orders: [
          _order('o1', OrderStatus.placed),
          _order('o2', OrderStatus.delivered),
        ],
        status: OrdersStatus.ready,
      );

      expect(identical(state.active, state.active), isTrue);
      expect(identical(state.completed, state.completed), isTrue);
      expect(state.active.map((o) => o.id), ['o1']);
      expect(state.completed.map((o) => o.id), ['o2']);
    });
  });

  group('P4 — cart virtualization', () {
    testWidgets('cart list builds lazily via ListView.builder', (tester) async {
      final store = MemoryStorefrontPersistence();
      final cart = CartCubit(store);
      cart.add(products[0], color: 'Emerald', length: '2m');
      cart.add(products[1], color: 'Natural', length: '1m');
      cart.add(products[2], color: 'Ivory', length: '5m');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cart),
            BlocProvider(create: (_) => WishlistCubit(store)),
          ],
          child: const CartPage(),
        ),
      ));
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView).first);
      expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
      expect(find.byType(CartItemTile), findsNWidgets(3));
    });
  });
}
