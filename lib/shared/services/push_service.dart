import 'dart:async';

import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'env_config.dart';
import 'logger.dart';

/// Push port (feature-batch §12). Interface-wrapped like the other
/// batch services so consumers depend on the port, not OneSignal
/// (audit 2026-09-13).
abstract interface class PushService {
  /// Idempotent SDK init. Fail-silent; a no-op without a key.
  Future<void> init();
}

/// OneSignal push scaffold.
///
/// Deliberately a no-op unless `ONESIGNAL_APP_ID` is provided at build
/// time: an unconfigured key must never crash or spam the log. When the
/// key lands, `init()` registers the device; the `push-order-status`
/// edge-function proposal (supabase/functions/_proposals) sends the
/// server-side pushes on `update_order_status`.
final class OneSignalPushService implements PushService {
  const OneSignalPushService();

  @override
  Future<void> init() async {
    final appId = EnvConfig.onesignalAppId;
    if (appId.isEmpty) {
      Log.i('push disabled — no OneSignal app id', category: LogCategory.app);
      return;
    }
    try {
      await OneSignal.initialize(appId);
      // Notification permission is requested from Settings (§12), not
      // at startup — a cold permission prompt on first launch reads as
      // hostile in a shopping app.
    } on Exception catch (e, st) {
      Log.w('push init failed: $e');
      Log.d(st.toString());
    }
  }
}
