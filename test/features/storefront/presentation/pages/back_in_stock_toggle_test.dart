import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/wishlist_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

final class _MemAlertStore implements BackInStockAlertStore {
  Set<String> watched = {};

  @override
  Set<String> get watchedProductIds => {...watched};

  @override
  bool isWatched(String productId) => watched.contains(productId);

  @override
  void setWatched(String productId, bool enabled) =>
      enabled ? watched.add(productId) : watched.remove(productId);
}

const _outOfStock = Product(
  id: 'p_oos',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF176B57,
  // No variant stock at all -> out of stock.
);
const _inStock = Product(
  id: 'p_in',
  name: 'Golden Cotton Weave',
  category: 'Cotton',
  price: Money.egp(640),
  imageColor: 0xFFD9C6A1,
  stock: {'Emerald-1m': 4},
);

class _StubRepo with FetchRelatedFromProducts implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success([_outOfStock, _inStock]);
  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['Silk', 'Cotton']);
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));
  @override
  Product? findProductById(String id) => null;
  @override
  List<String> get defaultCategories => const ['All'];
  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

void main() {
  testWidgets(
      'out-of-stock wishlist tile shows the back-in-stock toggle; tapping '
      'registers the alert and toasts', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence()
      ..wishlistIds = {'p_oos', 'p_in'};
    final alertStore = _MemAlertStore();

    // Mirror app start-up order: wishlist restore and catalog load
    // complete before the wishlist page is first built, so the page's
    // post-frame resolveProducts matches against a populated catalog.
    final catalog = CatalogCubit(_StubRepo());
    final wishlist = WishlistCubit(store, alertStore: alertStore);
    await catalog.load();
    await wishlist.restore();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: catalog),
          BlocProvider.value(value: wishlist),
          BlocProvider(create: (_) => CartCubit(store)),
        ],
        child: const WishlistPage(),
      ),
    ));
    await tester.pumpAndSettle();

    // The toggle is reachable on the out-of-stock tile only; the
    // in-stock tile keeps the move-to-cart button instead.
    final toggles = find.text('Notify me when back in stock');
    expect(toggles, findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(find.text('Move to Cart'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    // Toggle ON -> registered in the preset store + toast snackbar.
    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(alertStore.isWatched('p_oos'), isTrue);
    expect(
      find.text("We'll notify you when Royal Emerald Silk is back in stock"),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // Toggle OFF -> unregistered + removal toast.
    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(alertStore.isWatched('p_oos'), isFalse);
    expect(find.text('Back-in-stock alert removed'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    // Pre-created with BlocProvider.value: close them here so the
    // cubit close() cancels CatalogCubit's 60s flash-poll timer before
    // the binding's pending-timer invariant runs.
    await catalog.close();
    await wishlist.close();
  });
}
