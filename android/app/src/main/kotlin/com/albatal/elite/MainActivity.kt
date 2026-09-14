package com.albatal.elite

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Host activity for the Flutter engine.
 *
 * MUST extend [FlutterFragmentActivity] (not `FlutterActivity`): the
 * `local_auth` plugin behind the biometric app lock (feature-batch §15)
 * requires the foreground activity to be an `androidx.fragment.app.
 * FragmentActivity`. Any other activity type makes the plugin answer
 * `AuthResultCode.NOT_FRAGMENT_ACTIVITY` without ever showing a prompt
 * (see `LocalAuthPlugin.java`: `if (!(activity instanceof FragmentActivity))`),
 * which silently turned the app lock into a no-op. `FlutterFragmentActivity`
 * is a `FragmentActivity` subclass, so the prompt can actually be shown.
 *
 * Regression-guarded by `test/platform/platform_config_test.dart`.
 */
class MainActivity : FlutterFragmentActivity()
