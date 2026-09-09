import 'package:flutter/material.dart';

/// Single source of truth for catalog fallback data (audit P5).
///
/// Three previously-duplicated literals now live here:
/// - [defaults]: the category names used when the catalog provides none
///   (was inline in `visibleCategoryChips` and in
///   `SupabaseCatalogRepository.defaultCategories`);
/// - [categoryAccents]: the tactile mid-tone tint per fabric family
///   (was inline in `categoryAccent`);
/// - [curatedSwatches]: the fabric color-name → mid-tone dot table
///   (was the private `_curated` map in `color_swatches.dart`).
///
/// The old top-level names remain as `@Deprecated` aliases at their
/// original locations so existing tests keep compiling.
abstract final class CatalogConstants {
  /// Category names used whenever the catalog provides none.
  static const defaults = <String>[
    'Silk',
    'Cotton',
    'Velvet',
    'Linen',
    'Wool',
  ];

  /// A tactile mid-tone tint per fabric family, with a deterministic hue
  /// fallback for categories the catalog grows later.
  static const categoryAccents = <String, Color>{
    'Silk': Color(0xFFB08A2E),
    'Cotton': Color(0xFF7D8B6A),
    'Velvet': Color(0xFF6E1423),
    'Linen': Color(0xFFA9824F),
    'Wool': Color(0xFF4A5058),
    'Chiffon': Color(0xFF8A7FA8),
    'Satin': Color(0xFF8C5A6A),
    'Denim': Color(0xFF2F5A8C),
  };

  /// Fabric color-name → mid-tone fabric hue for the dots rendered on
  /// light chips. Curated so dots stay distinguishable and white icons
  /// keep contrast on the dark category tiles. Unknown names resolve
  /// through [deterministicTint] so any future name still gets a stable
  /// color.
  static const curatedSwatches = <String, Color>{
    'black': Color(0xFF23272E),
    'white': Color(0xFFC8CDD4), // rendered light grey so the dot is visible
    'grey': Color(0xFF70767E),
    'silver': Color(0xFF8E959D),
    'charcoal': Color(0xFF3E444C),
    'emerald': Color(0xFF0B7A4D),
    'green': Color(0xFF3E7D44),
    'sage': Color(0xFF7D9464),
    'mint': Color(0xFF3E9E8A),
    'seafoam': Color(0xFF4FAFA0),
    'teal': Color(0xFF1F7A74),
    'gold': Color(0xFFC9A227),
    'amber': Color(0xFFB07616),
    'champagne': Color(0xFFC6A876),
    'bronze': Color(0xFFA9763B),
    'camel': Color(0xFFB08950),
    'sand': Color(0xFFB89B6E),
    'ivory': Color(0xFFE0D3B6),
    'cream': Color(0xFFE7D9B2),
    'natural': Color(0xFFCDB98F),
    'purple': Color(0xFF6A3FA0),
    'navy': Color(0xFF283A63),
    'blue': Color(0xFF2F6FA3),
    'royal': Color(0xFF3146A6),
    'burgundy': Color(0xFF6E1423),
    'crimson': Color(0xFF9E1B32),
    'red': Color(0xFFB0303E),
    'rust': Color(0xFF9C4A1F),
    'terracotta': Color(0xFFBA5A2A),
    'rose': Color(0xFFB85C70),
    'pink': Color(0xFFC26F8A),
    'brown': Color(0xFF6E4A2E),
  };

  /// Resolves a fabric family to its accent tint.
  static Color accentFor(String category) =>
      categoryAccents[category] ?? deterministicTint(category);

  /// Categories shown as chips/grid: drops a leading 'All' selector when
  /// the catalog provides one, keeps everything otherwise.
  ///
  /// A blind `sublist(1)` dropped the Wool category on devices where the
  /// loaded list has no 'All' first entry (live-found 2026-09-04).
  static List<String> chipsFor(List<String> categories) {
    if (categories.isEmpty) return defaults;
    final chips =
        categories.first == 'All' ? categories.sublist(1) : categories;
    return chips.isEmpty ? defaults : chips;
  }

  /// Resolves a fabric color name to a visual [Color].
  ///
  /// Matching is case-insensitive and ignores surrounding whitespace.
  static Color swatchFor(String name) {
    final key = name.trim().toLowerCase();
    return curatedSwatches[key] ?? deterministicTint(key);
  }

  /// Stable, dependency-free FNV-1a hash so fallback colors never vary
  /// between platforms or across Dart versions (String.hashCode is not
  /// guaranteed stable).
  static int _fnv1a(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Deterministic mid-saturation hue derived from [seed] — used for
  /// unknown color names and for category-card tints that have no
  /// curated entry.
  static Color deterministicTint(String seed) {
    final hash = _fnv1a(seed.toLowerCase());
    final hue = (hash & 0xFF) / 0xFF * 360;
    return HSVColor.fromAHSV(1, hue, 0.4, 0.78).toColor();
  }
}
