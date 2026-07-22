# Post-Audit Local Repair — Evidence

Branch: `fix/post-audit-production-repair`
Environment: Flutter 3.44.4 · Dart 3.12.2 · channel stable (Windows)

This document records the post-audit repairs that were **executed and proven
locally**. It deliberately separates what was implemented, what was locally
verified, and what remains **NOT VERIFIED / STAGING-BLOCKED** for a follow-up
backend pass. The five backend security items from the repair prompt
(idempotent stock restoration, notification constant-time auth, revoking
public `EXECUTE` on `process_paymob_callback`, Paymob HMAC algorithm/config
confirmation, and live atomic-checkout verification) were **out of scope** for
this pass — they need Deno + a disposable Postgres + staging + the Paymob
merchant dashboard.

---

## Final gate results (all green)

| Gate | Command | Result |
|------|---------|--------|
| Format | `dart format --output=none --set-exit-if-changed .` | `Formatted 183 files (0 changed)` — exit 0 |
| Analyze | `flutter analyze` | `No issues found! (ran in 6.5s)` |
| Tests | `flutter test` | `+223: All tests passed!` |

Test count moved from 212 (audit baseline) to **223** with the 11 new tests
added below.

---

## Fix 1 — dart format gate (VERIFIED)

- **Implemented:** ran `dart format .` across the repo.
- **Output:** `Formatted 183 files (37 changed)`, then a re-check reported
  `183 files (0 changed)` with exit code 0.
- **Locally verified:** the CI `dart format --set-exit-if-changed` gate now
  passes.

## Fix 2 — Supabase product-image mapping (VERIFIED mapping; render STAGING-BLOCKED)

- **Implemented** in `lib/features/storefront/data/supabase_catalog_repository.dart`:
  - Extended the PostgREST select to embed
    `product_images(storage_path, is_primary, sort_order)`.
  - Refactored `_mapProduct` to resolve image URLs (primary first, then by
    `sort_order`, blank paths skipped) and set `Product.imageAsset` (primary)
    and `Product.images` (gallery).
  - Injected `String Function(String storagePath) publicUrlFor` (production
    defaults to the `product-images` bucket public URL) and exposed
    `@visibleForTesting debugMapProduct` so the mapping is unit-testable
    without a live client.
- **Locally verified:** `test/supabase_catalog_mapping_test.dart` — 5 tests
  (primary→imageAsset, sort_order fallback, null when no images, blank path
  ignored, variant sizes/colors/stock). All pass.
- **NOT VERIFIED / STAGING-BLOCKED:** real on-device image rendering. Seed
  migration `016` inserts **zero** `product_images` rows and no assets are
  uploaded to the `product-images` bucket, so end-to-end rendering requires a
  human-reviewed seed/migration plus uploaded assets on staging.

## Fix 3 — Support page dead buttons (VERIFIED)

- **Implemented** in `lib/features/support/presentation/pages/support_pages.dart`:
  - `SupportPage` now renders channels from `SupportRepository.getChannels()`
    (injectable for tests, defaults to `getIt<SupportRepository>()`).
  - WhatsApp/email tiles copy their value to the clipboard and show a
    confirmation snackbar (clipboard fallback — **no `url_launcher`
    dependency added**).
  - FAQ tile navigates to a new in-app `FaqPage` via a new `/faq` `GoRoute`
    (added to `publicRoutes`); FAQ content is fully local (l10n).
  - New l10n keys added to `app_en.arb` / `app_ar.arb` (`copiedToClipboard`
    plus four FAQ Q&A pairs); localizations regenerated.
- **Locally verified:** `test/support_page_actions_test.dart` — 4 tests assert
  every tile performs a real action (clipboard write captured via a mocked
  `SystemChannels.platform` handler, snackbar shown, FAQ navigation). No
  `// TODO`-only handler remains.

## Fix 4 — Admin catalog dead buttons (VERIFIED)

- **Implemented** in `lib/features/admin/presentation/pages/admin_catalog_page.dart`:
  - Wired the "Variants & stock" tile to the existing `/admin/inventory`
    route.
  - Removed the three tiles with no backing implementation (Products,
    Categories, Product images) since admin CRUD is deferred post-MVP.
- **Locally verified:** `test/admin_catalog_page_test.dart` — 2 tests assert a
  single tile remains, the dead tiles are gone, and the remaining tile
  navigates. No `// TODO`-only handler remains.

## Fix 5 — CI branch + version alignment (INSPECTION-ONLY)

- **Implemented** in `.github/workflows/ci.yml`:
  - Added `master` to `push.branches` (`[main, master, develop]`) and
    `pull_request.branches` (`[main, master]`).
  - Aligned every `flutter-version` pin from `3.24.x` to `3.44.x` (5 jobs) to
    match the local toolchain.
- **NOT VERIFIED here:** CI cannot be executed in this environment. Verified by
  inspection only; an actual green run is a follow-up gate.

## Fix 6 — Documentation reconciliation (VERIFIED by re-count)

- **README.md:**
  - Corrected the persistence note — catalog and orders are Supabase-backed
    (`SupabaseCatalogRepository`; `SupabaseOrdersRepository` in release,
    local in debug), not "local mock" with "Supabase repos removed".
  - Fixed "14 numbered migrations" → **19 numbered** (24 SQL files total incl.
    test/verify).
  - Documented the `supabase/functions/checkout` decision: **backend-only /
    reserved** — the client checks out via the `create_checkout_order` RPC
    directly, and `checkout` is kept deployed and CI-verified for
    server-side/administrative use.
- **STATE.md:**
  - Updated test count to **223/223** (both the noise line and the run table).
  - Removed the stale "17 outdated packages / major bumps pending" item — the
    majors are already applied in `pubspec.yaml` (`flutter_dotenv ^6.0.1`,
    `flutter_lints ^6.0.0`, `get_it ^9.2.1`, `go_router ^17.3.0`).
  - Reconciled the "project is clean" claim with the active repair branch and
    its uncommitted working tree, and recorded the STAGING-BLOCKED backend
    items on the watch list.

---

## NOT VERIFIED / STAGING-BLOCKED (deferred to a backend L2 pass)

The following require Deno + a disposable Postgres + staging + the Paymob
merchant dashboard and were **not** attempted this pass:

1. Idempotent stock restoration on order cancellation/expiry.
2. Constant-time auth comparison in the order-notification function.
3. Revoking public `EXECUTE` on `process_paymob_callback`.
4. Confirming the Paymob HMAC algorithm and configuration against live keys.
5. Live verification of the atomic `create_checkout_order` checkout path.

Additionally, real product-image rendering (Fix 2) is staging-blocked pending a
reviewed seed for `product_images` and uploaded bucket assets.

## New / changed files this pass

- `lib/features/storefront/data/supabase_catalog_repository.dart` (Fix 2)
- `lib/features/support/presentation/pages/support_pages.dart` (Fix 3)
- `lib/features/admin/presentation/pages/admin_catalog_page.dart` (Fix 4)
- `lib/shared/routing/app_router.dart` (Fix 3 — `/faq` route)
- `l10n/app_en.arb`, `l10n/app_ar.arb` (+ regenerated `lib/generated/l10n/`) (Fix 3)
- `.github/workflows/ci.yml` (Fix 5)
- `README.md`, `STATE.md` (Fix 6)
- Tests: `test/supabase_catalog_mapping_test.dart`,
  `test/support_page_actions_test.dart`, `test/admin_catalog_page_test.dart`
- Repo-wide `dart format` (Fix 1)

_No changes were made to `supabase/` migrations, `payments/`, `auth/`, `.env*`,
or secrets. No push/merge/deploy was performed._
