import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/push_service.dart';
import '../services/service_locator.dart';

/// Debug-only OneSignal integration verifier.
///
/// The OneSignal Flutter integration guide requires a one-time dialog once
/// the device receives a real (server-assigned) subscription id. The copy is
/// developer-facing, so it is intentionally limited to debug builds; the
/// production opt-in remains Settings -> order notifications.
final class PushVerificationListener extends StatefulWidget {
  const PushVerificationListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.pushService,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Test seam; production resolves the registered service.
  final PushService? pushService;

  @override
  State<PushVerificationListener> createState() =>
      _PushVerificationListenerState();
}

final class _PushVerificationListenerState
    extends State<PushVerificationListener> {
  PushService? _push;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) return;
    _push = widget.pushService ??
        (getIt.isRegistered<PushService>() ? getIt<PushService>() : null);
    final push = _push;
    if (push == null) return;
    unawaited(_attach(push));
  }

  Future<void> _attach(PushService push) async {
    await push.addSubscriptionObserver(_onSubscription);
    if (!mounted) {
      push.removeSubscriptionObserver(_onSubscription);
      return;
    }
    // The id may already be server-assigned before the observer attaches.
    _maybeShow(push.subscriptionId);
  }

  void _onSubscription(String? id) => _maybeShow(id);

  void _maybeShow(String? id) {
    if (!mounted || _shown) return;
    if (id == null || id.isEmpty || id.startsWith('local-')) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDialog());
  }

  Future<void> _showDialog() async {
    if (!mounted) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your OneSignal SDK integration is complete!'),
        content: const Text(
          'You can now send Push Notifications & In-App Messages through '
          'OneSignal. Tap below to enable push notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final push = _push;
              if (push != null) unawaited(push.requestPermission());
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _push?.removeSubscriptionObserver(_onSubscription);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
