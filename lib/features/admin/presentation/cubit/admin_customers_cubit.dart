import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/utils/app_durations.dart';
import '../../domain/entities/admin_customer.dart';
import '../../domain/repositories/admin_customers_port.dart';

enum AdminCustomersStatus { initial, loading, ready, error }

final class AdminCustomersState extends Equatable {
  const AdminCustomersState({
    this.status = AdminCustomersStatus.initial,
    this.customers = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.errorCode,
    this.tierError,
    this.tierErrorCode,
  });

  final AdminCustomersStatus status;

  /// Rows loaded so far for the active search, newest first.
  ///
  /// Since the search runs on the server this *is* the view — there is no
  /// second client-side filtered copy to drift out of sync with it.
  final List<AdminCustomer> customers;

  /// How many rows the server holds for the active search. This is what makes
  /// the read bound visible instead of silent.
  final int total;

  /// True while [total] exceeds what has been loaded, so the page can offer
  /// the next page.
  final bool hasMore;

  /// A [AdminCustomersCubit.loadMore] request is in flight. Deliberately not
  /// [status]: replacing the list with a full-screen spinner mid-page would
  /// throw away what the admin is already reading.
  final bool isLoadingMore;

  /// Failure of a *read* (the initial load, a search, or a page load). The
  /// page renders it as its error state, whose retry re-runs the active
  /// search.
  final String? errorMessage;

  /// App-authored failure code for [errorMessage].
  final String? errorCode;

  /// Failure from a tier *write*, kept off [status] deliberately: this page
  /// renders a whole-screen error view for [AdminCustomersStatus.error], so
  /// reusing it would erase the loaded directory whenever a write bounced.
  /// The page surfaces this as a floating message and clears it.
  final String? tierError;

  /// App-authored failure code for [tierError].
  final String? tierErrorCode;

  AdminCustomersState copyWith({
    AdminCustomersStatus? status,
    List<AdminCustomer>? customers,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    String? errorCode,
    String? tierError,
    String? tierErrorCode,
    bool clearTierError = false,
  }) =>
      AdminCustomersState(
        status: status ?? this.status,
        customers: customers ?? this.customers,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        errorMessage: errorMessage,
        errorCode: errorCode,
        // Same sentinel convention as AdminState.copyWith(clearSelectedOrder).
        tierError: clearTierError ? null : (tierError ?? this.tierError),
        tierErrorCode:
            clearTierError ? null : (tierErrorCode ?? this.tierErrorCode),
      );

  @override
  List<Object?> get props => [
        status,
        customers,
        total,
        hasMore,
        isLoadingMore,
        errorMessage,
        errorCode,
        tierError,
        tierErrorCode,
      ];
}

/// Customer directory for the admin hub (feature-batch §14). The page
/// renders this cubit instead of calling the repository from its State
/// (audit 2026-09-13).
///
/// The directory is **paged by keyset cursor**, and the search is
/// **server-side**: a filtered read covers the whole `profiles` table rather
/// than only the pages already loaded. Both exist because of the same defect —
/// the directory used to be a single `.limit(500)` that silently hid the 501st
/// customer, with a client-side filter that could therefore only ever see the
/// same 500.
///
/// Paging is positional by the last row's `(createdAt, id)` rather than by an
/// offset, so a customer signing up mid-scroll cannot make the next page
/// repeat a row or step over one (see [_cursor]).
class AdminCustomersCubit extends Cubit<AdminCustomersState> {
  AdminCustomersCubit({
    required AdminCustomersPort repository,
    this.pageSize = defaultCustomersPageSize,
    this.searchDebounce = AppDurations.searchDebounce,
  })  : _repository = repository,
        super(const AdminCustomersState());

  final AdminCustomersPort _repository;

  /// Rows requested per page. Injectable so tests can drive paging with a
  /// handful of fixtures instead of fifty.
  final int pageSize;

  /// Injectable for the same reason CatalogCubit takes a clock seam: tests
  /// must not have to wait out a real debounce.
  final Duration searchDebounce;

  /// Active search term, already trimmed and sent to the server.
  String _query = '';

  /// Bookmark for the next page: the `(createdAt, id)` of the last row the
  /// server returned for the active search, or null before the first page.
  ///
  /// Deliberately a position *value* rather than an offset derived from
  /// `state.customers.length`. A count is wrong at both ends of the same
  /// problem: the repository drops undecodable rows (so the loaded count is
  /// short of what the server consumed), and a customer who signs up while an
  /// admin is scrolling shifts every later row down by one, so the next offset
  /// steps over a row that was never shown. A cursor cannot do either.
  CustomerCursor? _cursor;

  /// Bumped whenever the result set is replaced (initial load or a new
  /// search). A page load is applied only if the generation still matches, so
  /// a slow response can never append rows belonging to a superseded query —
  /// overlapping requests are normal once search is live.
  int _generation = 0;

  Timer? _searchDebounceTimer;

  /// Loads the first page of the active search.
  Future<void> load() => _loadFirstPage(withSpinner: true);

  /// Live search with the same 300ms debounce CatalogCubit uses: each
  /// keystroke restarts the timer, so typing runs one query instead of one
  /// per character. The text field is controller-driven, so display never
  /// lags.
  ///
  /// The list currently on screen is left alone until the new results land —
  /// blanking it would tear down the page that owns the focused field.
  void search(String query) {
    _query = query.trim();
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      searchDebounce,
      () => unawaited(_loadFirstPage(withSpinner: false)),
    );
  }

  /// Appends the next page. A no-op when nothing more is known or a page is
  /// already in flight, so a double tap cannot fetch the same page twice.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _repository.fetchCustomers(
      query: _query.isEmpty ? null : _query,
      cursor: _cursor,
      limit: pageSize,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        _cursor = value.nextCursor;
        // `total` is deliberately NOT taken from this response. A cursor
        // narrows the filter the exact count is taken over, so a continuation
        // page can only ever report the rows *remaining*; the first page's
        // count is the one the "showing X of Y" line means. Ignoring it here
        // (rather than trusting the repository to leave it null) makes that
        // invariant structural: no continuation page can move the number.
        emit(state.copyWith(
          status: AdminCustomersStatus.ready,
          customers: [...state.customers, ...value.customers],
          hasMore: value.nextCursor != null,
          isLoadingMore: false,
        ));
      case Failure(:final error):
        // A failed page load keeps the failure model consistent with the
        // initial load: the page shows the error (with a retry that re-runs
        // the active search) rather than pretending the queue is shorter.
        emit(state.copyWith(
          status: AdminCustomersStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
          isLoadingMore: false,
        ));
    }
  }

  Future<void> _loadFirstPage({required bool withSpinner}) async {
    final generation = ++_generation;
    if (withSpinner) {
      emit(state.copyWith(
        status: AdminCustomersStatus.loading,
        isLoadingMore: false,
      ));
    }
    final result = await _repository.fetchCustomers(
      query: _query.isEmpty ? null : _query,
      limit: pageSize,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        _cursor = value.nextCursor;
        emit(state.copyWith(
          status: AdminCustomersStatus.ready,
          customers: value.customers,
          // A first page always carries the exact total; the fallback only
          // exists so a compliant repository cannot silently blank the line.
          total: value.total ?? 0,
          hasMore: value.nextCursor != null,
          isLoadingMore: false,
        ));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminCustomersStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
          isLoadingMore: false,
        ));
    }
  }

  /// Set a customer's membership tier via the admin-gated RPC (migration
  /// 046). On success the directory row reflects the new tier immediately —
  /// the repository confirmed the write before this emits, so the page can
  /// verify its ack against state like every other admin transition.
  ///
  /// A failure never touches [AdminCustomersState.status] (see
  /// [AdminCustomersState.tierError]); it must not erase the directory.
  Future<void> setMembershipTier(String profileId, String tier) async {
    final result = await _repository.setMembershipTier(profileId, tier);
    if (isClosed) return;
    switch (result) {
      case Success():
        final updated = state.customers
            .map((c) => c.id == profileId ? c.copyWith(tier: tier) : c)
            .toList();
        emit(state.copyWith(customers: updated));
      case Failure(:final error):
        emit(state.copyWith(
          tierError: error.message,
          tierErrorCode: error.code,
        ));
    }
  }

  /// Dismiss the tier-write error once the page has surfaced it.
  void clearTierError() => emit(state.copyWith(clearTierError: true));

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}
