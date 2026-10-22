import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/related_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Catalog stub that returns a WIDE related strip (3 rows) so the horizontal
/// list actually renders its inter-card separator.
final class _WideRelatedCatalog implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Success(products.firstWhere((p) => p.id == id));

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async =>
      Success(products.where((p) => p.id != excludeId).take(3).toList());
}

final class _NoopShareService implements ShareService {
  @override
  Future<void> shareText(String message) async {}

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {}
}

final class _NoopWhatsAppShareService implements WhatsAppShareService {
  @override
  Future<bool> share(String message) async => true;
}

void main() {
  testWidgets('the related strip renders more than one card', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final persistence = MemoryStorefrontPersistence();
    final router = GoRouter(
      initialLocation: '/product/silk-01',
      routes: [
        GoRoute(
          path: '/product/:id',
          builder: (_, s) => DetailsPage(
            id: s.pathParameters['id']!,
            catalogRepository: _WideRelatedCatalog(),
            whatsappShareService: _NoopWhatsAppShareService(),
            shareService: _NoopShareService(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => WishlistCubit(persistence)),
          BlocProvider(create: (_) => CartCubit(persistence)),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Related Products'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Two or more laid-out cards mean the separated list rendered the
    // separator between them.
    expect(find.byType(RelatedCard), findsAtLeastNWidgets(2));
  });
}
