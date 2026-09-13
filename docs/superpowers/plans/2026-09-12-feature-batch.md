# Feature Batch Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 20 owner-approved feature proposals as 17 revertable slices in one
worktree/branch, keeping the suite green (analyze clean, all tests passing) at every commit.

**Architecture:** Additive Clean-Architecture slices. New platform capabilities sit behind
interfaces with fakes; new server capabilities ship as review-gated SQL/edge-function proposals;
money math stays server-side; every user-facing string is l10n'd (EN+AR); GetIt registrations
use ctor-injected dependencies.

**Tech Stack:** Flutter 3.x, Dart 3.x, bloc/flutter_bloc, equatable, get_it, go_router,
supabase_flutter, intl, flutter_test/bloc_test/mocktail/fake_async + newly approved plugins
(connectivity_plus, internet_connection_checker_plus, flutter_local_notifications,
onesignal_flutter, share_plus, app_links, permission_handler, flutter_image_compress,
photo_view, skeletonizer, flutter_animate, local_auth, pdf, printing, package_info_plus).

**Spec:** `docs/superpowers/specs/2026-09-12-feature-batch-design.md`

## Global Constraints

- Work in worktree `.trees/feature-batch`, branch `feat/feature-batch`; never edit `master`.
- Never push/merge; owner call only. Max 3 fix attempts per item, then escalate in STATE.md.
- `supabase/` changes = new proposal files only (`048–053` migrations, `functions/_proposals/`);
  never apply, never edit existing migrations.
- Additive state changes only (new optional fields with defaults; no public shape breaks).
- Every slice: TDD (failing test first), `flutter analyze` then slice tests, `dart format`
  touched files, secret sweep, one commit per slice.

## File map (new files)

- `lib/shared/services/connectivity_cubit.dart`, `lib/shared/widgets/offline_banner.dart`
- `lib/shared/services/image_compressor.dart`
- `lib/shared/services/deep_link_parser.dart`, `lib/shared/services/deep_link_service.dart`,
  `lib/shared/services/product_share_service.dart`
- `lib/features/storefront/presentation/cubit/reorder_cubit.dart`
- `lib/features/storefront/data/recent_searches_store.dart`
- `lib/features/storefront/domain/repositories/reviews_repository.dart`,
  `lib/features/storefront/data/supabase_reviews_repository.dart`,
  `lib/features/storefront/presentation/cubit/reviews_cubit.dart`,
  `lib/features/storefront/presentation/pages/review_submit_sheet.dart`
- `lib/features/storefront/domain/repositories/coupons_repository.dart`,
  `lib/features/storefront/data/supabase_coupons_repository.dart`
- `lib/shared/services/analytics_service.dart`, `lib/shared/services/remote_config_service.dart`
- `lib/shared/services/notification_service.dart`, `lib/shared/services/push_service.dart`,
  `lib/shared/services/local_auth_service.dart`
- `lib/features/storefront/domain/invoice/invoice_pdf_builder.dart`
- `lib/features/admin/domain/orders_csv_exporter.dart`,
  `lib/features/admin/presentation/pages/admin_customers_page.dart`,
  `lib/features/admin/presentation/pages/admin_coupons_page.dart`,
  `lib/features/admin/presentation/pages/admin_reviews_page.dart`
- `supabase/migrations/048_coupons.sql`, `049_product_reviews.sql`,
  `050_fabric_attributes.sql`, `051_analytics_events.sql`, `052b_app_config.sql`
- `supabase/functions/_proposals/push-order-status/index.ts` (+ README note)
- Tests mirror the above under `test/`; l10n keys in `l10n/app_en.arb` + `app_ar.arb`.

## File map (modified)

- `pubspec.yaml` (§1 approved deps), `lib/shared/services/service_locator.dart` (all slices),
  `lib/shared/routing/app_router.dart` (§13 maintenance, §14–15 admin routes, §9 review route),
  `lib/app.dart` (§2 banner, §12 notification bootstrap, §15 app-lock gate),
  `lib/features/storefront/presentation/pages/{home,catalog,details,orders,checkout,cart}_page.dart`
  (§3, §5–§10, §17), `lib/features/payments/presentation/pages/instapay_instructions_page.dart`
  (§4), `lib/features/admin/presentation/pages/{admin_dashboard,admin_product_edit,admin_variant_editor}_page.dart`
  (§8–§10, §14), `lib/features/auth/presentation/pages/{sign_in,profile}_page.dart` (§15),
  `lib/features/settings/presentation/pages/settings_page.dart` (§15 app lock, §12 alerts).

---

### Task §1: Foundation — approved dependencies
- [ ] `flutter pub add connectivity_plus internet_connection_checker_plus flutter_local_notifications onesignal_flutter share_plus app_links permission_handler flutter_image_compress photo_view skeletonizer flutter_animate local_auth pdf printing package_info_plus`
- [ ] Gate: `flutter analyze` clean + `flutter test` 632/632 green → commit `feat(§1): approved dependency additions`.

### Task §2: Connectivity awareness
- [ ] Failing test: `ConnectivityCubit` maps connectivity stream → `online/offline/checking` (fake stream).
- [ ] Impl cubit + `OfflineBanner` (MaterialBanner-style overlay, l10n `offlineBanner`).
- [ ] Wire banner above `MaterialApp.router` builder in `app.dart`; register cubit.
- [ ] Gate + commit `feat(§2): offline banner`.

### Task §3: Skeleton loading
- [ ] Failing widget tests: catalog/home/orders show `Skeletonizer` while loading.
- [ ] Impl skeleton placeholders per page (existing loading states → skeleton zones).
- [ ] Gate + commit `feat(§3): skeleton loading states`.

### Task §4: Image compression
- [ ] Failing test: guard skips files under threshold; impl `ImageCompressor` interface +
      `FlutterImageCompressor` (quality 82, max 1600px).
- [ ] Wire into InstaPay proof upload + admin image manager upload paths.
- [ ] Gate + commit `feat(§4): upload image compression`.

### Task §5: Share + deep links
- [ ] Failing tests: `DeepLinkParser` (`/product/:id`, `/catalog?q=`), `ProductShareService` text building.
- [ ] Impl + `app_links` listener in bootstrap → router navigation; share button on details page.
- [ ] Gate + commit `feat(§5): product share and deep links`.

### Task §6: Reorder
- [ ] Failing cubit tests: rebuild cart; drop inactive/out-of-stock lines with report; no-op when cart has items? (confirm dialog).
- [ ] Impl `ReorderCubit` + orders-list/detail button + result snackbar.
- [ ] Gate + commit `feat(§6): one-tap reorder`.

### Task §7: Search UX
- [ ] Failing tests: `RecentSearchesStore` dedupe/limit/persist; suggestions fallback from cached catalog.
- [ ] Impl recent-searches chips + suggestion overlay on catalog search.
- [ ] Proposal: `052b` partial — `search_suggestions` RPC lives in §7 addendum of `048_coupons.sql`? NO — separate `supabase/migrations/048_search_suggestions.sql` (renumber map below).
- [ ] Gate + commit `feat(§7): recent searches and suggestions`.

> Migration numbering (proposal files, in slice order): 048_search_suggestions, 049_coupons,
> 050_product_reviews, 051_fabric_attributes, 052_analytics_events, 052b_app_config.

### Task §8: Coupons
- [ ] Failing tests: `validate_coupon` result mapper; checkout cubit applies server discount; admin coupon CRUD cubit.
- [ ] Impl repo + checkout field + discount line + `admin_coupons_page` + route.
- [ ] Proposal `049_coupons.sql`.
- [ ] Gate + commit `feat(§8): promo codes end-to-end (client) + SQL proposal`.

### Task §9: Reviews
- [ ] Failing tests: reviews repo mapping (approved-only, buy-to-review gate via RPC error), cubits, moderation page cubit.
- [ ] Impl details reviews section + submit sheet + `admin_reviews_page`.
- [ ] Proposal `050_product_reviews.sql`.
- [ ] Gate + commit `feat(§9): photo reviews + moderation (client) + SQL proposal`.

### Task §10: Fabric attributes
- [ ] Failing tests: mapper reads composition/width/gsm/care + `sell_by_length`/`min_cut_meters`; length stepper math (min cut, rounding to 0.5m).
- [ ] Impl details spec/care section + stepper; admin product/variant edit fields.
- [ ] Proposal `051_fabric_attributes.sql` (+ `create_checkout_order` metered-line update inside proposal).
- [ ] Gate + commit `feat(§10): fabric attributes + cut-length purchase (client) + SQL proposal`.

### Task §11: Analytics
- [ ] Failing tests: `AnalyticsService` fire-and-forget (swallow, redact, no-throw when unauthenticated).
- [ ] Impl + instrument product view / ATC / checkout start / purchase; admin dashboard events widget.
- [ ] Proposal `052_analytics_events.sql`.
- [ ] Gate + commit `feat(§11): first-party analytics`.

### Task §12: Notifications
- [ ] Failing tests: `NotificationService` permission gating with fake; `PushService` no-op without env key; alerts toggle store.
- [ ] Impl local order-status notifications + push scaffold + settings toggles.
- [ ] Proposal `supabase/functions/_proposals/push-order-status/index.ts`.
- [ ] Gate + commit `feat(§12): order notifications (local + push scaffold)`.

### Task §13: Remote config
- [ ] Failing tests: `RemoteConfigService` defaults, TTL cache, maintenance/min-version gates.
- [ ] Impl + splash maintenance gate + `MaintenancePage` + forced-update dialog.
- [ ] Proposal `052b_app_config.sql`.
- [ ] Gate + commit `feat(§13): remote config + maintenance mode`.

### Task §14: Admin ops
- [ ] Failing tests: `OrdersCsvExporter` (header, quoting, formula-injection guard); customers cubit paging/search.
- [ ] Impl `admin_customers_page` + CSV export button on admin orders + dashboard links.
- [ ] Gate + commit `feat(§14): admin customers + CSV export`.

### Task §15: Auth upgrades
- [ ] Failing tests: OAuth cubit mapping (provider unavailable → l10n code); app-lock cubit (canCheckBiometrics false → disabled state).
- [ ] Impl Google/Apple buttons on sign-in; App Lock setting + cold-start gate.
- [ ] Gate + commit `feat(§15): OAuth + biometric app lock`.

### Task §16: Invoice PDF
- [ ] Failing tests: `InvoicePdfBuilder` non-empty PDF, brand header text, line items + totals; empty-order rejection.
- [ ] Impl + order-detail "Save invoice" action (printing share).
- [ ] Gate + commit `feat(§16): invoice PDF`.

### Task §17: Accessibility + perf harness
- [ ] Failing semantics tests: swatch color-name labels + selected state; cart stepper actions; merged product-card label.
- [ ] Impl Semantics pass; `MediaQuery.disableAnimations` guards for §3 skeletons/animates.
- [ ] Add `test/perf/catalog_scroll_perf_test.dart` (skipped unless `PERF=1`) + `docs/perf-budget.md`.
- [ ] Gate + commit `feat(§17): accessibility pass + perf harness`.

### Batch end protocol
- [ ] Full `flutter analyze` + `flutter test` (all green).
- [ ] `git diff master --check` secret sweep; review untracked strays.
- [ ] Verifier sub-agent over full diff vs plan; fix verdicts (≤3 attempts/item).
- [ ] Fill spec §5 status table; update `STATE.md` (main tree) with evidence; final owner report
      (no push/merge).
