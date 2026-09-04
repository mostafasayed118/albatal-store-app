import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the category-chip list: a leading 'All' selector is dropped,
/// real categories never are (live-found 2026-09-04: Wool vanished when
/// the loaded list had no 'All' first entry).
void main() {
  group('visibleCategoryChips', () {
    test('drops a leading All selector', () {
      expect(
        visibleCategoryChips(['All', 'Wool', 'Silk']),
        ['Wool', 'Silk'],
      );
    });

    test('keeps every category when no All entry exists', () {
      expect(
        visibleCategoryChips(['Wool', 'Silk', 'Cotton', 'Velvet', 'Linen']),
        ['Wool', 'Silk', 'Cotton', 'Velvet', 'Linen'],
      );
    });

    test('falls back to defaults when empty', () {
      expect(
        visibleCategoryChips([]),
        ['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'],
      );
    });

    test('falls back to defaults for a lone All', () {
      expect(
        visibleCategoryChips(['All']),
        ['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'],
      );
    });
  });
}
