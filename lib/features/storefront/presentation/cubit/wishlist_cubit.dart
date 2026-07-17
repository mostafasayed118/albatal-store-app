import 'package:bloc/bloc.dart';

import '../../data/storefront_persistence.dart';

final class WishlistCubit extends Cubit<Set<String>> {
  WishlistCubit(this._persistence) : super(<String>{});

  final StorefrontPersistence _persistence;

  Future<void> restore() async => emit(await _persistence.readWishlist());

  void toggle(String id) {
    final next = {...state}..toggle(id);
    emit(next);
    _persistence.writeWishlist(next);
  }
}

extension WishlistToggle on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}
