import 'package:flutter/material.dart';

import 'responsive_shell.dart';

/// Scaffold that caps its content width on tablets/desktop.
///
/// The surrounding area is painted with the scaffold background so a wide
/// window never shows a bare strip behind the centered 1200px column. The
/// app bar, body, FAB and bottom bar all live inside the cap.
final class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.maxWidth = ResponsiveShell.maxContentWidth,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final color = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    // Opaque only: this colour is painted behind the centered column and the
    // inner Scaffold repaints it inside the cap.
    return ColoredBox(
      color: color,
      child: ResponsiveShell(
        maxWidth: maxWidth,
        child: Scaffold(
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          backgroundColor: color,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        ),
      ),
    );
  }
}
