import '../../../../core/entities/money.dart';

/// A product row as the admin catalog screens consume it.
///
/// Typed replacement for ad-hoc `Map<String, dynamic>` access in the
/// catalog management UI — the mapper owns every cast so a mistyped
/// payload degrades to a safe default instead of throwing in the
/// widget tree. Lives in the admin feature (not the shared core
/// [Product]) because the admin surfaces need management fields the
/// storefront model deliberately does not carry (`isActive`, management
/// product fields).
final class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryId,
    required this.categoryName,
    required this.basePrice,
    required this.isActive,
    this.description,
    this.composition,
    this.care,
    this.origin,
    this.widthCm,
    this.gsm,
    this.sellByLength = false,
    this.minCutMeters,
    this.colorName,
  });

  final String id;
  final String name;
  final String slug;
  final String categoryId;

  /// Display name from the joined `categories(name)` row.
  final String categoryName;

  /// Base price in integer minor units, matching the products table.
  final Money basePrice;
  final bool isActive;

  final String? description;
  final String? composition;
  final String? care;
  final String? origin;
  final int? widthCm;
  final int? gsm;
  final bool sellByLength;
  final double? minCutMeters;
  final String? colorName;

  /// Compact status chip for list rows.
  ///
  /// Data-layer convenience only — never rendered directly. Shopper-visible
  /// surfaces use the localized `active` / `inactive` ARB keys (see
  /// `admin_products_page.dart`, `admin_categories_page.dart`), mirroring
  /// the `adminOrderStatusLabel` rule that the domain layer must not own
  /// presentation copy (audit). Kept in English for logs/diagnostics and
  /// pinned by `admin_mappers_test.dart`.
  String get statusLabel => isActive ? 'Active' : 'Inactive';
}

/// A category row for the catalog management hub.
///
/// Read-only today (no admin write RPC exists yet) — the entity still
/// carries the management fields so a future create/edit surface does
/// not need a shape change.
final class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;
}
