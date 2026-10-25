import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/wishlist_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/local_catalog_repository.dart';
import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

final class _WishlistRepo implements WishlistRepository {
  _WishlistRepo({this.ids = const {}});

  Set<String> ids;
  bool failWrites = false;

  @override
  Future<Result<Set<String>>> readWishlist() async => Success({...ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async => failWrites
      ? const Failure(AppError('secure store unavailable'))
      : const Success(null);
}

/// Wishlist read that stays pending until the test completes it, so the
/// page can be observed while a manual refresh is in flight.
final class _DeferredWishlistRepo implements WishlistRepository {
  final reads = <Completer<Result<Set<String>>>>[];

  @override
  Future<Result<Set<String>>> readWishlist() {
    final completer = Completer<Result<Set<String>>>();
    reads.add(completer);
    return completer.future;
  }

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

final class _EmptyCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success<List<Product>>([]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

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

final class _CatalogWithProduct
    with FetchRelatedFromProducts
    implements CatalogRepository {
  _CatalogWithProduct({required this.product});

  Product product;

  @override
  Future<Result<List<Product>>> fetchProducts() async => Success([product]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('single fetch disabled'));

  @override
  Product? findProductById(String id) => id == product.id ? product : null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

final class _RecordingNotifications implements NotificationService {
  final List<({String title, String body})> backInStock = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showBackInStockNotification({
    required String title,
    required String body,
  }) async {
    backInStock.add((title: title, body: body));
  }
}

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

Widget _app(
  GoRouter router, {
  required WishlistCubit wishlist,
  required CatalogCubit catalog,
  NotificationService? notifications,
}) {
  final persistence = MemoryStorefrontPersistence();
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: wishlist),
      BlocProvider(create: (_) => catalog),
      BlocProvider(create: (_) => CartCubit(persistence)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _router({
  required WishlistCubit wishlist,
  required CatalogCubit catalog,
  NotificationService? notifications,
}) =>
    GoRouter(
      initialLocation: '/wishlist',
      routes: [
        GoRoute(
          path: '/wishlist',
          builder: (_, __) => WishlistPage(notificationService: notifications),
        ),
        GoRoute(
          path: '/categories',
          builder: (_, __) => const Scaffold(body: Text('Categories stub')),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, __) => const Scaffold(body: Text('Product stub')),
        ),
      ],
    );

Product _product(String id, {required bool inStock}) => Product(
      id: id,
      name: 'Fabric $id',
      category: 'Silk',
      price: products.first.price,
      imageColor: 0xFF176B57,
      stock: inStock ? const {'Emerald-1m': 3} : const <String, int>{},
    );

void main() {
  testWidgets('the empty wishlist offers a route back to categories',
      (tester) async {
    final wishlist = WishlistCubit(_WishlistRepo());
    await wishlist.restore();
    final catalog = CatalogCubit(_EmptyCatalog());
    await catalog.load();

    await tester.pumpWidget(
      _app(
        _router(wishlist: wishlist, catalog: catalog),
        wishlist: wishlist,
        catalog: catalog,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your wishlist is empty'), findsOneWidget);

    await tester.tap(find.text('Explore Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Categories stub'), findsOneWidget);
  });

  testWidgets('a refresh in flight shows loading, not the empty state',
      (tester) async {
    // Regression: loading had no UI branch, so a force refresh with an
    // empty resolved list read as "nothing saved yet" until the read
    // completed.
    final repo = _DeferredWishlistRepo();
    final wishlist = WishlistCubit(repo);
    addTearDown(wishlist.close);
    final catalog = CatalogCubit(_EmptyCatalog());
    await catalog.load();

    final refresh = wishlist.restore(force: true);
    expect(wishlist.state.status, WishlistStatus.loading);

    await tester.pumpWidget(
      _app(
        _router(wishlist: wishlist, catalog: catalog),
        wishlist: wishlist,
        catalog: catalog,
      ),
    );
    // A real spinner animates forever — never pumpAndSettle here.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Your wishlist is empty'), findsNothing);

    repo.reads.single.complete(const Success(<String>{}));
    await refresh;
    await tester.pumpAndSettle();

    expect(wishlist.state.status, WishlistStatus.ready);
    expect(find.text('Your wishlist is empty'), findsOneWidget);
  });

  testWidgets('a persist failure keeps the grid and surfaces a snackbar',
      (tester) async {
    final repo = _WishlistRepo(ids: {'silk-01'});
    final wishlist = WishlistCubit(repo);
    await wishlist.restore();
    final catalog = CatalogCubit(LocalCatalogRepository());
    await catalog.load();

    await tester.pumpWidget(
      _app(
        _router(wishlist: wishlist, catalog: catalog),
        wishlist: wishlist,
        catalog: catalog,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsOneWidget);

    repo.failWrites = true;
    wishlist.toggle('cotton-01');
    await tester.pumpAndSettle();

    expect(wishlist.state.status, WishlistStatus.error);
    expect(wishlist.state.products, isNotEmpty);
    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
  });

  testWidgets('a catalog refresh triggers wishlist re-resolution',
      (tester) async {
    final wishlist = WishlistCubit(_WishlistRepo(ids: {'silk-01'}));
    await wishlist.restore();
    final catalog = CatalogCubit(LocalCatalogRepository());
    await catalog.load();

    await tester.pumpWidget(
      _app(
        _router(wishlist: wishlist, catalog: catalog),
        wishlist: wishlist,
        catalog: catalog,
      ),
    );
    await tester.pumpAndSettle();

    expect(wishlist.state.products.map((p) => p.id), ['silk-01']);

    await catalog.load();
    await tester.pumpAndSettle();

    expect(wishlist.state.products.map((p) => p.id), ['silk-01']);
  });

  testWidgets('a restock transition fires the injected notification',
      (tester) async {
    final alertStore = _MemAlertStore()..watched = {'p1'};
    final wishlist =
        WishlistCubit(_WishlistRepo(ids: {'p1'}), alertStore: alertStore);
    await wishlist.restore();
    final catalog = CatalogCubit(
      _CatalogWithProduct(product: _product('p1', inStock: false)),
    );
    await catalog.load();
    final notifications = _RecordingNotifications();

    await tester.pumpWidget(
      _app(
        _router(
          wishlist: wishlist,
          catalog: catalog,
          notifications: notifications,
        ),
        wishlist: wishlist,
        catalog: catalog,
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();

    wishlist.resolveProducts([_product('p1', inStock: true)]);
    await tester.pumpAndSettle();

    expect(notifications.backInStock, hasLength(1));
    expect(notifications.backInStock.single.title, 'Back in stock');
    expect(notifications.backInStock.single.body, contains('Fabric p1'));
  });
}
