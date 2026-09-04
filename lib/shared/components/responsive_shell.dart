import 'package:flutter/material.dart';

/// Centers content within a 1200px cap on wide screens.
///
/// Phones (<1200px logical) are unaffected. Without this, tablet/desktop
/// stretches catalog grids edge-to-edge and body lines past ~75 characters.
/// Apply around top-level scrollables (CustomScrollView, GridView, ListView).
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  /// Maximum content width — matches the DESIGN.md desktop breakpoint.
  static const double maxContentWidth = 1200;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
