import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/cubit/admin_cubit.dart';
import 'admin_read_scenarios.dart';
import 'smoke_runner.dart';
import 'smoke_scenario.dart';

/// Signature for terminating the process after a run completes.
/// Production wires `exit` from `dart:io`; widget tests pass a sentinel.
typedef SmokeExit = void Function(int exitCode);

/// Build-time scenario filter: `--dart-define=E2E_SCENARIOS=a,b` restricts
/// the run to those scenario names; empty (the default) means all.
///
/// Must stay a top-level const: `String.fromEnvironment` only bakes the
/// value in const contexts — the exact bug class that sank the previous
/// define-based on/off gate in a non-const getter.
const String kSmokeScenarioFilter = String.fromEnvironment('E2E_SCENARIOS');

/// Debug-only smoke harness for on-device verification.
///
/// Mounted **only** by the dedicated smoke entry point
/// (`lib/main_smoke.dart`), which passes the [exitApp] hook — that hook is
/// the gate, so no dart-define is involved and a normal debug build cannot
/// mount it. The harness additionally refuses to run under `kReleaseMode`.
///
/// Survives the uiautomator-dead case: on devices where OEM hibernation has
/// killed the Flutter semantics tree and every `uiautomator dump` returns an
/// empty hierarchy, verification runs through greppable `[SMOKE]` logcat
/// lines driven by deterministic delays — no a11y tree, no tap coordinates.
///
/// Build & run (see docs/device-smoke-runbook.md):
/// ```
/// flutter build apk --debug --target=lib/main_smoke.dart \
///   --dart-define-from-file=config/env.staging.local.json
/// adb install -r build/app/outputs/flutter-apk/app-debug.apk
/// adb shell am start -n <pkg>/.MainActivity
/// adb logcat -s flutter | grep SMOKE
/// ```
class SmokeHarness extends StatefulWidget {
  const SmokeHarness({
    super.key,
    required this.child,
    required this.router,
    required this.adminCubit,
    this.exitApp,
  });

  /// Process-exit hook, invoked once after the run completes.
  final SmokeExit? exitApp;

  final Widget child;
  final GoRouter router;
  final AdminCubit adminCubit;

  @override
  State<SmokeHarness> createState() => _SmokeHarnessState();
}

class _SmokeHarnessState extends State<SmokeHarness> {
  final List<String> _buffer = [];
  bool _running = false;
  bool _ran = false;
  SemanticsHandle? _semanticsHandle;

  Future<void> _log(String message) async {
    debugPrint('[SMOKE] $message');
    if (mounted) {
      setState(() => _buffer.add(message));
    }
  }

  Future<void> _pump([Duration duration = const Duration(seconds: 1)]) =>
      Future<void>.delayed(duration);

  /// Restricts the run at build time via [kSmokeScenarioFilter].
  List<String>? get _scenarioFilter {
    if (kSmokeScenarioFilter.isEmpty) return null;
    return kSmokeScenarioFilter.split(',').map((s) => s.trim()).toList();
  }

  Future<void> _start() async {
    if (_ran) return;
    if (kReleaseMode) {
      // Defense-in-depth: the entry point is the gate, but the harness
      // itself must never run in a release binary either.
      debugPrint('[SMOKE] refused: release build');
      return;
    }
    setState(() {
      _running = true;
      _ran = true;
    });
    // Announce synchronously, before anything can hang: a run that goes
    // silent after this line means a step is stuck, not that the harness
    // is absent.
    debugPrint('[SMOKE] RUN start (mounted on first frame)');

    // On some devices the semantics tree is merely dormant; requesting it
    // revives uiautomator dumps alongside the logcat channel. Harmless if
    // the session is truly dead — the logs are the source of truth. The
    // handle is held for the app session (deliberately never closed).
    try {
      _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    } catch (_) {}

    final ctx = SmokeContext(
      router: widget.router,
      log: _log,
      pump: _pump,
      adminCubit: widget.adminCubit,
    );
    final runner = SmokeRunner(
      context: ctx,
      scenarios: adminReadScenarios(),
    );

    await runner.run(only: _scenarioFilter);

    if (mounted) {
      setState(() => _running = false);
    }
    widget.exitApp?.call(runner.results.every((r) => r.passed) ? 0 : 1);
  }

  @override
  void dispose() {
    _semanticsHandle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ran) _start();
    });

    if (!_running && _ran && _buffer.isNotEmpty) {
      // Done: collapse to a thin summary strip over the finished app.
      return Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.green.shade900,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'SMOKE DONE — ${_buffer.lastWhere((l) => l.startsWith('SUMMARY'), orElse: () => 'see logcat')}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        widget.child,
        if (_running)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.black54,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SMOKE RUNNING…',
                          style: Theme.of(context).textTheme.labelMedium),
                      for (final line in _buffer
                          .skip(_buffer.length > 5 ? _buffer.length - 5 : 0))
                        Text(line,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
