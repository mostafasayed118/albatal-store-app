import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/recently_viewed_store.dart';

final class RecentlyViewedState extends Equatable {
  const RecentlyViewedState({this.products = const []});

  final List<Product> products;

  @override
  List<Object?> get props => [products];
}

/// In-memory mirror of [RecentlyViewedStore] for the home strip.
class RecentlyViewedCubit extends Cubit<RecentlyViewedState> {
  RecentlyViewedCubit({required RecentlyViewedStore store})
      : _store = store,
        super(const RecentlyViewedState());

  final RecentlyViewedStore _store;

  void load() => emit(RecentlyViewedState(products: _store.load()));

  void record(Product product) {
    _store.record(product);
    emit(RecentlyViewedState(products: _store.load()));
  }

  void clear() {
    _store.clear();
    emit(const RecentlyViewedState());
  }
}
