import '../../features/admin/presentation/cubit/admin_cubit.dart';
import 'smoke_scenario.dart';

/// Read-only data-path scenarios: they exercise the real cubits and
/// repositories against whatever backend the app is built for, so a pass
/// means the RPC contracts hold end-to-end on this device. No writes —
/// runs must never mutate the environment under test.
Map<String, SmokeScenario> adminReadScenarios() => {
      'admin_dashboard_data': (ctx) async {
        // Every load is time-bounded: a smoke run must terminate even if
        // the network hangs, with the stall named in a failed check.
        Future<void> bounded(Future<void> step) =>
            step.timeout(const Duration(seconds: 15));

        // The harness starts on the first frame — before a persisted admin
        // session has rehydrated. One retry after a settle absorbs that
        // race on slow devices without masking real failures (the check
        // itself still fails if the second attempt errors).
        await bounded(ctx.adminCubit.loadOrders());
        await bounded(ctx.adminCubit.loadLowStockProducts());
        await ctx.pump(const Duration(seconds: 3));
        if (ctx.adminCubit.state.errorMessage != null) {
          await ctx.log('dashboard: first attempt errored, retrying after '
              'session settle');
          await bounded(ctx.adminCubit.loadOrders());
          await bounded(ctx.adminCubit.loadLowStockProducts());
          await ctx.pump(const Duration(seconds: 3));
        }
        final s = ctx.adminCubit.state;
        return [
          SmokeCheck('dashboard_status_ready',
              ok: s.status == AdminStatus.ready,
              detail: 'status=${s.status.name}'),
          SmokeCheck('dashboard_no_error',
              ok: s.errorMessage == null,
              detail: 'error=${s.errorMessage ?? 'none'}'),
          SmokeCheck('low_stock_mapper_keeps_rows',
              ok: s.lowStockProducts.isNotEmpty,
              detail: 'rows=${s.lowStockProducts.length} — the 043 contract: '
                  'id-less rows are silently dropped, so an empty list on a '
                  'catalog that ships means the RPC/mapper contract broke'),
        ];
      },
      'admin_routes_live': (ctx) async {
        // Every admin path must land somewhere real: a redirect back to
        // sign-in means the admin guard tripped, and go_router's error page
        // would mean a dead end like the pre-044 catalog hub.
        const paths = [
          '/admin',
          '/admin/orders',
          '/admin/inventory',
          '/admin/catalog',
          '/admin/products',
          '/admin/products/new',
          '/admin/categories',
        ];
        final checks = <SmokeCheck>[];
        for (final path in paths) {
          ctx.router.go(path); // void — no await.
          await ctx.pump();
          final location = ctx.router.routeInformationProvider.value.uri.path;
          checks.add(SmokeCheck(
            'route_live_$path',
            ok: location == path,
            detail: 'landed=$location',
          ));
        }
        return checks;
      },
    };
