import '../../../generated/l10n/app_localizations.dart';

/// The one place a fabric color name becomes shopper-visible copy.
///
/// Why this exists: `products.color_name` and the variant color sets are
/// DATA, not ARB keys — the filter sheet and the PDP variant chips used to
/// render them verbatim, so an Arabic session read English chips
/// ("Emerald", "Gold") inside fully localized chrome (audit 2026-09-21
/// M-03 / UX-031). Mirrors `catalogSortLabel`: one mapping, ARB-backed,
/// with unknown/new DB values passing through untranslated instead of
/// disappearing (the vocabulary is data-driven and can grow).
String catalogColorLabel(AppLocalizations l, String color) =>
    switch (color.trim().toLowerCase()) {
      'emerald' => l.colorEmerald,
      'gold' => l.colorGold,
      'ivory' => l.colorIvory,
      'purple' => l.colorPurple,
      'beige' => l.colorBeige,
      'brown' => l.colorBrown,
      'amber' => l.colorAmber,
      'teal' => l.colorTeal,
      'crimson' => l.colorCrimson,
      'sand' => l.colorSand,
      'other' => l.colorOther,
      _ => color,
    };
