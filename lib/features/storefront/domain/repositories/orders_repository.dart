import '../../../../core/entities/order.dart';
import '../../../../core/error/result.dart';

/// Abstraction for orders persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
/// Returns [Result] so callers receive errors at this boundary.
abstract interface class OrdersRepository {
  Future<Result<List<Order>>> readOrders();
  Future<Result<void>> writeOrders(List<Order> orders);
}
