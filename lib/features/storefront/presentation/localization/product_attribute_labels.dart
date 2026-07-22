import '../../../../core/entities/product.dart';
import '../../../../generated/l10n/app_localizations.dart';

/// Maps known English product attribute wire values to localized display text.
///
/// Unknown remote-catalog values fall back to the raw string so new catalog
/// entries still render without a schema change.
String localizedComposition(String? wire, AppLocalizations l) {
  if (wire == null || wire.isEmpty) return '';
  return switch (wire) {
    '100% Mulberry Silk' => l.compositionMulberrySilk,
    '100% Egyptian Giza Cotton' => l.compositionEgyptianGizaCotton,
    '85% Cotton, 15% Silk' => l.compositionCottonSilkBlend,
    '100% European Flax Linen' => l.compositionEuropeanFlaxLinen,
    '100% Merino Wool' => l.compositionMerinoWool,
    '100% Mulberry Silk Charmeuse' => l.compositionMulberrySilkCharmeuse,
    '100% Combed Cotton' => l.compositionCombedCotton,
    '70% Silk, 30% Viscose' => l.compositionSilkViscoseBlend,
    '100% Irish Linen' => l.compositionIrishLinen,
    _ => wire,
  };
}

String localizedCare(String? wire, AppLocalizations l) {
  if (wire == null || wire.isEmpty) return '';
  return switch (wire) {
    'Dry clean only. Cool iron on reverse. Store folded in breathable cotton.' =>
      l.careDryCleanSilk,
    'Machine wash cold, gentle cycle. Tumble dry low. Iron while slightly damp.' =>
      l.careMachineWashCotton,
    'Dry clean only. Steam to remove creases. Brush nap gently in one direction.' =>
      l.careDryCleanVelvet,
    'Machine wash cold. Hang dry. Embrace natural wrinkles or iron on high while damp.' =>
      l.careMachineWashLinen,
    'Dry clean preferred. Spot clean with cold water. Store with cedar to deter moths.' =>
      l.careDryCleanWool,
    'Dry clean only. Cool iron on reverse. Hang on padded hanger to prevent creasing.' =>
      l.careDryCleanSilkCharmeuse,
    'Machine wash warm. Tumble dry low. Iron on medium heat.' =>
      l.careMachineWashCombedCotton,
    'Dry clean only. Steam from a distance. Never press directly.' =>
      l.careDryCleanCrushedVelvet,
    'Machine wash cold. Line dry for best results. Iron while damp for crisp finish.' =>
      l.careMachineWashIrishLinen,
    _ => wire,
  };
}

String localizedOrigin(String? wire, AppLocalizations l) {
  if (wire == null || wire.isEmpty) return '';
  return switch (wire) {
    'Varanasi, India' => l.originVaranasiIndia,
    'Nile Delta, Egypt' => l.originNileDeltaEgypt,
    'Como, Italy' => l.originComoItaly,
    'Belgium' => l.originBelgium,
    'Yorkshire, England' => l.originYorkshireEngland,
    'Suzhou, China' => l.originSuzhouChina,
    'Izmir, Turkey' => l.originIzmirTurkey,
    'Bursa, Turkey' => l.originBursaTurkey,
    'Belfast, Northern Ireland' => l.originBelfastNorthernIreland,
    _ => wire,
  };
}

String localizedProductComposition(Product product, AppLocalizations l) =>
    localizedComposition(product.composition, l);

String localizedProductCare(Product product, AppLocalizations l) =>
    localizedCare(product.care, l);

String localizedProductOrigin(Product product, AppLocalizations l) =>
    localizedOrigin(product.origin, l);
