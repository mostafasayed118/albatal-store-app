import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/entities/admin_wholesale_price_entry.dart';
import '../../domain/repositories/admin_catalog_port.dart';
import '../../domain/repositories/admin_wholesale_prices_port.dart';

enum AdminWholesalePricesStatus { initial, loading, ready, error }

final class AdminWholesalePricesState extends Equatable {
  const AdminWholesalePricesState({
    this.status = AdminWholesalePricesStatus.initial,
    this.entries = const [],
    this.products = const [],
    this.errorMessage,
    this.errorCode,
  });

  final AdminWholesalePricesStatus status;

  /// Negotiated price rows (one per product, wholesale tier).
  final List<AdminWholesalePriceEntry> entries;

  /// Catalog candidates for the add/edit picker (bounded 100 like the
  /// admin catalog list).
  final List<AdminProduct> products;

  final String? errorMessage;

  /// App-authored failure code; drives localization at the render site.
  final String? errorCode;

  AdminWholesalePricesState copyWith({
    AdminWholesalePricesStatus? status,
    List<AdminWholesalePriceEntry>? entries,
    List<AdminProduct>? products,
    String? errorMessage,
    String? errorCode,
  }) =>
      AdminWholesalePricesState(
        status: status ?? this.status,
        entries: entries ?? this.entries,
        products: products ?? this.products,
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

  @override
  List<Object?> get props =>
      [status, entries, products, errorMessage, errorCode];
}

/// Wholesale price-list management for the admin hub (078 B2B).
class AdminWholesalePricesCubit extends Cubit<AdminWholesalePricesState> {
  AdminWholesalePricesCubit({
    required AdminWholesalePricesPort repository,
    required AdminCatalogPort catalogRepository,
  })  : _repository = repository,
        _catalogRepository = catalogRepository,
        super(const AdminWholesalePricesState());

  final AdminWholesalePricesPort _repository;
  final AdminCatalogPort _catalogRepository;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: AdminWholesalePricesStatus.loading));
    final results = await Future.wait([
      _repository.fetchWholesalePrices(),
      _catalogRepository.getAllProducts()
    ]);
    if (isClosed) return;
    final prices = results[0] as Result<List<AdminWholesalePriceEntry>>;
    final products = results[1] as Result<List<AdminProduct>>;
    switch ((prices, products)) {
      case (Success(value: final entries), Success(value: final catalog)):
        emit(state.copyWith(
            status: AdminWholesalePricesStatus.ready,
            entries: entries,
            products: catalog));
      case (Failure(:final error), _):
        emit(state.copyWith(
            status: AdminWholesalePricesStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
      case (_, Failure(:final error)):
        emit(state.copyWith(
            status: AdminWholesalePricesStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
    }
  }

  Future<void> upsertPrice({
    required String productId,
    required int priceMinor,
  }) async {
    final result = await _repository.upsertWholesalePrice(
        productId: productId, priceMinor: priceMinor);
    if (isClosed) return;
    switch (result) {
      case Success():
        await load();
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminWholesalePricesStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
    }
  }

  Future<void> deletePrice(String productId) async {
    final result = await _repository.deleteWholesalePrice(productId);
    if (isClosed) return;
    switch (result) {
      case Success():
        emit(state.copyWith(
            entries: state.entries
                .where((entry) => entry.productId != productId)
                .toList()));
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminWholesalePricesStatus.error,
            errorMessage: error.message,
            errorCode: error.code));
    }
  }
}
