import 'package:flutter/material.dart';

/// Stitch circular category chips — 78dp track, 56dp circles.
///
/// Stitch HTML uses horizontal pill chips; this maps to circular tactile
/// chips per Section 4 token map: active fill primaryContainer + stroke
/// primary, inactive fill [ColorScheme.surfaceContainerHighest] + stroke
/// [ColorScheme.outlineVariant]. 56dp circle, 8dp gap, 4dp label gap,
/// InkSparkle via theme + [EdgeInsetsDirectional] for RTL.
/// The 78dp track fits the 12px labelSmall line (16px) under the circle
/// with 2px slack for font rounding.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Active state from the theme (primaryContainer + primary) so dark
    // mode stays legible — never hardcoded mint.
    final activeFill = scheme.primaryContainer;
    final activeStroke = scheme.primary;
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = cat == selected;
          return Semantics(
            button: true,
            selected: isActive,
            label: cat,
            child: InkWell(
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
                          ? activeFill
                          : scheme.surfaceContainerHighest,
                      border: Border.all(
                        color: isActive ? activeStroke : scheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.texture,
                      color: isActive
                          ? scheme.onPrimaryContainer
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
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
