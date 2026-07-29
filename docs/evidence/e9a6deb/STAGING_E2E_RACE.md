# Staging E2E — Race / Concurrency

Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Authorization: STAGING-E2E-E9A6DEB-2026-07-28 (staging only, disposable fixtures)

Result: BLOCKED — callback-driven race tests depend on a mapped payment, which
cannot be created (see STAGING_E2E_PAYMOB.md).

## RACE-1 — Concurrent duplicate success callbacks — BLOCKED
Requires an initiated payment with a real provider order id. Blocked by the
`paymob-initiate` HTTP 500. Exactly-once success + single stock effect are
enforced by `process_paymob_callback` terminal-state idempotency (migration 014);
executable staging confirmation deferred to PACKAGE M.

## RACE-2 — Concurrent COD confirmation — DEFERRED
Independent of Paymob, but not executed as a discrete concurrent probe in this
run (harness exited after the initiation block). The sequential idempotency guard
is verified in STAGING_E2E_COD.md (COD-2: second confirm → `already_confirmed`,
single payment row, no extra stock movement). A discrete two-parallel-confirm
probe is queued for the PACKAGE M re-run.

## Callback-vs-expiry — BLOCKED
Requires an initiated payment. Blocked as above; deferred to PACKAGE M.
