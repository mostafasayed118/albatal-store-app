import '../../../generated/l10n/app_localizations.dart';
import '../domain/entities/catalog_filters.dart';

/// The one place a fabric weight/width band becomes shopper-visible copy.
///
/// Mirrors `catalogColorLabel`: one mapping, ARB-backed. Fabric keywords
/// (cotton, linen, …) stay in source spelling like category names do —
/// data-driven vocabulary, documented in `FilterSheet`.
String fabricWeightLabel(AppLocalizations l, FabricWeight weight) =>
    switch (weight) {
      FabricWeight.any => l.filterAny,
      FabricWeight.light => l.weightLight,
      FabricWeight.medium => l.weightMedium,
      FabricWeight.heavy => l.weightHeavy,
      FabricWeight.unspecified => l.filterAny,
    };

/// Width band label. `unspecified` never reaches the sheet (it means
/// "unknown data", not a shopper choice) and falls back to "Any".
String fabricWidthLabel(AppLocalizations l, FabricWidth width) =>
    switch (width) {
      FabricWidth.any => l.filterAny,
      FabricWidth.narrow => l.widthNarrow,
      FabricWidth.standard => l.widthStandard,
      FabricWidth.wide => l.widthWide,
      FabricWidth.unspecified => l.filterAny,
    };
