import '../../../core/entities/order.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/orders_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [OrdersRepository].
///
/// Catches errors at the boundary so the Cubit only sees [Result].
final class LocalOrdersRepository implements OrdersRepository {
  LocalOrdersRepository(this._persistence);
  final LocalStorefrontPersistence _persistence;

  @override
  Future<Result<List<Order>>> readOrders() async {
    try {
      return Success(await _persistence.readOrders());
    } catch (e) {
      return Failure(AppError('Failed to load orders', cause: e));
    }
  }

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async {
    try {
      await _persistence.writeOrders(orders);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save orders', cause: e));
    }
  }
}
