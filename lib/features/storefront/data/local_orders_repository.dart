import '../../../core/entities/order.dart';
import '../domain/repositories/orders_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [OrdersRepository].
final class LocalOrdersRepository implements OrdersRepository {
  LocalOrdersRepository(this._persistence);
  final StorefrontPersistence _persistence;

  @override
  Future<List<Order>> readOrders() => _persistence.readOrders();

  @override
  Future<void> writeOrders(List<Order> orders) =>
      _persistence.writeOrders(orders);
}
