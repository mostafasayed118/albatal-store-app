import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Stitch search bar — rounded-full, surfaceContainerLow #F3F3F3.
///
/// Maps Stitch HTML `rounded-full` + `bg-[#f3f3f3]` to Flutter pill
/// container. Uses [EdgeInsetsDirectional] and keeps radii discipline:
/// pill is Stitch-exact `rounded-full` (outside 16/8/4 scale) documented
/// here, inner TextField border is none.
///
/// The mockup's voice-search mic is deliberately NOT rendered: it is a
/// dead affordance until voice search ships (the "coming soon" toast was
/// flagged as a release blocker), and the canonical design decision
/// (STATE.md 2026-09-06) is no mic until then. Restore it together with
/// real speech-to-text, not before.
///
/// Ownership: [controller] is borrowed, not owned — the caller (typically
/// the page State) creates and disposes it; this widget never disposes it.
class StitchSearchBar extends StatelessWidget {
  const StitchSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText,
    this.onSubmitted,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final EdgeInsetsGeometry padding;

  static const _fill = AppColors.surfaceContainerLow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerLow == AppColors.surface
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
            // Trailing inset mirrors the leading one so the placeholder
            // text optically centers in the pill without a trailing icon.
            // (The mockup's mic is intentionally not rendered — see class
            // doc: dead affordance until voice search ships.)
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
