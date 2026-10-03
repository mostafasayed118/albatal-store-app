import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wholesale_price_source.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

const _silk = Product(
  id: 'silk',
  name: 'Silk Charmeuse',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF004D40,
  sellByLength: true,
  minCutMeters: 1.0,
);

final class _OneProductCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Success(_silk);

  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([_silk]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['Silk']);

  @override
  Product? findProductById(String id) => id == _silk.id ? _silk : null;

  @override
  List<String> get defaultCategories => const ['Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() =>
      Future.value(const Success<List<FlashSale>>([]));
}

final class _FakeWholesaleSource implements WholesalePriceSource {
  _FakeWholesaleSource(this._prices);

  final Map<String, Money> _prices;
  var calls = 0;

  @override
  Future<Map<String, Money>> fetchWholesalePrices(
      Iterable<String> productIds) async {
    calls++;
    return {
      for (final id in productIds)
        if (_prices[id] case final price?) id: price,
    };
  }
}

/// Answers each call with the next queued future — the staleness harness:
/// the FIRST (soon-stale) fetch parks on a gate while a newer load
/// completes with its own price.
final class _SequencedSource implements WholesalePriceSource {
  final List<Future<Map<String, Money>>> _answers;
  var _next = 0;

  _SequencedSource(this._answers);

  @override
  Future<Map<String, Money>> fetchWholesalePrices(
          Iterable<String> productIds) =>
      _answers[_next++ % _answers.length];
}

void main() {
  test('wholesale viewer: the product is re-emitted with the list price',
      () async {
    final source = _FakeWholesaleSource({
      'silk': const Money(8000),
    });
    final cubit =
        ProductDetailsCubit(_OneProductCatalog(), wholesalePrices: source);
    addTearDown(cubit.close);

    await cubit.loadProduct('silk', viewerTier: MembershipTier.wholesale);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, DetailsStatus.ready);
    expect(cubit.state.product?.price, const Money.egp(1290),
        reason: 'the catalog price never changes');
    expect(cubit.state.product?.wholesalePrice, const Money(8000));
    expect(cubit.state.product?.effectiveBasePrice, const Money(8000));
  });

  test('non-wholesale viewers never query the price list', () async {
    final source = _FakeWholesaleSource({'silk': const Money(8000)});
    final cubit =
        ProductDetailsCubit(_OneProductCatalog(), wholesalePrices: source);
    addTearDown(cubit.close);

    await cubit.loadProduct('silk', viewerTier: MembershipTier.premium);
    await Future<void>.delayed(Duration.zero);
    await cubit.loadProduct('silk');
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 0);
    expect(cubit.state.product?.wholesalePrice, isNull);
  });

  test('a wholesale viewer on a product without a list row sees no price',
      () async {
    final source = _FakeWholesaleSource(const {});
    final cubit =
        ProductDetailsCubit(_OneProductCatalog(), wholesalePrices: source);
    addTearDown(cubit.close);

    await cubit.loadProduct('silk', viewerTier: MembershipTier.wholesale);
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 1);
    expect(cubit.state.product?.wholesalePrice, isNull);
  });

  test('a stale attach can never re-price a newer load', () async {
    // The first fetch (load A) parks on this gate; the second load B
    // completes with its own price immediately.
    final parkedA = Completer<Map<String, Money>>();
    final source = _SequencedSource([
      parkedA.future,
      Future.value({'silk': const Money(3000)}),
    ]);
    final cubit =
        ProductDetailsCubit(_OneProductCatalog(), wholesalePrices: source);
    addTearDown(cubit.close);

    unawaited(cubit.loadProduct('silk', viewerTier: MembershipTier.wholesale));
    await Future<void>.delayed(Duration.zero);
    await cubit.loadProduct('silk', viewerTier: MembershipTier.wholesale);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.product?.wholesalePrice, const Money(3000));

    // Load A's price lands late — generation-stale, must be ignored.
    parkedA.complete({'silk': const Money(8000)});
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.product?.wholesalePrice, const Money(3000),
        reason: 'a stale continuation can never re-price product B');
  });
}
