import 'package:flutter/material.dart';

/// Stitch circular category chips — 72dp track, 56dp circles.
///
/// Stitch HTML uses horizontal pill chips; this maps to circular tactile
/// chips per Section 4 token map: active fill #B0F0D6 + stroke #064E3B,
/// inactive fill [ColorScheme.surfaceContainerHighest] + stroke
/// [ColorScheme.outlineVariant]. 56dp circle, 8dp gap, 4dp label gap,
/// InkSparkle via theme + [EdgeInsetsDirectional] for RTL.
class StitchCategoryChips extends StatelessWidget {
  const StitchCategoryChips({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.categories,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final List<String> categories;

  static const _activeFill = Color(0xFFB0F0D6);
  static const _activeStroke = Color(0xFF064E3B);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = cat == selected;
          return InkWell(
            onTap: () => onSelect(cat),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? _activeFill
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color:
                          isActive ? _activeStroke : scheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.texture,
                    color: isActive
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat,
                  style: textTheme.labelSmall?.copyWith(
                    color:
                        isActive ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
