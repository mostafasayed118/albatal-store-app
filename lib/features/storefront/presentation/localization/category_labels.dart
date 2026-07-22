import '../../../../generated/l10n/app_localizations.dart';

/// Maps wire/API category keys (English) to display labels.
///
/// Filtering and repository code keep using the English wire values
/// (`Silk`, `All`, …). Only UI call sites use this helper.
String localizedCategory(String wireKey, AppLocalizations l) {
  return switch (wireKey) {
    'All' => l.categoryAll,
    'Silk' => l.categorySilk,
    'Cotton' => l.categoryCotton,
    'Velvet' => l.categoryVelvet,
    'Linen' => l.categoryLinen,
    'Wool' => l.categoryWool,
    _ => wireKey,
  };
}
