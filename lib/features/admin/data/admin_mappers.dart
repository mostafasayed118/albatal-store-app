import '../../../../core/entities/money.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/services/logger.dart';
import '../domain/entities/admin_catalog.dart';
import '../domain/entities/admin_order.dart';
import '../domain/entities/admin_sales.dart';
import '../domain/entities/admin_variant.dart';
import '../domain/entities/low_stock_variant.dart';
import 'admin_sales_mappers.dart';

/// Maps raw Supabase row/RPC payloads into typed admin domain entities.
///
/// Every cast lives here — the repository, cubit, and pages never touch
/// `Map<String, dynamic>`. Mapping is defensive: payload fields are read
/// with `is` type tests and helpers ([optString], [optInt]), never bare
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
    final orderItems = row['order_items'];
    final snapshot = row['address_snapshot'];
    return AdminOrder(
      // Repository filters id-less rows before calling; optString keeps a
      // single malformed row from throwing inside the widget tree.
      id: optString(row, 'id') ?? '',
      status: AdminOrderStatus.fromName(row['status']),
      total: Money(optInt(row, 'total') ?? 0),
      placedAt: placedAt ?? DateTime.now(),
      customerName: _nonBlank(_customerName(row)),
      customerId: _customerId(row),
      customerTier: _customerTier(row),
      paymentMethod: optString(row, 'payment_method'),
      itemCount:
          orderItems is List ? orderItems.length : items.length,
      items: items,
      trackingNumber: optString(row, 'payment_id'),
      address: snapshot is Map
          ? addressFromSnapshot(safeMap(snapshot))
          : null,
    );
  }

  /// Maps an order-detail row (`orders` + `order_items(*)` +
  /// `profiles(id, full_name, membership_tier)`) into a fully-populated
  /// [AdminOrder].
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
      productName: optString(row, 'product_name') ?? 'Unknown',
      size: optString(row, 'size') ?? '',
      color: optString(row, 'color') ?? '',
      quantity: optInt(row, 'quantity') ?? 0,
      unitPrice: Money(optInt(row, 'unit_price') ?? 0),
    );
  }

  /// Maps the `address_snapshot` jsonb column into an [AdminOrderAddress].
  static AdminOrderAddress? addressFromSnapshot(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) return null;
    final recipient = optString(snapshot, 'recipient') ?? '';
    final line = optString(snapshot, 'line') ?? '';
    final city = optString(snapshot, 'city') ?? '';
    if (recipient.isEmpty && line.isEmpty && city.isEmpty) return null;
    return AdminOrderAddress(
      recipient: recipient,
      line: line,
      city: city,
      country: optString(snapshot, 'country') ?? '',
    );
  }

  /// Maps one `get_low_stock_products` RPC row into a [LowStockVariant].
  /// Returns null for rows missing the variant id (cannot be updated).
  static LowStockVariant? lowStockVariantFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    return LowStockVariant(
      variantId: id,
      productName: optString(row, 'product_name') ?? 'Unknown',
      size: optString(row, 'variant_size') ?? '',
      color: optString(row, 'variant_color') ?? '',
      stock: optInt(row, 'current_stock') ?? 0,
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

  /// Maps one `product_variants` row into an [AdminVariant].
  /// Returns null for rows missing the variant id (cannot be edited).
  static AdminVariant? variantFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    final overrideMinor = optInt(row, 'price_override');
    return AdminVariant(
      variantId: id,
      size: optString(row, 'size') ?? '',
      color: optString(row, 'color') ?? '',
      stock: optInt(row, 'stock') ?? 0,
      priceOverride: overrideMinor != null && overrideMinor > 0
          ? Money(overrideMinor)
          : null,
    );
  }

  /// Maps a list of variant rows, skipping unmappable entries.
  static List<AdminVariant> variantsFromRows(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .map(variantFromRow)
      .whereType<AdminVariant>()
      .toList();

  /// Extracts non-blank `storage_path` strings from `product_images` rows.
  /// Blank or mistyped paths are skipped — they render nothing useful.
  static List<String> imagePathsFromRows(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .map((row) => optString(row, 'storage_path'))
      .whereType<String>()
      .where((path) => path.trim().isNotEmpty)
      .toList();

  /// Maps one `products` row (with joined `categories(name)`) into an
  /// [AdminProduct].
  ///
  /// Precondition: `row['id']` is a non-null String (the repository
  /// filters id-less rows before calling this, same contract as the
  /// order queue). The admin catalog list must show inactive products
  /// too — they are exactly what needs un-hiding — so unlike the
  /// storefront list there is no active-only filter upstream.
  static AdminProduct productFromRow(Map<String, dynamic> row) {
    final category = row['categories'];
    final basePriceMinor = optInt(row, 'base_price');
    final id = optString(row, 'id') ?? '';
    // Fail-closed money boundary (audit Top-5 #4): a missing/non-positive
    // price is corrupt data, not a free product — render zero but log so
    // the catalog team sees it. Absurd values (>999M minor ≈ 9.99M EGP)
    // are clamped to zero for the same reason; the server (068/073)
    // rejects them on write.
    Money basePrice;
    if (basePriceMinor == null || basePriceMinor <= 0) {
      if (basePriceMinor != null) {
        Log.w('admin product $id has non-positive base_price $basePriceMinor');
      }
      basePrice = Money.zero;
    } else if (basePriceMinor > 999999999) {
      Log.w('admin product $id base_price $basePriceMinor exceeds cap');
      basePrice = Money.zero;
    } else {
      basePrice = Money(basePriceMinor);
    }
    return AdminProduct(
      id: id,
      name: optString(row, 'name') ?? '',
      slug: optString(row, 'slug') ?? '',
      categoryId: optString(row, 'category_id') ?? '',
      categoryName: category is Map ? optString(category, 'name') ?? '' : '',
      basePrice: basePrice,
      isActive: safeBool(row, 'is_active'),
      description: optString(row, 'description'),
      composition: optString(row, 'composition'),
      care: optString(row, 'care'),
      origin: optString(row, 'origin'),
      widthCm: optInt(row, 'width_cm'),
      gsm: optInt(row, 'gsm'),
      sellByLength: safeBool(row, 'sell_by_length'),
      minCutMeters: optDouble(row, 'min_cut_meters'),
      colorName: optString(row, 'color_name'),
    );
  }

  /// Maps a list of product rows, skipping id-less entries.
  static List<AdminProduct> productsFromRows(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .where((row) {
        final id = optString(row, 'id');
        return id != null && id.isNotEmpty;
      })
      .map(productFromRow)
      .toList();

  /// Maps one `categories` row into an [AdminCategory].
  ///
  /// Same id precondition as [productFromRow].
  static AdminCategory categoryFromRow(Map<String, dynamic> row) {
    return AdminCategory(
      id: optString(row, 'id') ?? '',
      name: optString(row, 'name') ?? '',
      isActive: safeBool(row, 'is_active'),
    );
  }

  /// Maps a list of category rows, skipping id-less entries.
  static List<AdminCategory> categoriesFromRows(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .where((row) {
        final id = optString(row, 'id');
        return id != null && id.isNotEmpty;
      })
      .map(categoryFromRow)
      .toList();

  /// Aggregates a windowed `orders` read into an [AdminSalesOverview].
  ///
  /// Forwards to [AdminSalesMappers.salesOverviewFromRows] (same contract,
  /// same tests) — see that method for the aggregation rules.
  static AdminSalesOverview salesOverviewFromRows(
    List<dynamic> rows, {
    required int days,
    required DateTime now,
  }) =>
      AdminSalesMappers.salesOverviewFromRows(rows, days: days, now: now);

  /// Customer display name: joined `profiles.full_name`, falling back to
  /// a denormalized `customer_name` column; mistyped values are ignored.
  static String? _customerName(Map<String, dynamic> row) {
    final profiles = row['profiles'];
    final fromJoin = profiles is Map ? optString(profiles, 'full_name') : null;
    return fromJoin ?? optString(row, 'customer_name');
  }

  /// Customer profile id from the joined `profiles` row. The queue query
  /// doesn't select it; the detail query does, and the tier control needs
  /// it to address the admin RPC.
  static String? _customerId(Map<String, dynamic> row) {
    final profiles = row['profiles'];
    final id = profiles is Map ? optString(profiles, 'id') : null;
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Membership tier of the joined profile. Only 'premium' is treated as
  /// meaningful: anything else (null, 'standard', unknown value) reads as
  /// standard, matching [Profile]'s tolerant decoding.
  static String _customerTier(Map<String, dynamic> row) {
    final profiles = row['profiles'];
    final raw = profiles is Map ? optString(profiles, 'membership_tier') : null;
    return raw == 'premium' ? 'premium' : 'standard';
  }

  static String? _nonBlank(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;
}
