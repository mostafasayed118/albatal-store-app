import '../../../../core/entities/order.dart';

/// Abstraction for orders persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
abstract interface class OrdersRepository {
  Future<List<Order>> readOrders();
  Future<void> writeOrders(List<Order> orders);
}
