import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';

/// Loads the category list for the product-edit dropdown.
///
/// Returns the admin list (ids + names, including inactive) — not the
/// storefront name list, which cannot satisfy the RPC's UUID contract —
/// plus the selected id after the keep-selectable merge:
///
/// * success: when the current selection vanished from the visible list
///   (e.g. deactivated), it is appended as an id-named entry instead of
///   silently rewriting the product's value on save; when nothing is
///   selected yet, the first category is pre-selected.
/// * failure (or throw): degraded mode — the current selection stands in
///   for its own name so an edit can still save. An empty list with no
///   selection stays empty (create mode with no categories to pick).
Future<({List<AdminCategory> categories, String? selectedId})>
    loadProductEditCategories({
  required AdminRepository repository,
  required String? selectedCategoryId,
}) async {
  try {
    final result = await repository.getAllCategories();
    return result.when(
      success: (categories) {
        var selected = selectedCategoryId;
        var merged = categories;
        final ids = categories.map((c) => c.id).toSet();
        if (selected != null && !ids.contains(selected)) {
          // The product's category vanished from the visible list
          // (e.g. deactivated): keep it selectable instead of
          // silently rewriting the product's value on save.
          merged = [
            ...merged,
            AdminCategory(id: selected, name: selected, isActive: true),
          ];
        } else if (selected == null && merged.isNotEmpty) {
          selected = merged.first.id;
        }
        return (categories: merged, selectedId: selected);
      },
      failure: (_) => (
        categories: _degraded(selectedCategoryId),
        selectedId: selectedCategoryId
      ),
    );
  } catch (e) {
    Log.w('Admin categories load failed.', error: e);
    return (
      categories: _degraded(selectedCategoryId),
      selectedId: selectedCategoryId
    );
  }
}

/// Degraded category list: the current selection stands in for its own
/// name so an edit can still save when the list cannot load.
List<AdminCategory> _degraded(String? selectedCategoryId) =>
    selectedCategoryId == null
        ? const []
        : [
            AdminCategory(
              id: selectedCategoryId,
              name: selectedCategoryId,
              isActive: true,
            ),
          ];

/// Single-row product fetch for the edit prefill (audit 2026-09-13).
///
/// Returns the product, or — when the row is missing or the fetch fails —
/// the failure details so the caller can surface them. Never throws: a
/// failed prefill must disable the form, not crash the route.
Future<
    ({
      AdminProduct? product,
      String? failureCode,
      String? failureMessage,
    })> fetchProductForEdit({
  required AdminRepository repository,
  required String productId,
}) async {
  final result = await repository.getProductById(productId);
  switch (result) {
    case Success(:final value):
      return (product: value, failureCode: null, failureMessage: null);
    case Failure(:final error):
      return (
        product: null,
        failureCode: error.code,
        failureMessage: error.message
      );
  }
}
