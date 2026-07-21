# Release Readiness Checklist

## Code Quality
- [x] `flutter analyze` — 0 errors, 0 warnings
- [x] `flutter test` — test suite across 22 test files passing
- [x] No hardcoded secrets in source code
- [x] `.env` files gitignored (verified via `git log`)
- [x] All widgets follow one-public-widget-per-file rule
- [x] Clean Architecture maintained (presentation → domain → data)

## Database
- [x] 14 SQL migrations created and ordered (001–014)
- [x] RLS policies on all user-facing tables
- [x] Admin role for catalog/order management
- [x] Order creation protected (server-side RPC `create_checkout_order`, migration 013)
- [x] Stock functions (decrement, increment) with transaction safety
- [x] Shipping zones for Egyptian governorates

## Payments
- [x] Paymob: server-side auth, order, payment key (Edge Functions)
- [x] Paymob: webhook with HMAC verification, idempotent
- [x] Cash on Delivery: order creation flow
- [x] Payment failure restores stock
- [x] Duplicate callback protection

## Authentication
- [x] Email/password sign up with verification
- [x] Sign in with session restore
- [x] Password reset flow
- [x] Profile auto-creation via database trigger
- [x] Guest browsing (no sign-in required)

## Admin
- [x] Dashboard with order stats
- [x] Order queue with status filters
- [x] Order detail with fulfillment actions
- [x] Status transitions: placed → processing → shipped → delivered
- [x] Low stock alerts
- [x] Stock editing
- [x] Admin role protection

## Notifications
- [x] Email notification Edge Function
- [x] Templates for 6 order events
- [x] Server-side triggered (not from app)

## Monitoring
- [x] Analytics funnel tracking
- [x] Error logging to Supabase
- [x] Payment failure reporting

## Localization
- [x] 260+ keys in English and Arabic
- [x] RTL support verified
- [x] All checkout/auth/payment strings translated

## Environment
- [x] `.env.staging` template created
- [x] `.env.production` template created
- [x] `.env.example` for new developers
- [x] `.gitignore` covers all env files

## Documentation
- [x] README.md updated with full setup guide
- [x] DESIGN.md design system reference
- [x] `docs/foundation-walkthrough.md` — settings, theme, and locale foundation
- [x] `docs/storefront-walkthrough.md` — architecture docs
- [x] `docs/money-walkthrough.md` — `Money` minor-units value object
- [x] `docs/supabase-integration.md` — Supabase setup
- [x] `docs/staging-verification.md` — verification checklist
- [x] `docs/acceptance-checklist.md` — test cases
- [x] `supabase/migrations/verify_rls.sql` — RLS verification queries

## Pre-Launch Manual Steps
1. Create staging Supabase project
2. Run all 14 numbered SQL migrations in order
3. Deploy the 8 Edge Functions required by the enabled payment and notification flows
4. Fill in `.env.staging` with real credentials
5. Run RLS verification queries as non-admin
6. Execute acceptance checklist on real devices
7. Fix any P0/P1 issues found
8. Create production Supabase project
9. Deploy to production
10. Invite 10-20 beta users
