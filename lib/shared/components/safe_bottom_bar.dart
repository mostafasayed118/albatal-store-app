import 'package:flutter/material.dart';

/// Bottom action bar that clears the system navigation bar.
///
/// Android 15/16 enforce edge-to-edge, so a bare surface `Container` puts the
/// CTA under the gesture bar. The surface colour is painted behind the inset
/// so the bar still reads as one continuous strip.
final class SafeBottomBar extends StatelessWidget {
  const SafeBottomBar({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsetsDirectional.all(16),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color ?? Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
