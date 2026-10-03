import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/pricing/cut_length_pricing.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wholesale_price_source.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

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

/// Answers each call with the next queued future — parks the first
/// (soon-stale) fetch on a gate the test releases.
final class _SequencedSource implements WholesalePriceSource {
  final List<Future<Map<String, Money>>> _answers;
  var _next = 0;
  var calls = 0;

  _SequencedSource(this._answers);

  @override
  Future<Map<String, Money>> fetchWholesalePrices(Iterable<String> productIds) {
    calls++;
    return _answers[_next++ % _answers.length];
  }
}

void main() {
  test('wholesale viewer: cart lines re-price at the negotiated list price',
      () async {
    final source = _FakeWholesaleSource({products.first.id: const Money(8000)});
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    cubit.add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    cubit.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 1);
    expect(cubit.state.items.single.product.wholesalePrice, const Money(8000));
    expect(cubit.state.items.single.effectiveLineTotal, const Money(16000));
  });

  test('non-wholesale viewers never touch the price list', () async {
    final source = _FakeWholesaleSource({products.first.id: const Money(1)});
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    cubit.add(products.first, color: 'Emerald', length: '2m');
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 0);
    expect(cubit.state.items.single.product.wholesalePrice, isNull);
  });

  test('losing the wholesale tier strips injected prices in place', () async {
    final source = _FakeWholesaleSource({products.first.id: const Money(8000)});
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    cubit.add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    cubit.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items.single.product.wholesalePrice, const Money(8000));

    cubit.setWholesaleViewer(isWholesale: false);
    expect(cubit.state.items.single.product.wholesalePrice, isNull);
    expect(cubit.state.items.single.product.price, products.first.price,
        reason: 'the strip restores the catalog price, never mutates it');
    expect(
        cubit.state.items.single.effectiveLineTotal, products.first.price * 2);
  });

  test('restore re-attaches list prices for a wholesale session', () async {
    final storage = MemoryStorefrontPersistence();
    final source = _FakeWholesaleSource({products.first.id: const Money(8000)});
    Product? lookup(String id) => products.where((p) => p.id == id).firstOrNull;

    final writer = CartCubit(storage, productLookup: lookup);
    writer.add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    await writer.close();

    final restored =
        CartCubit(storage, productLookup: lookup, wholesalePrices: source);
    addTearDown(restored.close);
    restored.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);
    await restored.restore();
    await Future<void>.delayed(Duration.zero);

    expect(
        restored.state.items.single.product.wholesalePrice, const Money(8000),
        reason: 'persisted products resolve without list prices; a wholesale '
            'session must re-attach them or metered checkout fails the '
            "server's line-total cross-check");
  });
  test('attach is a no-op when no line carries a list row', () async {
    final source = _FakeWholesaleSource(const {});
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    cubit.add(products.first, color: 'Emerald', length: '2m');
    cubit.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 1);
    expect(cubit.state.items.single.product.wholesalePrice, isNull);
    expect(cubit.state.items.single.effectiveLineTotal, products.first.price);
  });

  test(
      'a stale attach landing after a tier strip cannot re-attach prices '
      '(shared-device leak guard)', () async {
    // The tier-transition attach parks on this gate; the strip happens
    // while it is in flight.
    final parkedAttach = Completer<Map<String, Money>>();
    final source = _SequencedSource([parkedAttach.future]);
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    cubit.add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    cubit.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 1, reason: 'the transition attach is parked');

    cubit.setWholesaleViewer(isWholesale: false);
    parkedAttach.complete({products.first.id: const Money(8000)});
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items.single.product.wholesalePrice, isNull,
        reason: 'the in-flight attach is tier-stale and must be dropped');
  });

  test('a wholesale add heals its own line when the page attach missed it',
      () async {
    final source = _FakeWholesaleSource({products.first.id: const Money(8000)});
    final cubit =
        CartCubit(MemoryStorefrontPersistence(), wholesalePrices: source);
    addTearDown(cubit.close);

    // Session already wholesale (empty-cart attach is a no-op — no ids).
    cubit.setWholesaleViewer(isWholesale: true);
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 0);

    cubit.add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    await Future<void>.delayed(Duration.zero);

    expect(source.calls, 1, reason: 'add() triggers its own attach');
    expect(cubit.state.items.single.product.wholesalePrice, const Money(8000));
    expect(cubit.state.items.single.effectiveLineTotal, const Money(16000));
  });
}
