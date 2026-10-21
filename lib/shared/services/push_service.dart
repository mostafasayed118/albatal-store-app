import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'env_config.dart';
import 'logger.dart';

/// Push port (feature-batch §12). Interface-wrapped like the other
/// batch services so consumers depend on the port, not OneSignal
/// (audit 2026-09-13).
abstract interface class PushService {
  /// Idempotent SDK init. Fail-silent; a no-op without a key.
  Future<void> init();

  /// Links the app user id as OneSignal's `external_id` so the server
  /// can target `include_external_user_ids`. Fail-silent.
  Future<void> login(String userId);

  /// Unlinks the external id on sign-out. Fail-silent.
  Future<void> logout();

  /// Requests OS push permission. Call only from a user-initiated action.
  Future<void> requestPermission();

  /// Server-assigned push subscription id, or null before registration.
  String? get subscriptionId;

  /// Registers a listener for subscription-id changes. The caller must
  /// retain [listener] and pass the same reference to
  /// [removeSubscriptionObserver].
  Future<void> addSubscriptionObserver(void Function(String? id) listener);

  /// Removes a previously registered subscription listener.
  void removeSubscriptionObserver(void Function(String? id) listener);
}

/// Seam over the static OneSignal entry points so the service is
/// unit-testable without the plugin.
abstract interface class PushSdk {
  Future<void> initialize(String appId);
  Future<void> login(String externalId);
  Future<void> logout();
  Future<bool> requestPermission();
  String? get subscriptionId;
  void addSubscriptionObserver(void Function(String? id) listener);
  void removeSubscriptionObserver(void Function(String? id) listener);
}

final class OneSignalSdk implements PushSdk {
  OneSignalSdk();

  /// Maps our listener to the SDK observer so removal uses the exact
  /// same function object the SDK stored.
  final Map<void Function(String?), OnPushSubscriptionChangeObserver>
      _observers = {};

  @override
  Future<void> initialize(String appId) {
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }
    return OneSignal.initialize(appId);
  }

  @override
  Future<void> login(String externalId) => OneSignal.login(externalId);

  @override
  Future<void> logout() => OneSignal.logout();

  @override
  Future<bool> requestPermission() =>
      OneSignal.Notifications.requestPermission(true);

  @override
  String? get subscriptionId => OneSignal.User.pushSubscription.id;

  @override
  void addSubscriptionObserver(void Function(String? id) listener) {
    void observer(OSPushSubscriptionChangedState state) =>
        listener(state.current.id);
    _observers[listener] = observer;
    OneSignal.User.pushSubscription.addObserver(observer);
  }

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) {
    final observer = _observers.remove(listener);
    if (observer != null) {
      OneSignal.User.pushSubscription.removeObserver(observer);
    }
  }
}

/// OneSignal push service.
///
/// Deliberately a no-op unless `ONESIGNAL_APP_ID` is provided at build
/// time: an unconfigured key must never crash or spam the log. When the
/// key lands, `init()` registers the device, `login()` links the
/// Supabase user id as OneSignal's external id, and the
/// `push-order-status` Edge Function targets that id server-side.
final class OneSignalPushService implements PushService {
  OneSignalPushService({
    PushSdk? sdk,
    String? appId,
  })  : _sdk = sdk ?? OneSignalSdk(),
        _appId = appId;

  final PushSdk _sdk;
  final String? _appId;
  bool _initialized = false;
  Future<void>? _initFuture;

  String get _resolvedAppId => _appId ?? EnvConfig.onesignalAppId;

  @override
  Future<void> init() {
    final appId = _resolvedAppId;
    if (appId.isEmpty) {
      Log.i('push disabled — no OneSignal app id', category: LogCategory.app);
      return Future<void>.value();
    }
    if (_initialized) return Future<void>.value();
    // Callers can race (bootstrap starts init unawaited, an auth restore
    // calls login); share the in-flight future instead of initializing
    // the SDK twice.
    return _initFuture ??= _initialize(appId);
  }

  Future<void> _initialize(String appId) async {
    try {
      await _sdk.initialize(appId);
      _initialized = true;
      // Notification permission is requested from Settings (§12), not
      // at startup — a cold permission prompt on first launch reads as
      // hostile in a shopping app.
    } on Exception catch (e, st) {
      Log.w('push init failed.', error: e);
      Log.d(st.toString());
    } finally {
      _initFuture = null;
    }
  }

  @override
  Future<void> login(String userId) async {
    if (_resolvedAppId.isEmpty) return;
    await init();
    if (!_initialized) return;
    try {
      await _sdk.login(userId);
    } on Exception catch (e, st) {
      Log.w('push login failed.', error: e);
      Log.d(st.toString());
    }
  }

  @override
  Future<void> logout() async {
    if (_resolvedAppId.isEmpty) return;
    await init();
    if (!_initialized) return;
    try {
      await _sdk.logout();
    } on Exception catch (e, st) {
      Log.w('push logout failed.', error: e);
      Log.d(st.toString());
    }
  }

  @override
  String? get subscriptionId =>
      _resolvedAppId.isEmpty ? null : _sdk.subscriptionId;

  @override
  Future<void> requestPermission() async {
    if (_resolvedAppId.isEmpty) return;
    await init();
    if (!_initialized) return;
    try {
      await _sdk.requestPermission();
    } on Exception catch (e, st) {
      Log.w('push permission request failed.', error: e);
      Log.d(st.toString());
    }
  }

  @override
  Future<void> addSubscriptionObserver(
      void Function(String? id) listener) async {
    if (_resolvedAppId.isEmpty) return;
    await init();
    if (!_initialized) return;
    _sdk.addSubscriptionObserver(listener);
  }

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) =>
      _sdk.removeSubscriptionObserver(listener);
}
