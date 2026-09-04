import '../../../../core/entities/money.dart';
import '../domain/entities/admin_order.dart';
import '../domain/entities/low_stock_variant.dart';

/// Maps raw Supabase row/RPC payloads into typed admin domain entities.
///
/// Every cast lives here — the repository, cubit, and pages never touch
/// `Map<String, dynamic>`. Mapping is defensive: payload fields are read
/// with `is` type tests and helpers ([_asString], [_toInt]), never bare
/// `as` casts — a wrong runtime type (e.g. a string in a numeric column)
/// must degrade to a safe default, not throw inside the widget tree.
class AdminMappers {
  AdminMappers._();

  /// Maps a queue row (`orders` + joined `profiles(full_name)` +
  /// `order_items(id)` array, or the same shape from the detail query).
  ///
  /// Precondition: `row['id']` is a non-null String (the repository
  /// filters id-less rows before calling this).
  static AdminOrder orderFromRow(
    Map<String, dynamic> row, {
    List<AdminOrderItem> items = const [],
  }) {
    final placedRaw = row['placed_at'];
    final placedAt = placedRaw is String ? DateTime.tryParse(placedRaw) : null;
    return AdminOrder(
      id: row['id'] as String,
      status: AdminOrderStatus.fromName(row['status']),
      total: Money(_toInt(row['total'])),
      placedAt: placedAt ?? DateTime.now(),
      customerName: _nonBlank(_customerName(row)),
      paymentMethod: _asString(row['payment_method']),
      itemCount: row['order_items'] is List
          ? (row['order_items'] as List).length
          : items.length,
      items: items,
      trackingNumber: _asString(row['tracking_number']),
      address: row['address_snapshot'] is Map
          ? addressFromSnapshot(
              (row['address_snapshot'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  /// Maps an order-detail row (`orders` + `order_items(*)` +
  /// `profiles(full_name)`) into a fully-populated [AdminOrder].
  static AdminOrder orderDetailFromRow(Map<String, dynamic> row) {
    final itemsRaw = row['order_items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((m) => orderItemFromRow(m.cast<String, dynamic>()))
            .toList()
        : const <AdminOrderItem>[];
    return orderFromRow(row, items: items);
  }

  /// Maps one `order_items(*)` row into an [AdminOrderItem].
  static AdminOrderItem orderItemFromRow(Map<String, dynamic> row) {
    return AdminOrderItem(
      productName: _asString(row['product_name']) ?? 'Unknown',
      size: _asString(row['size']) ?? '',
      color: _asString(row['color']) ?? '',
      quantity: _toInt(row['quantity']),
      unitPrice: Money(_toInt(row['unit_price'])),
    );
  }

  /// Maps the `address_snapshot` jsonb column into an [AdminOrderAddress].
  static AdminOrderAddress? addressFromSnapshot(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) return null;
    final recipient = _asString(snapshot['recipient']) ?? '';
    final line = _asString(snapshot['line']) ?? '';
    final city = _asString(snapshot['city']) ?? '';
    if (recipient.isEmpty && line.isEmpty && city.isEmpty) return null;
    return AdminOrderAddress(
      recipient: recipient,
      line: line,
      city: city,
      country: _asString(snapshot['country']) ?? '',
    );
  }

  /// Maps one `get_low_stock_products` RPC row into a [LowStockVariant].
  /// Returns null for rows missing the variant id (cannot be updated).
  static LowStockVariant? lowStockVariantFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    return LowStockVariant(
      variantId: id,
      productName: _asString(row['product_name']) ?? 'Unknown',
      size: _asString(row['variant_size']) ?? '',
      color: _asString(row['variant_color']) ?? '',
      stock: _toInt(row['current_stock']),
    );
  }

  /// Maps a list of low-stock rows, skipping unmappable entries.
  static List<LowStockVariant> lowStockVariantsFromRows(
    List<dynamic> rows,
  ) =>
      rows
          .whereType<Map<String, dynamic>>()
          .map(lowStockVariantFromRow)
          .whereType<LowStockVariant>()
          .toList();

  /// Customer display name: joined `profiles.full_name`, falling back to
  /// a denormalized `customer_name` column; mistyped values are ignored.
  static String? _customerName(Map<String, dynamic> row) {
    final profiles = row['profiles'];
    final fromJoin =
        profiles is Map ? _asString(profiles['full_name']) : null;
    return fromJoin ?? _asString(row['customer_name']);
  }

  static String? _asString(Object? value) => value is String ? value : null;

  static int _toInt(Object? value) => value is num ? value.toInt() : 0;

  static String? _nonBlank(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;
}
