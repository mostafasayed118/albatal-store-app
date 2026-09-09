import 'package:flutter/material.dart';

import '../catalog_constants.dart';

/// Visual color swatches for fabric color names.
///
/// The `Product.colors` list currently carries names only (no per-variant
/// hex from the backend yet). The canonical palette now lives on
/// [CatalogConstants.curatedSwatches]; the helpers below remain as
/// deprecated aliases so existing tests keep compiling.
@Deprecated('Use CatalogConstants.deterministicTint instead.')
Color deterministicTint(String seed) =>
    CatalogConstants.deterministicTint(seed);

@Deprecated('Use CatalogConstants.swatchFor instead.')
Color swatchColorFor(String name) => CatalogConstants.swatchFor(name);

/// Small circular fabric-color dot used inside color ChoiceChips.
class ColorSwatchDot extends StatelessWidget {
  const ColorSwatchDot({super.key, required this.name, this.size = 20});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CatalogConstants.swatchFor(name),
        // Thin neutral ring keeps pale fabrics (ivory/cream) visible on
        // white chips.
        border: Border.all(color: scheme.outlineVariant),
      ),
    );
  }
}
