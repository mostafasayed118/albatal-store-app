# Al Batal Elite — Code Quality Audit — Scope Inventory (Baseline)

- **Date:** 2026-09-15
- **Baseline commit:** `5ef935c` (branch `master`) — note: working tree was dirty at audit start; the dirty-tree state is itself recorded as finding MNT/QLT context in the report. Audit verdicts cite committed sources.
- **Toolchain:** Flutter 3.48.0-1.0.pre-57 (stable), Dart 3.12.2, Windows x64.

## Verification commands (established)

| Purpose | Command | Baseline result |
|---|---|---|
| Static analysis / lint | `flutter analyze` | exit 1 — 4 warnings (`unused_import` ×4, all in `test/features/admin/data/admin_customer_directory_test.dart`) |
| Test suite | `flutter test` | running at baseline freeze (log: `.openclaw/tmp/audit/baseline/test_full.txt`) |
| Format check | `dart format --set-exit-if-changed --output=none lib test` | recorded during verification phase |
| Build (smoke) | `flutter build apk --debug` or platform-specific | recorded during verification phase |
| Dependency scan | `flutter pub deps --json`, `flutter pub outdated` | recorded during verification phase |

## First-party source inventory

### Application code (`lib/` — 255 files, 29,447 lines)

| Area | Files | Lines | Purpose |
|---|---|---|---|
| `lib/features/storefront` | 97 | 9,147 | Catalog, product detail, cart, checkout, orders (customer storefront) |
| `lib/features/admin` | 37 | 5,181 | Admin console: catalog mgmt, customers, orders, image manager |
| `lib/shared` | 53 | 4,731 | Theme, routing (GoRouter), components (incl. stitch kit), services (storage, biometric, share, deep links) |
| `lib/features/payments` | 10 | 1,987 | Paymob card, InstaPay, COD; payment service + cubit |
| `lib/features/auth` | 13 | 1,385 | Sign in/up, profile, session cubit |
| `lib/features/settings` | 7 | 685 | Settings page, notifications, app-lock settings |
| `lib/features/onboarding` | 6 | 546 | First-run onboarding flow |
| `lib/core` | 11 | 504 | Error/result taxonomy, config/env, logging, address codec |
| `lib/features/addresses` | 5 | 362 | Address book |
| `lib/features/support` | 9 | 257 | Support/WhatsApp contact |
| `lib/generated` | 3 | 4,212 | Generated l10n (committed to git; tracked) |
| Entry points | 4 | — | `main.dart`, `bootstrap.dart`, `app.dart`, `main_smoke.dart` |

### Backend (`supabase/`)

- `migrations/`: **59 SQL migration files** (first-party; policy/DDL review in scope for security dimension, read-only)
- `functions/`: Supabase edge functions incl. `_shared/secrets.ts` (first-party)
- `tests/`, `scripts/`: first-party helpers

### Tests (`test/` — 169 files, 22,003 lines)

- Mirrors `lib/` feature layout; includes `catalog_perf_test.dart` (performance regression harness).

### Platform & config

- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` — platform shells
- `analysis_options.yaml` — flutter_lints 6 + curated rule set (see rubric appendix)
- `pubspec.yaml` — 30 runtime dependencies, version-pinned ranges; `http: any` flagged
- `l10n/` — EN/AR ARB sources (bilingual app)
- `.github/workflows/` — CI (do not modify without approval)

## Exclusions from scoring (per audit brief)

- `build/`, `.dart_tool/`, `coverage/`, lockfiles (`pubspec.lock`, `package-lock.json`, `deno.lock`)
- `node_modules/`, `skills/`, `.openclaw*`, `.trees/`, `.superpowers/`, agent/IDE dot-directories
- `lib/generated/**` — generated l10n (scored only for hygiene of how it is consumed)
- `stitch_al_batal_fabric_e_commerce/`, `projects/`, `outputs/`, `evidence/` — design/source-of-truth artifacts, not shipping code
- Platform shells (`android/…`, `ios/…` etc.) — scored only where first-party code interacts unsafely (manifest, gradle, plist)

## Secrets-surface check at baseline (no values printed)

- Tracked env files: only `.env.example` (template) — `.env`, `.env.production`, `.env.staging`, `secrets-*.env` are **untracked and gitignored** ✔
- Keystores `release-key.jks` / `release-keystore.jks` exist **on disk only**; not tracked (`*.jks` ignored) ✔
- `supabase/functions/_shared/secrets.ts` is tracked — reviewed by security dimension for embedded values
