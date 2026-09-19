import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Stitch card surface: `surface` fill, 1dp `outlineVariant` border and
/// the 16dp [AppTheme.cardRadius].
///
/// Twelve call sites across ten files hand-rolled that decoration, and four of
/// them wrote `BorderRadius.circular(16)` instead of the token — the same
/// value, so nothing failed when the design grid and the token could drift
/// apart. The decoration now has exactly one definition.
///
/// Defaults mirror [Card]'s, so adopting this widget does not change a call
/// site's rendering: `clipBehavior`, `margin`, padding and `elevation` stay
/// per-site concerns. Pass [Clip.antiAlias] where an [InkWell] sits on the card
/// and its ripple has to respect the radius.
final class AppCard extends StatelessWidget {
  const AppCard(
      {super.key, required this.child, this.clipBehavior = Clip.none});

  final Widget child;

  /// Defaults to [Clip.none] — [Card]'s own default.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surface,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      child: child,
    );
  }
}
