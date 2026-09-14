import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/notification_service.dart';
import '../../domain/repositories/wishlist_repository.dart';

enum WishlistStatus { initial, loading, ready, error }

final class WishlistState extends Equatable {
  const WishlistState({
    this.status = WishlistStatus.initial,
    this.ids = const {},
    this.products = const [],
    this.alertIds = const {},
    this.errorMessage,
    this.errorCode,
  });

  final WishlistStatus status;
  final Set<String> ids;
  final List<Product> products;

  /// Product ids with an active back-in-stock alert toggle (task #5).
  final Set<String> alertIds;
  final String? errorMessage;

  /// Machine-readable error classification from [AppError.code] for
  /// UI localization (audit 2026-09-14); null when the failure carried
  /// no code — pages fall back to [errorMessage] verbatim.
  final String? errorCode;

  bool contains(String id) => ids.contains(id);

  WishlistState copyWith({
    WishlistStatus? status,
    Set<String>? ids,
    List<Product>? products,
    Set<String>? alertIds,
    String? errorMessage,
    String? errorCode,
  }) =>
      WishlistState(
        status: status ?? this.status,
        ids: ids ?? this.ids,
        products: products ?? this.products,
        alertIds: alertIds ?? this.alertIds,
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

  @override
  List<Object?> get props =>
      [status, ids, products, alertIds, errorMessage, errorCode];
}

final class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit(this._repository, {BackInStockAlertStore? alertStore})
      : _alertStore = alertStore,
        super(const WishlistState());

  final WishlistRepository _repository;

  /// Per-product back-in-stock opt-ins (task #5). Null in tests and
  /// shells who don't register the store; toggling is then a no-op.
  final BackInStockAlertStore? _alertStore;

  /// Broadcast of products that just transitioned to in-stock while an
  /// alert is watched. The page localizes + fires the notification —
  /// the cubit never imports l10n.
  final _restockAlerts = StreamController<Product>.broadcast();
  Stream<Product> get restockAlerts => _restockAlerts.stream;

  /// Reload persisted wishlist IDs.
  ///
  /// By default this is a startup fill: if the user already acted
  /// (non-empty wishlist) a late-completing read must NOT clobber
  /// live state. Pass [force] for an explicit manual refresh.
  Future<void> restore({bool force = false}) async {
    final hadIds = state.ids.isNotEmpty;
    emit(state.copyWith(status: WishlistStatus.loading));
    final result = await _repository.readWishlist();
    // Page popped mid-flight (e.g. guest redirected to sign-in): emitting
    // into a closed cubit throws a StateError.
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        if (force || !hadIds) {
          emit(WishlistState(
            ids: value,
            status: WishlistStatus.ready,
            alertIds: _alertStore?.watchedProductIds ?? const {},
          ));
        } else {
          // Keep the user's live wishlist; just leave loading state.
          emit(state.copyWith(
            status: WishlistStatus.ready,
            alertIds: _alertStore?.watchedProductIds,
          ));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: WishlistStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Resolve wishlist IDs against the product catalog.
  ///
  /// Back-in-stock detection (task #5, client-side slice): when a
  /// watched product was previously resolved out of stock and now has
  /// stock, it is pushed on [restockAlerts] exactly once per
  /// transition. The first resolution never fires — the app must have
  /// OBSERVED the out-of-stock state at runtime first (a server-side
  /// Supabase trigger is the follow-up).
  void resolveProducts(List<Product> allProducts) {
    final matched = allProducts.where((p) => state.ids.contains(p.id)).toList();
    final previousById = {for (final p in state.products) p.id: p};
    for (final p in matched) {
      final prev = previousById[p.id];
      if (prev != null &&
          !prev.inStock &&
          p.inStock &&
          state.alertIds.contains(p.id)) {
        _restockAlerts.add(p);
      }
    }
    emit(state.copyWith(products: matched));
  }

  /// Whether the back-in-stock alert is on for [productId].
  bool isBackInStockWatched(String productId) =>
      state.alertIds.contains(productId);

  /// Toggle the per-product back-in-stock alert (task #5). Writes the
  /// app notification preset store and mirrors it into state so tiles
  /// rebuild. No-op when the store is not registered.
  void toggleBackInStockAlert(String productId, bool enabled) {
    final store = _alertStore;
    if (store == null) return;
    store.setWatched(productId, enabled);
    final next = {...state.alertIds};
    enabled ? next.add(productId) : next.remove(productId);
    emit(state.copyWith(alertIds: next));
  }

  void toggle(String id) {
    final next = {...state.ids}..toggle(id);
    final removed = state.ids.contains(id);
    // Removing from the wishlist also drops its back-in-stock alert —
    // the toggle only exists on wishlist items.
    final alerts = removed ? ({...state.alertIds}..remove(id)) : state.alertIds;
    if (removed) _alertStore?.setWatched(id, false);
    emit(WishlistState(
      ids: next,
      status: WishlistStatus.ready,
      products: removed
          ? state.products.where((p) => p.id != id).toList()
          : state.products,
      alertIds: alerts,
    ));
    _persist(next);
  }

  /// Remove every saved item and clear persistence (account deletion).
  void clearAll() {
    final store = _alertStore;
    if (store != null) {
      for (final id in state.alertIds) {
        store.setWatched(id, false);
      }
    }
    emit(const WishlistState(status: WishlistStatus.ready));
    _persist(const {});
  }

  @override
  Future<void> close() {
    unawaited(_restockAlerts.close());
    return super.close();
  }

  /// Await persistence and surface any failure as a follow-up error state.
  /// The in-memory state is preserved (user's intent kept for the session)
  /// but the UI is warned the wishlist won't survive a restart.
  Future<void> _persist(Set<String> ids) async {
    final result = await _repository.writeWishlist(ids);
    if (isClosed) return;
    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        emit(state.copyWith(
          status: WishlistStatus.error,
          errorMessage: 'Wishlist may not be saved: ${error.message}',
        ));
    }
  }
}

extension WishlistToggle on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}
