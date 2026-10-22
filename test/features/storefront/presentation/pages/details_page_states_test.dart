import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/add_to_cart_button.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/back_in_stock_toggle.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/related_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Catalog stub that exercises the legacy full-list fallback: the
/// single-row fetch fails, so the page loads via `fetchProducts`.
final class _FallbackCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('single-row fetch unavailable'));

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

/// Catalog stub whose full-list fetch fails until [fail] is cleared,
/// so a Retry can recover.
final class _RetryCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  bool fail = true;

  @override
  Future<Result<List<Product>>> fetchProducts() async => fail
      ? const Failure(AppError('catalog offline'))
      : Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('single-row fetch unavailable'));

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

final class _RecordingShareService implements ShareService {
  final List<String> messages = [];

  @override
  Future<void> shareText(String message) async => messages.add(message);

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {}
}

final class _RecordingWhatsAppShareService implements WhatsAppShareService {
  final List<String> messages = [];

  @override
  Future<bool> share(String message) async {
    messages.add(message);
    return true;
  }
}

Widget _app(GoRouter router) {
  final persistence = MemoryStorefrontPersistence();
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => WishlistCubit(persistence)),
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
  required CatalogRepository catalogRepository,
  ShareService? shareService,
  WhatsAppShareService? whatsappShareService,
}) =>
    GoRouter(
      initialLocation: '/product/silk-01',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home stub')),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, s) => DetailsPage(
            id: s.pathParameters['id']!,
            catalogRepository: catalogRepository,
            whatsappShareService:
                whatsappShareService ?? _RecordingWhatsAppShareService(),
            shareService: shareService ?? _RecordingShareService(),
          ),
        ),
      ],
    );

ProductDetailsCubit _cubitOf(WidgetTester tester) =>
    BlocProvider.of<ProductDetailsCubit>(
      tester.element(find.byType(AddToCartButton)),
    );

void main() {
  testWidgets(
      'legacy fallback loads the product, renders related cards, and pushes '
      'the tapped related product', (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = _router(catalogRepository: _FallbackCatalog());
    await tester.pumpWidget(
      _app(router),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.text('Related Products'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(RelatedCard).first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.byType(RelatedCard), findsWidgets);
    tester.widget<RelatedCard>(find.byType(RelatedCard).first).onTap();
    await tester.pumpAndSettle();

    expect(find.text('Desert Gold Silk'), findsWidgets);
  });

  testWidgets('variant + quantity changes rebuild the selector and CTA',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(_router(catalogRepository: _FallbackCatalog())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final cubit = _cubitOf(tester);
    cubit.color('Gold');
    await tester.pump();
    cubit.length('2m');
    await tester.pump();
    cubit.quantity(2);
    await tester.pump();

    expect(cubit.state.color, 'Gold');
    expect(cubit.state.length, '2m');
    expect(cubit.state.quantity, 2);
    expect(find.text('Add to Cart - 2,580 EGP'), findsOneWidget);
  });

  testWidgets('selecting an out-of-stock variant reveals the restock toggle',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(_router(catalogRepository: _FallbackCatalog())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Color'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ivory'));
    await tester.pump();
    await tester.tap(find.text('5m'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(BackInStockToggle),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byType(BackInStockToggle), findsOneWidget);
  });

  testWidgets('share actions use the injected services', (tester) async {
    final share = _RecordingShareService();
    final whatsapp = _RecordingWhatsAppShareService();

    await tester.pumpWidget(
      _app(
        _router(
          catalogRepository: _FallbackCatalog(),
          shareService: share,
          whatsappShareService: whatsapp,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share on WhatsApp'));
    await tester.pump();
    expect(whatsapp.messages, hasLength(1));
    expect(whatsapp.messages.single, contains('Royal Emerald Silk'));

    await tester.tap(find.byTooltip('Share product'));
    await tester.pump();
    expect(share.messages, hasLength(1));
    expect(share.messages.single, contains('Royal Emerald Silk'));
  });

  testWidgets('size guide opens from the details body', (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(_router(catalogRepository: _FallbackCatalog())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Size Guide'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Size Guide'));
    await tester.pumpAndSettle();

    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Full suits, upholstery'), findsOneWidget);
  });

  testWidgets('error view retries and recovers to the product', (tester) async {
    final catalog = _RetryCatalog();

    await tester.pumpWidget(
      _app(_router(catalogRepository: catalog)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);

    catalog.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsNothing);
    expect(find.text('Royal Emerald Silk'), findsNWidgets(2));
  });
}
