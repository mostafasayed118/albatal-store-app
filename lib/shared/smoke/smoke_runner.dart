import 'package:flutter/foundation.dart';

import 'smoke_scenario.dart';

/// Outcome of one scenario.
class SmokeResult {
  SmokeResult(this.name);

  final String name;
  final List<SmokeCheck> checks = [];
  Object? error;

  bool get passed => error == null && checks.every((c) => c.ok);

  String get verdict => passed ? 'PASS' : 'FAIL';
}

/// Runs [scenarios] in order against a [SmokeContext], isolating failures:
/// a throwing scenario is recorded and the run continues, so one broken
/// surface can never mask another.
///
/// The complete summary is logged via [SmokeContext.log] (`[SMOKE]`-tagged,
/// greppable in logcat — the verification channel on devices where the
/// accessibility tree is dead and uiautomator dumps are empty) and is also
/// available via [results] for any UI that renders it.
class SmokeRunner {
  SmokeRunner({required this.context, required this.scenarios});

  final SmokeContext context;
  final Map<String, SmokeScenario> scenarios;

  final List<SmokeResult> results = [];

  Future<void> run({List<String>? only}) async {
    results.clear();
    final selected = (only == null || only.isEmpty)
        ? scenarios.keys.toList()
        : only.where(scenarios.containsKey).toList();

    for (final entry in scenarios.entries) {
      if (!selected.contains(entry.key)) continue;
      final result = SmokeResult(entry.key);
      try {
        result.checks.addAll(await entry.value(context));
      } catch (e, st) {
        // The only acceptable failure mode is a recorded one.
        result.error = e;
        debugPrintStack(stackTrace: st, maxFrames: 12);
      }
      results.add(result);
      await context.log('${result.verdict} ${entry.key}');
    }

    final failed = results.where((r) => !r.passed).length;
    await context.log(
        'SUMMARY ${results.length - failed}/${results.length} scenarios passed');
    for (final r in results) {
      final failedChecks =
          r.checks.where((c) => !c.ok).map((c) => c.name).join(',');
      await context.log(
          '  ${r.verdict} ${r.name}${r.error != null ? ' (threw: ${r.error})' : ''}${failedChecks.isEmpty ? '' : ' failed_checks=$failedChecks'}');
    }
  }
}
