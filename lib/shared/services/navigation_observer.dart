import 'package:flutter/material.dart';

import 'logger.dart';

/// Router observer that logs all navigation events.
class NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Log.nav('Push: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Log.nav('Pop: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    Log.nav(
        'Replace: ${oldRoute?.settings.name ?? ''} → ${newRoute?.settings.name ?? ''}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Log.nav('Remove: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Log.nav('Back gesture started');
  }
}
