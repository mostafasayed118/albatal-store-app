# Al Batal Elite — Comprehensive Code Quality Audit

- **Date:** 2026-09-21 · **Tree:** `master` @ `ef91836`
- **Scope:** `lib/` (269 files, ~36.9k LOC) + `supabase/` + platform manifests. `build/`, `node_modules`, `.mimocode`, `.openclaw`, `lib/generated` excluded.
- **Method:** five parallel dimension audits, then independent verification of every HIGH claim against source (all six held; one security claim confirmed with nuance). Full per-dimension detail in `sections/`.
- **Weights:** the frozen 2026-09-15 rubric — Maintainability 20% · Clean Architecture 20% · Code Quality 20% · Security 25% · Performance 15% — kept for comparability.

## 1. Overall score

| Dimension | Weight | Score | Weighted |
|---|---|---|---|
| Maintainability | 20% | **8.0** | 1.60 |
| Clean architecture | 20% | **7.5** | 1.50 |
| Code quality | 20% | **8.0** | 1.60 |
| Security | 25% | **8.5** | 2.13 |
| Performance | 15% | **9.2** | 1.38 |
| **Overall** | 100% | | **8.2 / 10** |

**Finding counts:** 0 CRITICAL · 6 HIGH · 25 MEDIUM · 28 LOW.

### Why 8.2 and not the prior audit's 9.6

The codebase did **not** lose 1.4 points in six days. Post-`2026-09-15` commits added **zero** new dependency-direction violations (mechanically re-tested: 1,438 edges) and `flutter analyze` is still clean under strict lints. The difference is that this pass (a) applies the broader definition of each dimension requested here — docs coverage, SOLID, wire-format placement, dead code, l10n completeness — where the prior pass scored import direction alone for architecture, and (b) independently re-ran every gate instead of inheriting them. One prior claim did not reproduce: **format-clean** (8 files fail `dart format` on the local toolchain — pure wrapping-style drift, see §3). The test count **is** confirmed: 1044/1044 pass on this tree (§7). Three genuinely new defects did accumulate since 09-15 from the l10n arc and the coupons feature (§3).

**The through-line:** every HIGH finding is a *silent dead-end path* — an error state emitted but never consumed (wishlist), an error code omitted so l10n precedence falls through to raw English (empty cart), a migration proposal that half-ships (coupon server side), an exception clause that structurally cannot catch what it will actually receive (`TypeError` vs `Exception`). Each is a branch no test pins. The second pattern is **half-applied refactors**: the ISP split stopped at the interface (impl still 824 lines), the l10n arc retired the English-only convention but missed one app-authored string, and the AUD-011 colour fix was plumbed but never read.

---

## 2. Maintainability — 8.0/10

Justification: exceptional hygiene in the mechanics of maintenance (zero TODO/FIXME/HACK in 29.8k LOC, why-comments everywhere, ~1:1 test parity, dated pubspec rationales, 548/548 ARB parity) undermined by the most-used abstraction in the codebase being undocumented and several actively-misdirecting leftovers.

| Sev | Finding | Location |
|---|---|---|
| HIGH | `Result`/`Success`/`Failure` — the codebase's most-used abstraction — have **no class-level docs**; dartdoc coverage 69.1%, gap concentrated in core types | `lib/core/error/result.dart:3,42,47` (verified) |
| MEDIUM | Colour/category vocabulary English-only in the shopper UI; `Product.colorName` mapped but never read — AUD-011's user-visible symptom persists | `filter_sheet.dart:121`, `product_mapper.dart:138` |
| MEDIUM | `catalogColorName` is dead code whose doc comment describes a design no code implements — actively misdirects the AUD-011 fix | `catalog_filters.dart:39-52` |
| MEDIUM | Two different `CatalogConstants` classes in one feature, both claiming "single source of truth" | `catalog_filters.dart:26`, `catalog_constants.dart:19` |
| MEDIUM | Invoice PDF is hardcoded English; the convention that justified it was retired by `56317cb` | `invoice_pdf_builder.dart:74-119` |
| MEDIUM | Same admin nav tile written 3×; admin port verbs mix `get*`/`fetch*` + redundant prefix | `admin_dashboard_page.dart:174` etc., `admin_reviews_port.dart:10` |
| LOW ×7 | Empty `lib/core/helper/`, dead `CatalogSortLabel.label`, test-only `@Deprecated` fns, port/impl basename collisions, non-uniform module shape, 391 LOC smoke scaffolding in `lib/`, address shim | see sections/maintainability.md |

**Done well:** zero TODO census; comments explain *rejected alternatives and invariants* (e.g. `catalog_filters.dart:94-96`); test parity ~1:1 (177 test files / 29.6k test LOC); pubspec rationales dated + approval-referenced; ARB parity exact with single-mapping label helpers.

## 3. Code quality — 8.0/10

Justification: the discipline behind the prior 10.0 is real (analyzer clean under strict lints, single `safe_parse` boundary, flawless Equatable — 42/42 `props` correct, no dead files, assets fully reconciled) but three real defects accumulated since 09-15 and the format gate is red.

Gates re-run fresh on `ef91836`: `flutter analyze` → **No issues found** (exit 0). `dart format --output=none --set-exit-if-changed lib` → **8/269 files fail** (`admin_customers_page`, `supabase_coupons_repository`, `catalog_sort_label`, `home_page`, `catalog_sort_bar`, `app_lock_gate`, `oauth_service`, `storage_service`). `git diff bed0d1c HEAD` is empty for all 8 → the files are untouched since the prior green gate, and a spot diff (`oauth_service.dart:52-55`) shows the disagreement is **pure line-wrapping style** (old-style wrapped argument lists vs the local pre-release formatter's joined lines) — toolchain version drift, not neglected files. Local toolchain is Dart 3.12.2 (Flutter 3.48.0-pre) vs CI pin 3.47.x; run format gates under the CI-pinned SDK to reconcile. `flutter test` — see §7 for how the sandbox was made to run it, and the result.

| Sev | Finding | Location |
|---|---|---|
| HIGH | **Wishlist failure renders as "nothing saved yet"** — `WishlistStatus.error` emitted at `wishlist_cubit.dart:97,189`, but `wishlist_page.dart:66-84` branches only on `products.isEmpty`; no error/retry UI anywhere | verified |
| HIGH | **Raw casts inside an `on Exception` boundary** — `rows as List<dynamic>?` (:33), `list.first as Map<String,dynamic>` (:37) throw `TypeError`, which is an `Error`, not an `Exception`; the `on Exception catch` (:56) structurally cannot catch it. Escapes to an unguarded checkout caller → "Apply coupon" silently does nothing | `supabase_coupons_repository.dart:33,37,56` (verified) |
| HIGH | **App-authored English reaches Arabic users on the empty-cart path** — `checkout_cubit.dart:217` emits `'Your cart is empty.'` with no `errorCode`; `checkout_page.dart:94-97` passes uncoded messages through verbatim by design ("uncoded = server-authored" — this one isn't) | verified |
| MEDIUM | Write-only error state: `details_page.dart:141`, `cart_page.dart:34` never read `errorMessage`; three cubit fields dead; two tests pin the dead English string | `product_details_cubit.dart:157,166` etc. |
| MEDIUM | Dead class `AdminReview` (`product_review.dart:32-57`, 0 readers — the only genuinely dead declaration in `lib/`) | verified |
| MEDIUM | 24 methods ≥100 lines; worst `build()` 257 lines (`home_page.dart:67-323`) | verified |
| MEDIUM | Three duplication clusters: catalog state-branching ×2 (byte-identical), auth failure listener ×3, admin error surface ×10 | see sections/code_quality.md |
| MEDIUM | `dart format` gate red (8 files, toolchain-disagreement) | §3 above |
| MEDIUM | `PendingOrder.status` is a raw `String` while `OrderStatus` enum exists; literal compare in domain | `pending_order.dart:23`, `place_checkout_order_usecase.dart:102` |
| LOW ×3 | InstaPay repeated guard/snackbar ×7; magic durations; smoke scaffolding | see sections/code_quality.md |

**Done well:** `safe_parse` consolidation held (single copy, enforced at every new boundary); strict lint set with *documented rejections*; Equatable flawless incl. deliberately-excluded memo fields; zero TODO/commented-out code; no dead files; assets fully reconciled.

## 4. Clean architecture — 7.5/10

Justification: the classic vertical rules are **genuinely clean** — mechanically re-tested across 266 files / 1,438 edges: presentation→data 0, domain→data 0, domain→presentation 0, core→feature 0, `package:flutter` in domain/core 0, cubits→data 0. Domain is Flutter-free; all 24 cubits are abstraction-only and navigation-free; DI is centralized (`getIt` in exactly 3 production files, zero in features). But the 10.0 was scoped to import direction alone; by the broader standard there is real structural erosion, and one domain dir imports a rendering framework.

| Sev | Finding | Location |
|---|---|---|
| HIGH | **Domain imports `package:pdf` + `dart:isolate`** — the only non-equatable 3rd-party import anywhere under `features/*/domain/` (predates the 09-15 audit) | `admin/domain/invoice/invoice_pdf_builder.dart:1-5` (verified) |
| HIGH | **`SupabaseAdminRepository` god-class** — 824 lines, 22 public methods, 7 concerns; the six-port ISP split stopped at the interface | `admin/data/supabase_admin_repository.dart:292` (verified: 824 lines) |
| MEDIUM | Row mapping in a core domain entity (`Profile.fromRow`/`toProfileRow`) — everywhere else lives in `data/` codecs | `core/entities/profile.dart:59,79` |
| MEDIUM | Server wire formats authored in `domain/` (address-snapshot JSON encoder, CSV exporter, raw `Map` in a port signature) | `place_checkout_order_usecase.dart:17`, `checkout_repository.dart:15`, `orders_csv_exporter.dart:8` |
| MEDIUM | 11 feature→feature internal imports, no barrels; `auth`↔`storefront` mutually coupled | `supabase_auth_session_port.dart:3` ↔ `storefront_persistence.dart:13` |
| MEDIUM | Six admin pages still on the 22-method facade; one runs the authorization check inside the widget, duplicating the router policy | `admin_catalog_page.dart:20,25-40` ↔ `app_router.dart:90-94` |
| MEDIUM | `app_router.dart` 374-line god-file: route table + auth policy + 48 `getIt` calls — a third composition root | `app_router.dart:115-374` |
| MEDIUM | `PaymentCubit` 443 lines, if-chain dispatch growing per payment method (OCP) | `payment_cubit.dart:149-155` |
| LOW ×4 | Concrete impl in domain dir; `BuildContext` in a shared port impl; duplicated `setMembershipTier`; dead `AdminReview` misplaced in storefront domain | see sections/clean_architecture.md |

**Done well:** 0 mechanical violations across 1,438 edges (the prior claim holds — not a stale repetition); domain Flutter-free; cubits never navigate; `view-layer DI` is real (removed `getIt` calls recorded in comments); genuine facade-over-narrow-ports ISP split at the interface; single `Result.guard` failure boundary.

## 5. Security — 8.5/10

Justification: the money boundary and privilege model are strong and verified — Paymob is server-authoritative end-to-end (amount from locked claim RPC, HMAC-SHA512 callback with constant-time compare, fail-closed 503, rate-limited before body parse, WebView locked to 3 exact hosts); clients cannot create or flip orders/payments (`orders` INSERT `WITH CHECK (false)`, admin flags locked on both self-write paths); no privileged secret in the tracked tree; PII at rest in secure storage with Sentry scrubbing. Deductions sit in the newest feature (coupons) and honest evidence gaps.

| Sev | Finding | Location |
|---|---|---|
| MEDIUM | **Coupon money path unproven** — client sends `p_coupon_code` (`checkout_service.dart:91`) but `056_coupons.sql:63-76` is reviewer-notes-only ("intentionally NOT inlined") and **no applied migration defines the parameter**. If live DB lacks it, valid coupons break `create_checkout_order` (PGRST202) or advertise a discount never applied. Needs a live-DB check (owner) | verified in-tree |
| MEDIUM | **Unauthenticated coupon oracle** — `GRANT EXECUTE … TO anon, authenticated` on `SECURITY DEFINER validate_coupon`, no rate limit, unlike every Edge Function | `056_coupons.sql:60-61` |
| MEDIUM | **Server-driven sign-out leaves PII on device** — `_listenToAuthChanges` clears only the profile; never calls the local-snapshot wipe used by explicit `signOut()`; encrypted address book + full shipping-address snapshots survive refresh-token revocation | `auth_cubit.dart:296-308` (verified) |
| MEDIUM | RLS unprovable on two externally-created tables: `notifications` (holds `recipient_email`) has no in-tree DDL; `analytics_events` policy in `053` is inert unless RLS was enabled out-of-band | `048_external_lineage.sql:5-7`, `053_analytics_events.sql:13-26` |
| LOW ×5 | `rate_limits` REVOKE-only; `allowBackup` defaults true; live keystore still in tree (`android/app/release-key.jks`, untracked); `search_path` style inconsistent; `app_config` world-readable | see sections/security.md |

**Prior-register status:** R1 migration 061 shipped ✅ · R6 partial (keystore in tree) · R7 waived in writing · R10 in-tree closed (placeholders verified: staging 29-char, prod 32-char, DSN 34-char; zero `eyJ` tokens tracked).

**Done well:** server-authoritative Paymob with HMAC + constant-time compare + fail-closed secrets; client can't mutate orders/payments/status; escaped PostgREST `or`-tree injection in customer search; formula-injection-safe CSV export; PII-at-rest + telemetry scrubbing; no privileged credential anywhere tracked.

## 6. Performance — 9.2/10

Justification: all four claimed perf commits verified landed and correctly scoped (width-bounded render URLs on every surface; one-year cache on upload; image-manager grid bounds; threshold-gated isolate compute). No HIGH remains; two MEDIUMs are sized by arithmetic, and several suspects were explicitly cleared (admin phone search is server-side/debounced/keyset-paged, not O(n²); no N+1; no `select('*')`; PDF on `Isolate.run`).

| Sev | Finding | Location |
|---|---|---|
| MEDIUM | Every `AppImage` takes an unconditional `MediaQuery` dependency → grid rebuilds per frame of IME/inset animation, though cards pass explicit `cacheWidth: 420` | `shared/components/app_image.dart:57` |
| MEDIUM | Grid (420) and detail (720) renders of the same photo are two cache keys → redundant fetch + decoded bitmap per product opened (≈2 MiB each; 100-product pass ≈67 MiB vs the 100 MiB `ImageCache` cap) | `product_mapper.dart:93-113` + `storage_service.dart:126-139` |
| LOW ×9 | `PricingTierTable` re-sorts a 2-element ladder per build; `DateFormat` per row per build ×4; `CatalogFilters.matches` re-trims per product; one dynamic non-builder `ListView` (`addresses_page.dart:45-71`); wishlist build-scheduled side effect; admin builders missing `buildWhen`; non-memoized `AdminState.filteredOrders`; full-res local-asset branch | see sections/performance.md |

**Done well:** complete P0-4 pipeline with named `StorageService` budgets; fully-memoized `CatalogState` derived views; flash countdown on a stream, not state; keyset paging + server-side count + debounced search; invoice PDF on `Isolate.run`.

## 7. Harness / verification appendix

| Gate | Result here | Note |
|---|---|---|
| `flutter analyze` | ✅ No issues found | independently re-run |
| `dart format` (check) | ❌ 8 files change | pure line-wrapping drift; local Dart 3.12.2 vs CI pin 3.47.x — reconcile under the CI toolchain |
| `flutter test` | ✅ **1044/1044 passed** (2m21s) | after fixing the sandbox launcher (below); claim independently confirmed |
| Secret sweep | ✅ no privileged key tracked | anon/prod/DSN values verified as placeholders |

**Sandbox note (reproducibility):** the WorkBuddy sandbox exports `HTTP(S)_PROXY=http://127.0.0.1:<port>` with no `NO_PROXY` and no `PROGRAMFILES(X86)`, which breaks the Flutter test runner twice (missing env var; the proxy hijacks `flutter_tester`'s localhost WebSocket handshake → `Invalid WebSocket upgrade request`). Working invocation:

```
env 'NO_PROXY=localhost,127.0.0.1' 'no_proxy=localhost,127.0.0.1' \
    'PROGRAMFILES(X86)=C:\Program Files (x86)' flutter test --reporter compact
```

**Reproduction commands:** `flutter analyze` · `dart format --output=none --set-exit-if-changed lib` (under the CI-pinned SDK) · the test command above · live-DB: `select proname, pg_get_function_arguments(oid) from pg_proc where proname='create_checkout_order'` (does it accept `p_coupon_code`?) · `select * from pg_policies where tablename in ('notifications','analytics_events')` + `select relname, relrowsecurity from pg_class where relname in ('notifications','analytics_events')`.

## 8. Prioritized roadmap

**P0 — this week (each ≤ 1 hour)**
1. Wishlist error branch: consume `WishlistStatus.error` → error `FeedbackView` + retry (`wishlist_page.dart:66`).
2. Harden coupons repo: `List.cast<Map<String,dynamic>>()`/`whereType` instead of raw casts; replace `on Exception` with the project's bare-`catch` `Result.guard` convention (`supabase_coupons_repository.dart:28-59`).
3. Empty-cart copy: add `kCartEmptyCode` + ARB key; pass `code:` at `checkout_cubit.dart:217`.
4. Sign-out wipe: extract the explicit-`signOut` local-wipe into a shared private method; call it from the `signedOut` listener (`auth_cubit.dart:301`).
5. Reconcile format gate: run `dart format` under the CI-pinned toolchain; commit or document the 8 files.

**P1 — this sprint (1–3 days each)**
6. Live-DB coupon verification (owner): confirm `p_coupon_code` exists on the live `create_checkout_order`; if not, ship the `056` delta or gate the client param behind a flag. Add rate limiting to `validate_coupon`.
7. Move `invoice_pdf_builder.dart` to `admin/data/`; split `SupabaseAdminRepository` into six per-port impls; relocate `Profile.fromRow` to a data mapper.
8. Consume the three write-only `errorMessage` fields (or delete them + unpin the two tests); delete dead `AdminReview` and `catalogColorName`; document `Result`/`Success`/`Failure`.
9. Enable RLS / add DDL evidence for `notifications` + `analytics_events`; set `allowBackup=false`.

**P2 — next sprint**
10. Barrels for cross-feature imports (break `auth`↔`storefront`); slim `app_router.dart`; dedupe admin nav tile + admin error surface ×10; `products.color_name` schema decision (closes AUD-011); unify 420/720 image cache keys; scope `AppImage`'s `MediaQuery`; move keystore out of the tree.

## 9. Strengths worth preserving

- **Dependency discipline that survives mechanical testing** — 0 violations / 1,438 edges; Flutter-free domain; navigation-free, abstraction-only cubits; centralized DI.
- **Server-owned money path** — Paymob HMAC, constant-time compare, fail-closed secrets, rate-limited callbacks, client-side amount tampering impossible by design.
- **RLS privilege model** — customers cannot create or mutate orders, payments, or admin flags.
- **Secrets & PII hygiene** — no privileged credential tracked; secure-storage-at-rest with migrations; Sentry scrubbing with PII off.
- **Maintenance mechanics** — zero TODOs, why-comments, ~1:1 test parity, dated pubspec rationales, exact ARB parity, flawless Equatable, single `safe_parse` boundary.
- **Perf engineering as a habit** — named byte budgets, memoized catalog state, isolate-based PDF, width-bounded image URLs.
