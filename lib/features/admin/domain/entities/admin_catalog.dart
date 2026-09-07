/// A product row as the admin catalog screens consume it.
///
/// Typed replacement for ad-hoc `Map<String, dynamic>` access in the
/// catalog management UI — the mapper owns every cast so a mistyped
/// payload degrades to a safe default instead of throwing in the
/// widget tree. Lives in the admin feature (not the shared core
/// [Product]) because the admin surfaces need management fields the
/// storefront model deliberately does not carry (`isActive`, raw
/// `basePrice`).
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
  });

  final String id;
  final String name;
  final String slug;
  final String categoryId;

  /// Display name from the joined `categories(name)` row.
  final String categoryName;

  /// Base price in major EGP units, as the upsert RPC accepts it.
  final double basePrice;
  final bool isActive;

  final String? description;
  final String? composition;

  /// Compact status chip for list rows.
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
