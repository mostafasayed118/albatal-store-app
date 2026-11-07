import 'package:flutter/material.dart';

/// Centers content within a 1200px cap on wide screens.
///
/// Phones (<1200px logical) are unaffected. Without this, tablet/desktop
/// stretches catalog grids edge-to-edge and body lines past ~75 characters.
/// Apply around top-level scrollables (CustomScrollView, GridView, ListView).
final class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth = maxContentWidth,
    this.padding,
  });

  /// Maximum content width — matches the DESIGN.md desktop breakpoint.
  static const double maxContentWidth = 1200;

  final Widget child;

  /// Optional tighter cap for text-heavy screens (e.g. checkout).
  final double maxWidth;

  /// Optional inner padding applied inside the cap.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
