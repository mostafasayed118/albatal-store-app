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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Audit 2026-09-21 (P0-1): a failed wishlist load used to render the
/// empty state — "nothing saved yet" — because the page branched only on
/// `products.isEmpty` and never consumed [WishlistStatus.error]. These
/// tests pin the error branch: an error view with a working retry, and
/// the empty view reserved for a genuinely empty wishlist.

/// Programmable [WishlistRepository]: fails a read the way a transient
/// secure-store error does, then recovers when [failNextRead] is reset.
class _FakeWishlistRepo implements WishlistRepository {
  _FakeWishlistRepo({this.ids = const {}});

  Set<String> ids;
  bool failNextRead = false;

  @override
  Future<Result<Set<String>>> readWishlist() async => failNextRead
      ? const Failure(AppError('secure store unavailable'))
      : Success({...ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

/// Catalog the page's post-frame resolveProducts matches wishlist ids
/// against (the app shell always provides one above the page).
class _StubRepo with FetchRelatedFromProducts implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success<List<Product>>([]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success<List<String>>([]);

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
  Widget boot(WishlistCubit wishlist, CatalogCubit catalog) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: catalog),
            BlocProvider.value(value: wishlist),
            BlocProvider(
                create: (_) => CartCubit(MemoryStorefrontPersistence())),
          ],
          child: const WishlistPage(),
        ),
      );

  Future<void> pump(
      WidgetTester tester, WishlistCubit wishlist, CatalogCubit catalog) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(boot(wishlist, catalog));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a failed wishlist load shows the localized error view with Retry, '
      'not the "nothing saved yet" empty state', (tester) async {
    final repo = _FakeWishlistRepo()..failNextRead = true;
    final wishlist = WishlistCubit(repo);
    addTearDown(wishlist.close);
    await wishlist.restore();
    expect(wishlist.state.status, WishlistStatus.error);

    // Pre-created with BlocProvider.value: closed in tearDown so the
    // catalog's flash-poll timer can't outlive the test.
    final catalog = CatalogCubit(_StubRepo());
    addTearDown(catalog.close);

    await pump(tester, wishlist, catalog);

    // FeedbackView's localized error defaults + Retry CTA…
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // …and the wishlist-empty copy must NOT appear.
    expect(find.text('Your wishlist is empty'), findsNothing);
    expect(
      find.text('Tap the heart on any product to save it here.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('tapping Retry re-reads the wishlist and recovers',
      (tester) async {
    final repo = _FakeWishlistRepo(ids: {'p_in'});
    final wishlist = WishlistCubit(repo);
    addTearDown(wishlist.close);
    await wishlist.restore();

    final catalog = CatalogCubit(_StubRepo());
    addTearDown(catalog.close);

    // Mid-session read failure while the page is up.
    repo.failNextRead = true;
    await wishlist.restore(force: true);
    await pump(tester, wishlist, catalog);
    expect(find.text('Retry'), findsOneWidget);

    // The store recovers; the Retry CTA re-reads and the list returns.
    repo.failNextRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(wishlist.state.status, WishlistStatus.ready);
    expect(find.text('Retry'), findsNothing);
  });
}
