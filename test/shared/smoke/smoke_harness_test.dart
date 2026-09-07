import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/shared/smoke/smoke_harness.dart';
import 'package:al_batal_elite/shared/smoke/smoke_runner.dart';
import 'package:al_batal_elite/shared/smoke/smoke_scenario.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Fakes ──────────────────────────────────────────────────────

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.lowStock = const []});

  List<LowStockVariant> lowStock;

  /// When set, order loads fail — drives the error/retry path.
  bool ordersError = false;

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
      {AdminOrderStatus? status, int limit = 50}) async {
    if (ordersError) return Failure(AppError('offline'));
    return const Success([]);
  }

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      Success(lowStock);

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeProvider extends GoRouteInformationProvider {
  _FakeProvider() : super(initialLocation: '/home', initialExtra: null);

  RouteInformation _current = RouteInformation(uri: Uri.parse('/home'));

  @override
  RouteInformation get value => _current;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.navigate,
  }) =>
      // Recording override: the real implementation JSON-encodes the route
      // state for the engine, which no test needs — scenarios only read
      // the location back.
      _current = routeInformation;
}

class _FakeGoRouter implements GoRouter {
  final provider = _FakeProvider();

  @override
  void go(String location, {Object? extra}) =>
      provider.routerReportsNewRouteInformation(
        RouteInformation(uri: Uri.parse(location)),
        type: RouteInformationReportingType.navigate,
      );

  @override
  GoRouteInformationProvider get routeInformationProvider => provider;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SmokeContext _context({
  required GoRouter router,
  required List<String> logs,
  required AdminCubit cubit,
}) =>
    SmokeContext(
      router: router,
      log: (m) async => logs.add(m),
      pump: ([duration = const Duration(milliseconds: 1)]) async {},
      adminCubit: cubit,
    );

/// Advances the test clock past the harness's real-timer pumps (1s settle
/// per step, ~15s of scenario timeline) — pumpAndSettle cannot drive them
/// because the timers schedule no frames.
Future<void> flushTimers(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(seconds: 3));
  }
}

AdminCubit _cubit(_FakeAdminRepository repo) {
  if (getIt.isRegistered<AdminRepository>()) {
    getIt.unregister<AdminRepository>();
  }
  getIt.registerSingleton<AdminRepository>(repo);
  final cubit = AdminCubit(repo);
  getIt.unregister<AdminRepository>();
  return cubit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
  });

  test('smoke gating is structural: entry point is the gate, no dart-define',
      () {
    // The harness mounts only when the app was given a process-exit hook,
    // and only the dedicated smoke entry point supplies one. A dart-define
    // gate was tried first and failed on-device (bool.fromEnvironment
    // returns its default outside a const context), so the invariant is
    // now pinned at the source level like the SQL contract tests do.
    final mainSrc = File('lib/main.dart').readAsStringSync();
    final smokeSrc = File('lib/main_smoke.dart').readAsStringSync();
    final appSrc = File('lib/app.dart').readAsStringSync();

    expect(mainSrc.contains('exitApp'), isFalse,
        reason: 'production entry must never arm the smoke harness');
    expect(smokeSrc.contains('bootstrap(exitApp:'), isTrue,
        reason: 'the smoke entry is what arms the harness');
    expect(smokeSrc.contains('kReleaseMode'), isTrue,
        reason: 'the smoke entry must refuse release builds');
    expect(appSrc.contains('widget.exitApp != null'), isTrue,
        reason: 'AlBatalApp mounts SmokeHarness only with an exit hook');
    expect(appSrc.contains('compileTimeEnabled'), isFalse,
        reason: 'the broken define-based gate must stay dead');
  });

  test('SmokeRunner isolates a throwing scenario and reports failures',
      () async {
    final logs = <String>[];
    final ctx = _context(
      router: _FakeGoRouter(),
      logs: logs,
      cubit: _cubit(_FakeAdminRepository()),
    );

    final runner = SmokeRunner(
      context: ctx,
      scenarios: {
        'passes': (_) async => [const SmokeCheck('ok_thing', ok: true)],
        'throws': (_) async => throw StateError('boom'),
        'fails': (_) async => [const SmokeCheck('bad_thing', ok: false)],
      },
    );

    await runner.run();

    expect(runner.results, hasLength(3),
        reason: 'one throw must not stop '
            'later scenarios');
    expect(runner.results.firstWhere((r) => r.name == 'passes').passed, isTrue);
    expect(
        runner.results.firstWhere((r) => r.name == 'throws').passed, isFalse);
    expect(runner.results.firstWhere((r) => r.name == 'fails').passed, isFalse);
    expect(logs.where((l) => l.contains('SUMMARY 1/3')), isNotEmpty,
        reason: 'the greppable summary names the totals');
    expect(logs.join('\n'), contains('FAIL throws'),
        reason: 'failing scenarios are named in the log');
  });

  test('SmokeRunner.only runs the requested subset', () async {
    final logs = <String>[];
    final ctx = _context(
      router: _FakeGoRouter(),
      logs: logs,
      cubit: _cubit(_FakeAdminRepository()),
    );

    final runner = SmokeRunner(
      context: ctx,
      scenarios: {
        'alpha': (_) async => [const SmokeCheck('a', ok: true)],
        'beta': (_) async => [const SmokeCheck('b', ok: true)],
      },
    );

    await runner.run(only: ['beta']);
    expect(runner.results.map((r) => r.name), ['beta']);
  });

  testWidgets('harness passes end-to-end against healthy fakes',
      (tester) async {
    final repo = _FakeAdminRepository(
      lowStock: [
        const LowStockVariant(
            variantId: 'v1',
            productName: 'Silk',
            size: 'M',
            color: 'N',
            stock: 2),
      ],
    );
    var exitCode = -1;
    final router = _FakeGoRouter();

    await tester.pumpWidget(MaterialApp(
      home: SmokeHarness(
        router: router,
        adminCubit: _cubit(repo),
        exitApp: (code) => exitCode = code,
        child: const Scaffold(body: Text('app')),
      ),
    ));
    await flushTimers(tester);

    expect(exitCode, 0, reason: 'healthy fakes must pass');
    expect(find.text('app'), findsOneWidget,
        reason: 'the harness overlays, never replaces, the app');
    expect(find.textContaining('SMOKE DONE'), findsOneWidget);
  });

  testWidgets('harness fails the run when the low-stock contract breaks',
      (tester) async {
    // An id-less empty result is exactly what the pre-043 bug produced:
    // the mapper contract check must fail the run (exit 1).
    final repo = _FakeAdminRepository(lowStock: const []);
    var exitCode = -1;

    await tester.pumpWidget(MaterialApp(
      home: SmokeHarness(
        router: _FakeGoRouter(),
        adminCubit: _cubit(repo),
        exitApp: (code) => exitCode = code,
        child: const Scaffold(body: SizedBox()),
      ),
    ));
    await flushTimers(tester);

    expect(exitCode, 1,
        reason: 'empty low stock must fail: it is the 043-bug signature');
  });

  testWidgets('harness surfaces repository errors as a failed run',
      (tester) async {
    final repo = _FakeAdminRepository()..ordersError = true;
    var exitCode = -1;

    await tester.pumpWidget(MaterialApp(
      home: SmokeHarness(
        router: _FakeGoRouter(),
        adminCubit: _cubit(repo),
        exitApp: (code) => exitCode = code,
        child: const Scaffold(body: SizedBox()),
      ),
    ));
    await flushTimers(tester);

    expect(exitCode, 1, reason: 'repo errors must fail the run, not pass');
  });
}
