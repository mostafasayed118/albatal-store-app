import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/pricing/cut_length_pricing.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/repositories/wholesale_price_source.dart';

enum CartStatus { initial, loading, ready, error }

final class CartState extends Equatable {
  const CartState(
    this.items, {
    this.status = CartStatus.initial,
    this.isPremiumMember = false,
  });

  final List<CartItem> items;
  final CartStatus status;

  /// Whether the signed-in customer is a premium member (mirrored from
  /// AuthCubit — see [CartCubit.setPremiumMember]). Drives the shipping
  /// ESTIMATE and local order snapshots only: the authoritative perk is
  /// applied server-side in create_checkout_order (migration 047), so a
  /// stale flag here can never change what is actually charged.
  final bool isPremiumMember;

  /// Display estimate: metered lines use the tier-aware metered total
  /// and sample lines are zero — the server totals stay authoritative.
  Money get subtotal =>
      items.fold(Money.zero, (value, item) => value + item.effectiveLineTotal);

  /// Shipping estimate. Zero for premium members, matching the server's
  /// free-shipping perk (migration 047); the checkout page carries the
  /// estimate disclaimer and the server-confirmed totals are what charge.
  Money get shipping =>
      items.isEmpty || isPremiumMember ? Money.zero : const Money.egp(75);
  Money get total => subtotal + shipping;
  int get count => items.fold(0, (value, item) => value + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    CartStatus? status,
    bool? isPremiumMember,
  }) =>
      CartState(
        items ?? this.items,
        status: status ?? this.status,
        isPremiumMember: isPremiumMember ?? this.isPremiumMember,
      );

  @override
  List<Object?> get props => [items, status, isPremiumMember];
}

final class CartCubit extends Cubit<CartState> {
  CartCubit(this._repository,
      {ProductLookup? productLookup, this.wholesalePrices})
      : _productLookup = productLookup,
        super(const CartState([]));

  final CartRepository _repository;

  /// B2B (078): wholesale price-list reader. Null in tests / pre-DI
  /// harnesses — cart estimates then always price at catalog values.
  final WholesalePriceSource? wholesalePrices;

  /// Whether the signed-in viewer is a wholesale member (mirrored from
  /// AuthCubit — see [setWholesaleViewer]). Cubit-private: unlike
  /// [CartState.isPremiumMember] it drives no estimate math itself, it
  /// only gates the negotiated price attach/strip.
  bool _isWholesaleViewer = false;

  /// Mirror the signed-in customer's membership tier into the estimate
  /// math (see [CartState.isPremiumMember]). Fired from AuthCubit state
  /// changes in app.dart; no-op when the tier is unchanged.
  void setPremiumMember({required bool isPremium}) {
    if (state.isPremiumMember == isPremium) return;
    emit(state.copyWith(isPremiumMember: isPremium));
  }

  /// Mirror the wholesale tier (078) and keep the cart lines priced in
  /// parity with the server: attaching the negotiated list price makes
  /// every metered `line_total` the client submits match the RPC's
  /// cross-check; stripping on non-wholesale sessions prevents a
  /// wholesale member's in-session prices from surviving a sign-out on
  /// a shared device.
  void setWholesaleViewer({required bool isWholesale}) {
    if (_isWholesaleViewer == isWholesale) return;
    _isWholesaleViewer = isWholesale;
    if (isWholesale) {
      unawaited(_attachWholesalePrices());
    } else {
      _stripWholesalePrices();
    }
  }

  /// Resolves a product id to a [Product] when restoring the cart.
  /// Injected from outside (e.g. the catalog) so this presentation cubit
  /// never imports a data file directly. May be null when the catalog
  /// isn't available yet (e.g. tests); restore then loads items as-is.
  final ProductLookup? _productLookup;

  /// Reload persisted items.
  ///
  /// By default this is a startup fill: if the user already acted
  /// (non-empty cart) a late-completing read must NOT clobber live
  /// state (live-found 2026-09-03: stale persisted items replaced
  /// fresh selections mid-checkout and the server was sent the
  /// wrong product). Pass [force] for an explicit manual refresh
  /// (e.g. the error-state retry button).
  Future<void> restore({bool force = false}) async {
    final hadItems = state.items.isNotEmpty;
    emit(state.copyWith(status: CartStatus.loading));
    final result = await _repository.readCart(_productLookup ?? (_) => null);
    switch (result) {
      case Success(:final value):
        if (force || !hadItems) {
          emit(CartState(value,
              status: CartStatus.ready,
              isPremiumMember: state.isPremiumMember));
          // 078: restored products resolve through [productLookup] (live
          // catalog / cache) and never carry a wholesale price — re-attach
          // so persisted metered lines keep passing the server's
          // line-total cross-check after a restart.
          if (_isWholesaleViewer) unawaited(_attachWholesalePrices());
        } else {
          // Keep the user's live items; just leave loading state.
          emit(state.copyWith(status: CartStatus.ready));
        }
      case Failure(:final error):
        // No raw-message payload: the page renders the localized
        // FeedbackView(error) from the status alone (audit 2026-09-21);
        // the cause rides in the log for diagnosis.
        Log.w('Cart restore failed', category: LogCategory.cubit, error: error);
        emit(state.copyWith(status: CartStatus.error));
    }
  }

  /// Re-price cart lines with the viewer's negotiated list prices (078).
  /// Reads [state.items] AFTER the fetch so an add/remove during the
  /// round-trip is included, not clobbered; emits only when something
  /// actually changed. The source fails soft (empty map) — absence of a
  /// price means the line keeps resolving as usual.
  Future<void> _attachWholesalePrices() async {
    final source = wholesalePrices;
    if (source == null || !_isWholesaleViewer) return;
    final ids = state.items.map((item) => item.product.id).toSet();
    if (ids.isEmpty) return;
    final prices = await source.fetchWholesalePrices(ids);
    // Tier re-check AFTER the fetch (M1): a sign-out / downgrade during
    // the round-trip must not re-attach prices onto the stripped cart.
    if (isClosed || !_isWholesaleViewer || prices.isEmpty) return;
    var changed = false;
    final items = state.items.map((item) {
      final price = prices[item.product.id];
      if (price == null || item.product.wholesalePrice == price) return item;
      changed = true;
      return CartItem(
        product: item.product.withWholesalePrice(price),
        color: item.color,
        length: item.length,
        quantity: item.quantity,
        sample: item.sample,
      );
    }).toList();
    if (isClosed || !changed) return;
    emit(state.copyWith(items: items));
  }

  /// Clear injected wholesale prices (sign-out / non-wholesale session on
  /// a shared device): lines fall back to catalog-price estimates. Sync —
  /// the strip must land before any checkout the ex-viewer can start.
  void _stripWholesalePrices() {
    final items = state.items;
    if (!items.any((item) => item.product.wholesalePrice != null)) return;
    emit(state.copyWith(
      items: items
          .map((item) => item.product.wholesalePrice == null
              ? item
              : CartItem(
                  product: item.product.withWholesalePrice(null),
                  color: item.color,
                  length: item.length,
                  quantity: item.quantity,
                  sample: item.sample,
                ))
          .toList(),
    ));
  }

  void add(Product product,
      {String color = 'Emerald', String length = '2m', int quantity = 1}) {
    // Ignore non-positive adds; clamp to the 1..99 update contract.
    if (quantity <= 0) return;
    final qty = quantity.clamp(1, 99).toInt();
    final item =
        CartItem(product: product, color: color, length: length, quantity: qty);
    final old =
        state.items.where((existing) => existing.key == item.key).firstOrNull;
    if (old == null) {
      _emitAndPersist(
          CartState([...state.items, item], status: CartStatus.ready));
    } else {
      update(item.key, old.quantity + qty);
    }
    // 078 (M2): a wholesale viewer's new line must not stay catalog-priced
    // when the details-page attach missed it (fail-soft error, offline
    // transition) — the fetch re-reads state after the round-trip, so
    // this heals the line without clobbering concurrent edits.
    if (_isWholesaleViewer) unawaited(_attachWholesalePrices());
  }

  /// Add a swatch/sample line for [product]. One sample per color:
  /// re-tapping the button is an idempotent no-op, since sample
  /// quantity is fixed to 1 by the server contract (migration 077).
  /// The line carries `sample: true` into the checkout payload; its
  /// client-side estimate is zero and the server prices it at the
  /// fixed sample price.
  void addSample(Product product, {String color = 'Emerald'}) {
    final item = CartItem(
      product: product,
      color: color,
      length: 'sample',
      quantity: 1,
      sample: true,
    );
    if (state.items.any((existing) => existing.key == item.key)) return;
    _emitAndPersist(
        CartState([...state.items, item], status: CartStatus.ready));
    if (_isWholesaleViewer) unawaited(_attachWholesalePrices());
  }

  void update(String key, int quantity) => _emitAndPersist(CartState(
        state.items
            .map((item) => item.key == key
                ? item.copyWith(quantity: quantity.clamp(1, 99).toInt())
                : item)
            .toList(),
        status: CartStatus.ready,
      ));

  void remove(String key) => _emitAndPersist(CartState(
      state.items.where((item) => item.key != key).toList(),
      status: CartStatus.ready));

  void clear() =>
      _emitAndPersist(const CartState([], status: CartStatus.ready));

  /// Emit the optimistic [next] state, then await persistence and surface
  /// any failure as a follow-up error state. Persistence errors do NOT
  /// roll back the in-memory state (the user's intent is preserved for the
  /// current session) but are reported so the UI can warn that the cart
  /// won't survive a restart. The error emit uses the *current* state
  /// (not the stale [next]) so a second add during the write isn't clobbered.
  Future<void> _emitAndPersist(CartState next) async {
    emit(next);
    final result = await _repository.writeCart(next.items);
    switch (result) {
      case Success():
        // No-op: optimistic state already emitted.
        break;
      case Failure(:final error):
        if (isClosed) return;
        // Persist failure keeps the items on screen; the full-screen
        // error view with restore retry is the pre-existing signal. No
        // raw-message payload: diagnosis rides in the log, not in state
        // that no widget reads (audit 2026-09-21).
        Log.w('Cart persist failed', category: LogCategory.cubit, error: error);
        emit(state.copyWith(status: CartStatus.error));
    }
  }
}
