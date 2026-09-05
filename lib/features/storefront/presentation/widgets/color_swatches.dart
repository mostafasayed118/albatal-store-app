import 'package:flutter/material.dart';

/// Visual color swatches for fabric color names.
///
/// The `Product.colors` list currently carries names only (no per-variant
/// hex from the backend yet), so this map provides the fabric palette the
/// catalog fixtures actually use. Colors are curated mid-tone fabric hues
/// so dots stay distinguishable on light chips and white icons keep
/// contrast on the dark categories tiles. Unknown names resolve through
/// [deterministicTint] so any future name still gets a stable color.
const Map<String, Color> _curated = <String, Color>{
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

/// Stable, dependency-free FNV-1a hash so fallback colors never vary
/// between platforms or across Dart versions (String.hashCode is not
/// guaranteed stable).
int _fnv1a(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Deterministic mid-saturation hue derived from [seed] — used for unknown
/// color names and for category-card tints that have no curated entry.
Color deterministicTint(String seed) {
  final hash = _fnv1a(seed.toLowerCase());
  final hue = (hash & 0xFF) / 0xFF * 360;
  return HSVColor.fromAHSV(1, hue, 0.4, 0.78).toColor();
}

/// Resolves a fabric color name to a visual [Color].
///
/// Matching is case-insensitive and ignores surrounding whitespace.
Color swatchColorFor(String name) {
  final key = name.trim().toLowerCase();
  return _curated[key] ?? deterministicTint(key);
}

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
        color: swatchColorFor(name),
        // Thin neutral ring keeps pale fabrics (ivory/cream) visible on
        // white chips.
        border: Border.all(color: scheme.outlineVariant),
      ),
    );
  }
}
