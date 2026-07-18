import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/storefront_persistence.dart';

enum WishlistStatus { initial, loading, ready, error }

final class WishlistState extends Equatable {
  const WishlistState({
    this.status = WishlistStatus.initial,
    this.ids = const {},
    this.errorMessage,
  });

  final WishlistStatus status;
  final Set<String> ids;
  final String? errorMessage;

  bool contains(String id) => ids.contains(id);

  WishlistState copyWith({
    WishlistStatus? status,
    Set<String>? ids,
    String? errorMessage,
  }) =>
      WishlistState(
        status: status ?? this.status,
        ids: ids ?? this.ids,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, ids, errorMessage];
}

final class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit(this._persistence) : super(const WishlistState());

  final StorefrontPersistence _persistence;

  Future<void> restore() async {
    emit(state.copyWith(status: WishlistStatus.loading));
    try {
      final restored = await _persistence.readWishlist();
      emit(WishlistState(ids: restored, status: WishlistStatus.ready));
    } catch (e) {
      emit(state.copyWith(
          status: WishlistStatus.error,
          errorMessage: 'Failed to load wishlist'));
    }
  }

  void toggle(String id) {
    final next = {...state.ids}..toggle(id);
    emit(WishlistState(ids: next, status: WishlistStatus.ready));
    _persistence.writeWishlist(next);
  }
}

extension WishlistToggle on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}
