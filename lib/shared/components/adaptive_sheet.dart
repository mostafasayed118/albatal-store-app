import 'package:flutter/material.dart';

/// Scroll-safe wrapper for modal bottom-sheet content.
///
/// Sheets open with `isScrollControlled: true`; without this wrapper a
/// `Column` overflows once the keyboard opens or the text scale grows, and
/// the submit action becomes unreachable. Also caps width on tablets and
/// keeps content clear of the system navigation bar.
final class AdaptiveSheet extends StatelessWidget {
  const AdaptiveSheet({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: viewInsets.bottom),
        child: Center(
          // Shrink-wrap short sheets; the scroll view caps tall ones.
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
