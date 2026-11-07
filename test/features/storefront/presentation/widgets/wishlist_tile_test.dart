import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/product_image_placeholder.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/wishlist_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/app_fonts.dart';

final class _CartRepository implements CartRepository {
  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async =>
      const Success(null);
}

final class _WishlistRepository implements WishlistRepository {
  @override
  Future<Result<Set<String>>> readWishlist() async => const Success({});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

const _product = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF176B57,
  imageAsset: 'assets/images/1.svg',
  stock: {'Emerald': 5},
);

Future<void> _pumpTile(
  WidgetTester tester, {
  required Size view,
  required double cellWidth,
  required double cellHeight,
  required double textScale,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cart = CartCubit(_CartRepository());
  final wishlist = WishlistCubit(_WishlistRepository());
  addTearDown(() async {
    await cart.close();
    await wishlist.close();
  });

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cart),
      BlocProvider.value(value: wishlist),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: cellWidth,
                height: cellHeight,
                child: const WishlistTile(product: _product),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('wishlist tile keeps a square media slot at 2.0x text scale',
      (tester) async {
    await loadAppFonts();
    // The 2.0x cell the wishlist delegate produces at 360dp.
    await _pumpTile(tester,
        view: const Size(360, 640),
        cellWidth: 158,
        cellHeight: 395,
        textScale: 2.0);

    expect(tester.takeException(), isNull);

    final media = tester.getSize(find.byType(ProductImagePlaceholder));
    // The old Expanded + Spacer pair left ~50dp of image at this scale; the
    // square slot now uses the full width-bound media area.
    expect(media.height, greaterThan(100),
        reason: 'square media must not collapse when text doubles');
    expect(media.width, closeTo(media.height, 1));
  });

  testWidgets('wishlist tile keeps a square media slot on a 320dp phone',
      (tester) async {
    await loadAppFonts();
    // Narrow-phone cell: 138dp wide, 0.52 aspect ratio.
    await _pumpTile(tester,
        view: const Size(320, 640),
        cellWidth: 138,
        cellHeight: 265,
        textScale: 1.0);

    expect(tester.takeException(), isNull);

    final media = tester.getSize(find.byType(ProductImagePlaceholder));
    expect(media.height, greaterThan(90),
        reason: 'media must keep its slot on the narrowest supported phone');
    expect(media.width, closeTo(media.height, 1));
  });
}
