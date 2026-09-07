import 'dart:io';

import 'package:flutter/foundation.dart';

import 'bootstrap.dart';

/// Debug-only entry point for on-device smoke runs.
///
/// Building with `--target=lib/main_smoke.dart` is what arms the smoke
/// harness: it passes a process-exit hook to the app, which is the mount
/// signal for `SmokeHarness`. Every launch of this build performs one full
/// read-only pass against whatever backend the build was configured for
/// and then exits the process (code 0 = all scenarios passed, 1 = failure),
/// so logcat is the verification channel even on devices where the Flutter
/// semantics tree is dead and `uiautomator dump` returns an empty
/// hierarchy.
///
/// See `docs/device-smoke-runbook.md` for the full procedure.
///
/// IMPORTANT: Android/iOS only — this file imports `dart:io` for the exit
/// hook and must never be targeted at the web platform.
Future<void> main() async {
  if (kReleaseMode) {
    // Belt-and-braces: the harness refuses to run in release anyway, but
    // failing at startup makes a misconfigured release build unmistakable.
    throw UnsupportedError(
        'lib/main_smoke.dart is a debug-only smoke entry point; '
        'never build it in release mode');
  }
  await bootstrap(exitApp: (exitCode) => exit(exitCode));
}
