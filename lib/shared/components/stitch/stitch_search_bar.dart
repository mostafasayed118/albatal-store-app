import 'package:flutter/material.dart';

import '../../extensions/build_context_x.dart';

/// Stitch search bar — rounded-full, surfaceContainerLow #F3F3F3, mic action.
///
/// Maps Stitch HTML `rounded-full` + `bg-[#f3f3f3]` to Flutter pill
/// container. Uses [EdgeInsetsDirectional], InkSparkle via [IconButton],
/// and keeps radii discipline: pill is Stitch-exact `rounded-full` (outside
/// 16/8/4 scale) documented here, inner TextField border is none.
class StitchSearchBar extends StatelessWidget {
  const StitchSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onMicTap,
    this.hintText,
    this.onSubmitted,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onMicTap;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final EdgeInsetsGeometry padding;

  static const _fill = Color(0xFFF3F3F3);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerLow == Colors.white
        ? _fill
        : scheme.surfaceContainerLow;
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          // Stitch `rounded-full` → pill. Intentional outside 16/8/4 scale;
          // see Section 4 token map (full = 9999px).
          borderRadius: BorderRadius.circular(999),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 12),
              child: Icon(Icons.search, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: hintText ?? 'Search fabrics, colors, textures…',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.voiceSearch,
              onPressed: onMicTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(context.l10n.comingSoon),
                      ),
                    );
                  },
              icon: const Icon(Icons.mic_none_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
