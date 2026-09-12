# Performance Budget (feature-batch §17)

Statuses and budgets for the surfaces that historically regressed
(idle rebuilds, unbounded loads — see PR #44 and the audit batches).

## Budgets

| Surface | Metric | Budget | Current evidence |
| ------- | ------ | ------ | ---------------- |
| Catalog grid scroll | dropped frames (profile, 60 Hz device) | < 5% over a 500-item fling | `test/perf/` harness (PERF=1, device run) |
| Home build | rebuilds per 10 s idle | 0 (flash ticker cubit-owned, `buildWhen`-gated) | `catalog_perf_test.dart` |
| Orders open | fetch-to-first-frame | ≤ 300 ms p50 on 4G | server-side; verify with `flutter run --profile` trace |
| App cold start | splash → /home | ≤ 2.5 s debug-free (profile) | device run |
| Image decode | thumb decode bounds | ≤ 72 px thumbs in grids (PR #51) | covered by unit tests |

## How to run the harness

```sh
PERF=1 flutter test test/perf --profile   # requires a connected device/emulator
```

The perf tests are skipped by default (`PERF` env gate) because frame
timings are only meaningful on real hardware.

## Rules of thumb

- New list surfaces: virtualize (`ListView.builder` / slivers) and bound
  queries (`limit`).
- New per-frame state (tickers, clocks): own it inside a cubit and gate
  page rebuilds with `buildWhen`/selectors.
- New images: set `cacheWidth`/`memCacheWidth` for grid thumbnails.
- New animations: respect `MediaQuery.disableAnimationsOf` (skeleton
  loaders do, §17).
