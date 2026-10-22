import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo implements WishlistRepository {
  _Repo({this.ids = const {}, this.failWrites = false});

  Set<String> ids;
  bool failWrites;
  Set<String>? lastWritten;

  @override
  Future<Result<Set<String>>> readWishlist() async => Success({...ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    lastWritten = {...ids};
    return failWrites
        ? const Failure(AppError('secure store unavailable', code: 'save'))
        : const Success(null);
  }
}

final class _AlertStore implements BackInStockAlertStore {
  Set<String> watched = {};

  @override
  Set<String> get watchedProductIds => {...watched};

  @override
  bool isWatched(String productId) => watched.contains(productId);

  @override
  void setWatched(String productId, bool enabled) =>
      enabled ? watched.add(productId) : watched.remove(productId);
}

void main() {
  test('contains answers from the id set', () async {
    final cubit = WishlistCubit(_Repo(ids: {'a'}));
    addTearDown(cubit.close);
    await cubit.restore();

    expect(cubit.state.contains('a'), isTrue);
    expect(cubit.state.contains('b'), isFalse);
  });

  test('clearAll unwatches alerts and persists the empty set', () async {
    final repo = _Repo(ids: {'a', 'b'});
    final alerts = _AlertStore()..watched = {'a', 'b'};
    final cubit = WishlistCubit(repo, alertStore: alerts);
    addTearDown(cubit.close);
    await cubit.restore();
    expect(cubit.state.alertIds, {'a', 'b'});

    cubit.clearAll();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.ids, isEmpty);
    expect(cubit.state.status, WishlistStatus.ready);
    expect(alerts.watched, isEmpty);
    expect(repo.lastWritten, isEmpty);
  });

  test('a persist failure emits an error state without dropping the id',
      () async {
    final repo = _Repo(failWrites: true);
    final cubit = WishlistCubit(repo);
    addTearDown(cubit.close);
    await cubit.restore();

    cubit.toggle('a');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, WishlistStatus.error);
    expect(cubit.state.ids, contains('a'));
    expect(cubit.state.errorMessage, contains('Wishlist may not be saved'));
    expect(cubit.state.errorCode, 'save');
  });

  test('toggle adds then removes an id and persists both times', () async {
    final repo = _Repo();
    final cubit = WishlistCubit(repo);
    addTearDown(cubit.close);
    await cubit.restore();

    cubit.toggle('a');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.ids, contains('a'));
    expect(repo.lastWritten, {'a'});

    cubit.toggle('a');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.ids, isEmpty);
    expect(repo.lastWritten, isEmpty);
  });
}
