import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/flash_sale.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_state.dart';
import 'flash_sale_ticker.dart';

export '../../domain/entities/catalog_filters.dart'
    show
        CatalogFilters,
        CatalogSort,
        CatalogSortLabel,
        CatalogConstants,
        catalogColorName;

/// Re-exported for backward compatibility: every consumer (pages, tests)
/// historically imported [CatalogState]/[CatalogStatus] from this file.
export 'catalog_state.dart';


final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(CatalogState()) {
    // Countdown ticking lives in FlashSaleTicker (server-driven); the
    // legacy 1Hz saleSeconds timer was removed (audit P4) — nothing
    // consumed it and it rebuilt memo caches every second.
    _flashTicker = FlashSaleTicker(now: _now);
  }

  final CatalogRepository _repository;

  /// Injectable clock so the flash countdown is testable deterministically.
  final DateTime Function() _now;
  late final FlashSaleTicker _flashTicker;
  Timer? _queryDebounce;

  /// Countdown ticks (audit P3): 1Hz remaining values on a dedicated
  /// broadcast stream instead of `CatalogState` — ticks never change
  /// state equality, so no catalog listener ever rebuilds from them.
  final _flashCountdown = StreamController<Duration>.broadcast();

  /// Live flash-sale countdown; single-value events once per second.
  /// Emits the initial remaining value immediately on
  /// [startFlashSale], clamps at `Duration.zero`, and closes with the
  /// cubit. No widget reads the countdown today; the stream keeps the
  /// capability available without polluting state equality.
  Stream<Duration> get flashCountdown => _flashCountdown.stream;

  /// Widget-owned 60s flash poll moved here (audit Task 8a): the poll
  /// now survives page navigation and dies with the cubit, instead of
  /// being recreated/disposed on every HomePage mount. Interval and
  /// fire-and-forget semantics unchanged.
  Timer? _flashPollTimer;

  Future<void> load() async {
    emit(state.copyWith(status: CatalogStatus.loading));
    // Parallel fetch (audit residual P4): products and categories are
    // independent queries, so they run concurrently via Future.wait.
    // Error semantics unchanged: a products failure is terminal (error),
    // while a categories failure degrades to the ['All'] fallback.
    late final Result<List<Product>> productResult;
    late final Result<List<String>> categoryResult;
    await Future.wait([
      _repository.fetchProducts().then((r) => productResult = r),
      _repository.fetchCategories().then((r) => categoryResult = r),
    ]);
    productResult.when(
      success: (products) {
        final cats = categoryResult.when(
          success: (c) => c,
          failure: (_) => <String>['All'],
        );
        emit(state.copyWith(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: cats,
        ));
        // Integrate flash sales into initial load (T1). Fire-and-forget;
        // emissions are skipped when sales are empty to keep existing
        // load tests deterministic.
        // ignore: discarded_futures
        loadFlashSales();
      },
      failure: (_) => emit(state.copyWith(status: CatalogStatus.error)),
    );
  }

  /// Loads active flash sales from the repository and binds the countdown.
  ///
  /// Calls [_repository.getActiveFlashSales] and emits [state.flashSales].
  /// When the first sale carries an [FlashSale.endsAt], it drives
  /// [startFlashSale] so ticks flow on [flashCountdown]. When the sales
  /// list empties on a refresh, the ticker is cancelled (Task 11 gating)
  /// so it never ticks while [CatalogState.flashSales] is empty. Failures
  /// are swallowed so catalog loading never regresses to error due to a
  /// flash-sale fetch issue.
  ///
  /// Also owns the 60s refresh poll (moved from HomePage, audit Task 8a):
  /// [loadFlashSales] is the entry point both for the initial load and
  /// for the periodic tick, and [_flashPollTimer] starts on the first
  /// call and is cancelled in [close].
  Future<void> loadFlashSales() async {
    // Start the poll once — subsequent calls are refreshes driven by
    // the poll itself (or explicit retry paths) and must not stack
    // additional timers.
    _flashPollTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        // Fire-and-forget: a tick is a refresh, not a state machine
        // transition; loadFlashSales already guards empty/failed loads.
        // ignore: discarded_futures
        loadFlashSales();
      },
    );
    final result = await _repository.getActiveFlashSales();
    result.when(
      success: (sales) {
        if (sales.isEmpty && state.flashSales.isEmpty) return;
        emit(state.copyWith(flashSales: sales));
        if (sales.isNotEmpty) {
          final endsAt = sales.first.endsAt;
          if (endsAt != null) startFlashSale(end: endsAt);
        } else {
          // Ticker gating (audit Task 11): the sales list emptied on
          // refresh — stop the countdown so the 1Hz ticker stays silent
          // while flashSales is empty. The cubit owns ticker lifecycle
          // (see flash_sale_ticker.dart).
          _flashTicker.cancel();
        }
      },
      failure: (_) {
        // Swallow — flash sales are non-critical.
      },
    );
  }

  void select(String category) =>
      emit(state.copyWith(filters: state.filters.copyWith(category: category)));

  /// Live search with a 300ms debounce: each keystroke restarts the
  /// timer so typing runs one O(n log n) filter pass, not one per
  /// character. The text field itself is controller-driven, so display
  /// never lags. Recent queries are recorded in the same fire.
  void updateQuery(String query) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (isClosed) return;
      final trimmed = query.trim();
      final recents = trimmed.isEmpty
          ? state.recentQueries
          : [trimmed, ...state.recentQueries.where((r) => r != trimmed)]
              .take(5)
              .toList();
      emit(state.copyWith(
        filters: state.filters.copyWith(query: query),
        recentQueries: recents,
      ));
    });
  }

  void selectSort(CatalogSort sort) =>
      emit(state.copyWith(filters: state.filters.copyWith(sort: sort)));

  void setColorFilter(String color) {
    if (color == state.filters.colorFilter) {
      emit(state.copyWith(
          filters: state.filters.copyWith(clearColorFilter: true)));
    } else {
      emit(state.copyWith(filters: state.filters.copyWith(colorFilter: color)));
    }
  }

  void setPriceRange(Money min, Money max) => emit(state.copyWith(
      filters: state.filters.copyWith(priceMin: min, priceMax: max)));

  void clearFilters() {
    // A pending debounced query must not land after the reset.
    _queryDebounce?.cancel();
    emit(state.copyWith(filters: const CatalogFilters()));
  }

  void carousel(int index) => emit(state.copyWith(carouselIndex: index));

  /// Starts the flash-sale countdown ending at [end].
  ///
  /// Delegates ticking to [FlashSaleTicker]; remaining values stream on
  /// [flashCountdown] (audit P3 — state equality is never touched).
  void startFlashSale({required DateTime end}) {
    _flashTicker.start(end, onTick: _flashCountdown.add);
  }

  @override
  Future<void> close() {
    _flashTicker.cancel();
    _queryDebounce?.cancel();
    _flashPollTimer?.cancel();
    // ignore: discarded_futures
    _flashCountdown.close();
    return super.close();
  }

  void deleteRecentQuery(String q) {
    emit(state.copyWith(
        recentQueries: state.recentQueries.where((r) => r != q).toList()));
  }
}
