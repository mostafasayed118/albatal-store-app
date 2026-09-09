import '../../../core/entities/order.dart';
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
  Future<Result<List<Order>>> readOrders() =>
      Result.guard(() => _persistence.readOrders(), 'Failed to load orders');
}
