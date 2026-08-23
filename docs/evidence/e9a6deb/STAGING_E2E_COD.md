# Staging E2E — COD Matrix

Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Authorization: STAGING-E2E-E9A6DEB-2026-07-28 (staging only, disposable fixtures)

Result: PASS — 5 scored / 5 passed / 0 failed / 2 N/A-by-design

Fixture: product `bbbb0003-0001-0001-0001-000000000003`, variant
`35f2e5e1-ce84-45de-9de5-cabd776a8118` (size 1m, color Cream, unit 69000).
All test users/orders/payments are disposable staging data.
JWTs and Authorization headers are never printed by the harness.

## COD-1 — Happy path — PASS
- order `aecda300-543b-41a5-bbf5-4f0e4339e628`
- create_checkout_order (cash_on_delivery, qty 2): HTTP 200, total 138000
- order status after create: pending
- stock before 14 → after create 12 (decremented by 2 at create)
- confirm_cod_payment: `code=confirmed`, `ok=true`
- order status after confirm: paid; payment status: success; method: cash_on_delivery
- stock after confirm: 12 (confirm does NOT re-decrement)
- transaction id present: true

## COD-2 — Idempotency — PASS
- second confirm_cod_payment: `code=already_confirmed`, `ok=true`
- payment row count: 1 (no duplicate); payment status: success
- stock unchanged (12)

## COD-3 — Non-owner — PASS
- attacker user `5b97b1d1-8ba4-4cf9-b241-134640549c64` confirm on victim order
- `code=not_owner`, `ok=false`; victim order status unchanged: paid

## COD-4 — Anonymous — PASS
- order `3e012019-9ce6-4b2f-8169-a888e1e3cffb`
- anonymous confirm_cod_payment: HTTP 401, SQLSTATE `42501` (permission denied)
- order status unchanged: pending (no state change)

## COD-5 — Non-COD order — PASS
- order `8e27112e-c404-40b6-8f2f-4c584c081f72`, method paymob_card
- confirm_cod_payment: `code=payment_not_cod`, `ok=false`
- order status unchanged: pending (no state change)

## COD-6 — Terminal-state (order_not_pending) — N/A_BY_DESIGN
No client-only path cancels a COD order (cancellation requires service-role or
the 15-min expiry sweep). The pending guard is covered by the paid-idempotency
branch (COD-2) and code review of migration 018.

## COD-7 — Missing payment row (payment_not_found) — N/A_BY_DESIGN
`confirm_cod_payment` creates the COD payment row when absent (migration 018),
so `payment_not_found` is unreachable by design. Direct client payment INSERT is
prohibited and denied by RLS (payments has no INSERT policy).
