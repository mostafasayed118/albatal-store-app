import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/order.dart';
import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

enum ReorderStatus { idle, working, done }

final class ReorderState extends Equatable {
  const ReorderState({
    this.status = ReorderStatus.idle,
    this.addedCount = 0,
    this.skippedNames = const [],
  });

  final ReorderStatus status;
  final int addedCount;
  final List<String> skippedNames;

  @override
  List<Object?> get props => [status, addedCount, skippedNames];
}

/// Rebuilds a cart from a past order (feature-batch §6).
///
/// Every line is re-validated against the LIVE catalog before it is
/// re-added: products that disappeared and color/length combinations
/// that are out of stock are skipped and reported instead of failing
/// the whole reorder. Quantities clamp down to available stock.
class ReorderCubit extends Cubit<ReorderState> {
  ReorderCubit({
    required CatalogRepository catalog,
    required void Function(Product product,
            {String color, String length, int quantity})
        addToCart,
  })  : _catalog = catalog,
        _addToCart = addToCart,
        super(const ReorderState());

  final CatalogRepository _catalog;
  final void Function(Product product,
      {String color, String length, int quantity}) _addToCart;

  Future<void> reorder(Order order) async {
    if (order.items.isEmpty) return;
    emit(const ReorderState(status: ReorderStatus.working));

    var added = 0;
    final skipped = <String>[];
    for (final item in order.items) {
      final product = _catalog.findProductById(item.product.id);
      if (product == null) {
        skipped.add(item.product.name);
        continue;
      }
      final available = product.stockFor(item.color, item.length);
      if (available <= 0) {
        skipped.add(product.name);
        continue;
      }
      _addToCart(
        product,
        color: item.color,
        length: item.length,
        quantity: item.quantity.clamp(1, available),
      );
      added++;
    }

    emit(ReorderState(
      status: ReorderStatus.done,
      addedCount: added,
      skippedNames: List.unmodifiable(skipped),
    ));
  }

  void reset() => emit(const ReorderState());
}
