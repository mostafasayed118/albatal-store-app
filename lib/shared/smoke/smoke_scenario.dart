import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/cubit/admin_cubit.dart';

/// One observable outcome of a smoke-scenario step.
///
/// Scenarios report [SmokeCheck]s instead of printing free-form text so
/// the harness can render a uniform, greppable PASS/FAIL summary.
class SmokeCheck {
  const SmokeCheck(this.name, {required this.ok, this.detail = ''});

  /// Short snake_case identifier, stable across runs.
  final String name;

  /// Whether the expectation held. Data-dependent conditions (row counts,
  /// specific products) belong in [detail], not here — checks should pass
  /// on any environment unless a contract is genuinely broken.
  final bool ok;

  final String detail;
}

/// Everything a scenario may touch, captured before the first async gap so
/// no BuildContext is ever used across awaits.
class SmokeContext {
  const SmokeContext({
    required this.router,
    required this.log,
    required this.pump,
    required this.adminCubit,
  });

  /// The app's real router — scenarios navigate through actual routes, so
  /// dead ends and guard behavior are exercised, not bypassed.
  final GoRouter router;

  /// Emits a greppable `[SMOKE]` line to logcat (and the harness buffer).
  final Future<void> Function(String message) log;

  /// Real-async settle: long enough for route animations and RPCs on a
  /// slow device. Not a frame pump — the device does its own rendering.
  final Future<void> Function([Duration duration]) pump;

  /// App-scope cubits captured at harness start.
  final AdminCubit adminCubit;
}

/// A scenario receives a [SmokeContext] and reports [SmokeCheck]s.
typedef SmokeScenario = Future<List<SmokeCheck>> Function(SmokeContext ctx);
