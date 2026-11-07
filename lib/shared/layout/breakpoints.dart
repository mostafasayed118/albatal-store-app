import 'package:flutter/widgets.dart';

/// Shared width thresholds (Material 3 window size classes, trimmed to the
/// three boundaries this app differentiates).
abstract final class Breakpoints {
  /// Phone portrait and below.
  static const double compactMax = 600;

  /// Large phone / tablet boundary. The navigation rail takes over here.
  static const double mediumMax = 840;

  /// Desktop content cap (matches `ResponsiveShell.maxContentWidth`).
  static const double expandedMax = 1200;
}

/// Current window width in logical pixels.
double windowWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

/// True when the window is wide enough for a navigation rail instead of the
/// bottom navigation bar.
bool usesNavigationRail(BuildContext context) =>
    windowWidth(context) >= Breakpoints.mediumMax;
