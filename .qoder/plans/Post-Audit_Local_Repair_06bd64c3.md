# Post-Audit Local Repair

## Summary
Implement only the audit blockers that can be **executed and proven** in this environment (Flutter code, CI YAML, docs), on a fresh branch `fix/post-audit-production-repair`. Every change is validated by `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test`. The five backend security items from the pasted prompt (idempotent stock restoration, notification constant-time auth, revoke public EXECUTE on `process_paymob_callback`, Paymob HMAC algorithm/config confirmation, live atomic-checkout verification) are **out of scope for this pass** — they need Deno + disposable Postgres + staging + the Paymob merchant dashboard, so they will be recorded as **NOT VERIFIED / STAGING-BLOCKED** for a follow-up backend L2 pass.

## Approvals Required (human-gated per AGENTS.md)
- **CI workflow edits** (`.github/workflows/ci.yml`).
- **Adding `url_launcher` to `pubspec.yaml`** (needed to actually launch WhatsApp/email). Fallback with no dependency = copy-to-clipboard.
- **Not touched this pass:** `supabase/` migrations, `payments/`, `auth/`, `.env*`, `secrets/`. No push/deploy.

## Fix 1 — dart format gate (VERIFIABLE)
- Run `dart format .` to reformat the 36 drifted files (mostly `test/*`, a few `lib/*`). No logic changes.
- **Acceptance:** `dart format --output=none --set-exit-if-changed .` exits 0.

## Fix 2 — Supabase product images (Dart mapping; render NOT VERIFIED)
- In `lib/features/storefront/data/supabase_catalog_repository.dart`: extend the PostgREST select to embed `product_images(storage_path, is_primary, sort_order)`; in `_mapProduct`, pick the primary (or lowest `sort_order`) image and set `Product.imageAsset` to its public Storage URL.
- Make it testable without a live client: refactor `_mapProduct` to accept an injected `String Function(String storagePath) publicUrlFor` (production passes `client.storage.from('product-images').getPublicUrl`). `ProductImagePlaceholder` already renders remote URLs, so no widget change.
- Add a unit test feeding a fake product row (with `product_images`) and asserting the mapped `imageAsset` equals the expected public URL, and that absence of images falls back to `imageColor`.
- **Explicit limitation:** seed migration `016` inserts **zero** `product_images` rows, so real on-device images still require (a) a human-reviewed seed/migration to populate `product_images` and (b) uploaded assets in the `product-images` bucket on staging. Those are flagged as follow-ups; **rendered images = NOT VERIFIED** here.
- **Acceptance:** new mapping test passes; analyze clean.

## Fix 3 — Support page dead buttons (VERIFIABLE)
- Inject `SupportRepository` into `SupportPage` and render channels from `getChannels()` instead of hardcoded tiles.
- FAQ → navigate to a new in-app `FaqPage` (new `GoRoute` `/faq`, content from l10n) — fully local.
- WhatsApp/email → **recommended:** add `url_launcher` and launch `wa.me` / `mailto:`. **Fallback (no dep):** copy value to clipboard with a confirmation snackbar. No `onTap` may be a no-op.
- Add a widget test asserting every support tile performs a real action (navigation/launch/clipboard), no empty `onTap`.
- **Acceptance:** test passes; no `// TODO`-only handlers remain in `support_pages.dart`.

## Fix 4 — Admin catalog dead buttons (VERIFIABLE)
- In `admin_catalog_page.dart`: wire the "Variants & stock" tile to the existing `/admin/inventory` route; remove the three tiles with no backing implementation (Products, Categories, Product images) since admin CRUD is deferred post-MVP.
- Add/extend a widget test asserting the remaining tile navigates and no no-op tiles remain.
- **Acceptance:** test passes; no `// TODO`-only handlers remain in `admin_catalog_page.dart`.

## Fix 5 — CI branch + version alignment (INSPECTION-ONLY; needs approval)
- `.github/workflows/ci.yml`: add `master` to `push.branches` and `pull_request.branches` (or the active branch strategy you choose).
- Align `flutter-version` with local (`3.44.x` or an agreed pin) across jobs.
- **Cannot run CI here** → verified by inspection only; actual green run is a follow-up gate.

## Fix 6 — Documentation reconciliation (VERIFIABLE by re-count)
- `README.md`: correct the note claiming catalog/orders are local mocks and "Supabase repos removed" — both `SupabaseCatalogRepository` and `SupabaseOrdersRepository` are wired; fix "14 numbered migrations" → **19 numbered** (24 SQL files incl. test/verify); update the deploy function list.
- `STATE.md`: update test count to **212**, remove the stale "17 outdated packages / pending major bumps" (already applied in `pubspec.yaml`), and reconcile "project is clean" with the current uncommitted working tree.
- Document the decision on `supabase/functions/checkout` (unused by client, which calls the RPC directly): keep-as-reserved-and-documented, or remove + update CI `deploy-check`. Recommended: document as backend-only/reserved.

## Test Plan (run after each fix + final)
1. `dart format --output=none --set-exit-if-changed .` → exit 0.
2. `flutter analyze` → "No issues found".
3. `flutter test` → all existing 212 tests plus the new mapping/support/admin tests pass.
4. Capture exact command output into `docs/post-audit-repair-evidence.md`, separating **Implemented** vs **Locally verified**, and listing the deferred backend items as **NOT VERIFIED / STAGING-BLOCKED**.

## Assumptions
- Working on branch `fix/post-audit-production-repair`; no push/merge/deploy.
- Backend security items (prompt sections 1–5) are a separate, later pass requiring Deno/Postgres/staging/merchant-dashboard access.
- `url_launcher` addition and CI edits proceed only after your approval; otherwise the clipboard fallback (Fix 3) and inspection-only CI note (Fix 5) apply.