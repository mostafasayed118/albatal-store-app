# Feature Batch — Design Spec (single worktree, sliced commits)

Date: 2026-09-12 | Base: `master@845d377` (green: analyze clean, test 632/632)
Mode: **L2 enabled by explicit owner approval** ("i approved and need you implement all", 2026-09-12).
Delivery: one branch `feat/feature-batch`, one worktree `.trees/feature-batch`, slices §1→§17 as
separate revertable commits, verifier once at batch end, **no push/merge without explicit owner call**.

## 0. Approved scope (owner-approved feature proposals, 2026-09-12)

All 20 proposals accepted. Grouped into 17 implementable slices (§1–§17 below). Two items are
docs-only because they require physical devices or external accounts: perf harness (§17) and
push-provider credentials (§12 — OneSignal app id stays env-gated).

## 1. Global architecture decisions

- **Server-first money math.** Coupon discounts and cut-length pricing are computed inside the
  proposed `create_checkout_order` migration update; the client never computes discounts or
  metered totals. Client displays server-returned lines only.
- **Review-gated SQL.** New migrations `048–053` are authored under `supabase/migrations/` but
  **never applied** by this worker (AGENTS.md: migrations need human review). Edge-function
  changes ship as proposals in `supabase/functions/_proposals/` as plain files for review.
- **Graceful degradation.** Every client feature backed by a new RPC/table must keep the app
  functional before migrations are applied: repositories catch `PostgrestException` and return
  typed `Result` failures; UI hides or disables the affordance on `featureUnavailable` errors
  instead of crashing. RemoteConfig flags default to "on client-side, harmless server-side".
- **No Firebase.** Push = OneSignal (per approved `docs/packages-proposal.md`); analytics =
  first-party `analytics_events` Supabase table. OAuth = Supabase native providers.
- **Platform channels stay behind interfaces.** New plugins (connectivity, notifications,
  biometrics, share, compress, app links) are wrapped in `lib/shared/**` or feature-level
  services with injectable fakes; tests never touch real channels.
- **l10n discipline.** Every user-facing string lands in `l10n/app_en.arb` + `app_ar.arb`;
  generated files regenerate via `flutter gen-l10n`. No raw strings in widgets.
- **GetIt discipline.** Every new service/cubit registers in `lib/shared/services/service_locator.dart`
  with a ctor-injectable dependency so `bloc_test`/`mocktail` fakes keep working.

## 2. Slices (each = 1+ revertable commit, TDD)

- **§1 Foundation (pubspec):** add owner-approved deps: connectivity_plus,
  internet_connection_checker_plus, flutter_local_notifications, onesignal_flutter, share_plus,
  app_links, permission_handler, flutter_image_compress, photo_view, skeletonizer,
  flutter_animate, local_auth, pdf, printing, package_info_plus. Gate: analyze + test green.
- **§2 Connectivity awareness:** `ConnectivityCubit` (connectivity_plus + real-internet check),
  `OfflineBanner` overlay above the navigator, l10n keys. Tests: cubit transitions with fakes,
  banner shows/hides.
- **§3 Skeleton loading:** skeletonizer placeholders for catalog grid, home feed, orders list
  while loading (replaces spinners). Tests: widget tests assert skeleton presence in loading state.
- **§4 Image compression:** `ImageCompressor` interface + `FlutterImageCompressor` impl; wired
  into InstaPay proof upload and admin image manager (skip-if-small guard, JPEG quality 82,
  max 1600px). Tests: guard logic with fakes (no channel).
- **§5 Share + deep links:** `share_plus` product share; `app_links` → GoRouter deep-link
  handling (`/product/:id`, `/catalog?q=`); pure `DeepLinkParser` for testability. Base URL from
  EnvConfig.
- **§6 Reorder:** `ReorderCubit` rebuilds cart from a delivered/past order, validating variants
  against live catalog (drop inactive/out-of-stock lines with a report). "Reorder" affordance on
  orders list/detail. Tests: cubit with fake catalog+cart repos.
- **§7 Search UX:** `RecentSearchesStore` (SharedPreferences, max 10, dedupe) + suggestions
  row under catalog search + proposed `search_suggestions` RPC (pg_trgm) with client-side
  cached-catalog fallback. Tests: store logic, debounce, fallback.
- **§8 Coupons:** migration `048_coupons.sql` (table, `validate_coupon`, checkout RPC accepts
  coupon) + checkout coupon field + discount line + admin coupon CRUD page. Tests: mapper,
  checkout cubit discount flow, admin CRUD cubit.
- **§9 Reviews:** migration `049_product_reviews.sql` (RLS: buy-to-review, approved-only read)
  + `ReviewsRepository` + details-page reviews section + submit sheet (rating, text, optional
  photo) + admin moderation page. Tests: repository mapping, cubits, upload-path compression tie-in.
- **§10 Fabric attributes:** migration `050_fabric_attributes.sql` (products: composition,
  width_cm, gsm, care_instructions; variants: sell_by_length, min_cut_meters) + details-page
  length stepper + spec/care section + admin edit fields. Tests: mappers, stepper logic.
- **§11 Analytics:** migration `051_analytics_events.sql` (insert-own RLS, aggregates RPC for
  admin) + `AnalyticsService` (fire-and-forget, redacts ids, swallows failures) + instrumentation
  (product view, ATC, checkout start, purchase) + admin dashboard widget. Tests: service with
  fake sink; no analytics in widget tests.
- **§12 Notifications:** `NotificationService` (flutter_local_notifications; local order-status
  notification on foreground transitions) + `PushService` (onesignal_flutter scaffold; no-op
  unless EnvConfig key set) + proposed edge function `push-order-status` + wishlist/flash-sale
  alert toggle stored locally. Tests: permission-request gating with fakes.
- **§13 Remote config:** migration `052b_app_config.sql` + `RemoteConfigService` (typed keys,
  defaults, 10-min TTL) + maintenance-mode gate (splash → `MaintenancePage`) + min-version
  forced-update check (package_info_plus). Tests: defaults, TTL, gates.
- **§14 Admin ops:** `AdminCustomersPage` (profiles list, search, membership control reuse) +
  `OrdersCsvExporter` (pure CSV builder; share via share_plus) + dashboard links. Tests: CSV
  builder (quoting/injection), customers cubit.
- **§15 Auth upgrades:** Google/Apple OAuth buttons (Supabase `signInWithOAuth`, graceful
  "provider unavailable" error) + optional App Lock (local_auth biometrics, settings toggle,
  cold-start gate). Tests: cubit logic with fakes.
- **§16 Invoice PDF:** pure `InvoicePdfBuilder` (pdf pkg, emerald/gold brand, per DESIGN.md) +
  "Save/Share invoice" on order detail (printing pkg). Tests: builder emits valid non-empty PDF
  with expected text markers.
- **§17 Accessibility + perf harness:** Semantics pass (swatch color-name labels + selected
  state, cart stepper increment/decrement actions, merged product-card labels), reduce-motion
  respect, text-scale spot fixes; `test/perf/` scroll micro-benchmark + `docs/perf-budget.md`.
  Tests: semantics widget tests; perf test guarded to run only in CI/profile mode.

## 3. Rejected alternatives

- Direct-to-master edits (violates binding constraints). One mega-commit (unrevertable).
- Applied migrations from the worker (AGENTS.md gate). Client-side discount math (money must be
  server-owned). Firebase Cloud Messaging (project-wide rejection). Reworking existing Cubit
  state shapes (additive fields only).

## 4. Verification protocol

Per slice: `flutter analyze` → `flutter test <slice tests>` → `dart format` touched files →
commit. Batch end: full `flutter analyze` + `flutter test`, secret sweep
(`git diff --check`, no keys/.env), verifier sub-agent, evidence recorded in `STATE.md`
(main tree) and this doc's status table.

## 5. Status (fill at batch end)

| Slice | Commit | Tests | Verifier |
| ----- | ------ | ----- | -------- |
| (pending) | | | |
