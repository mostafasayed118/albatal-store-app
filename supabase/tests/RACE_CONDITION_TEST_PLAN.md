# Race Condition Test Plan — Payment/Order/Stock State Machine

## Migration 025: Race-Safe State Machine

### Executive Summary

This document defines the test plan for validating the race-safe payment/order/stock state machine introduced in Migration 025. The core vulnerability was that `process_paymob_callback` only checked `payment.status` for idempotency, not `order.status`. This allowed a late-arriving success callback to silently no-op on the UPDATE while returning `ok:true, code:success` — misreporting the outcome.

---

## 1. State Transition Diagram

### Order States

```
pending ──callback(success)──► paid ──admin──► processing ──admin──► shipped ──admin──► delivered
   │                            │
   │ callback(fail)/expire      │ admin
   │                            ▼
   ▼                        cancelled
cancelled ◄──────────────────────┘
(terminal)                    (terminal)
```

### Payment States

```
pending ──callback(success)──► success (terminal)
   │
   │ callback(fail)
   ▼
failed (terminal)

pending ──expire──────────► expired (terminal)
```

### Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| I1 | Terminal states coherent across orders/payments/stock | Dual-guard in all RPCs |
| I2 | Lock canonical rows in deterministic order | payment FOR UPDATE → order FOR UPDATE |
| I3 | Success only while order AND payment eligible | `process_paymob_callback` checks both |
| I4 | Late success rejected without marking payment | `already_processed` return |
| I5 | Stock restored exactly once | `stock_restorations` ledger + `order_items.restored` trigger |
| I6 | Duplicate callbacks are safe no-ops | Idempotency guard on payment.status |
| I7 | All transitions auditable | `state_transitions` table + triggers |

---

## 2. Test Cases

### T-RC01: Callback Before Expiry (Happy Path)

| Field | Value |
|-------|-------|
| **ID** | T-RC01 |
| **Priority** | High |
| **Category** | Happy Path |
| **Setup** | Create pending order (expires_at = now + 15min) |
| **Action 1** | Call `process_paymob_callback(success)` |
| **Action 2** | Call `expire_pending_order()` |
| **Expected** | Action 1: `code=success`. Action 2: `code=already_terminal` |
| **Assert: order** | `status = 'paid'` |
| **Assert: payment** | `status = 'success'` |
| **Assert: stock** | Not restored (success path doesn't restore) |

### T-RC02: Expiry Before Callback (THE BUG FIX)

| Field | Value |
|-------|-------|
| **ID** | T-RC02 |
| **Priority** | Critical |
| **Category** | Race Condition |
| **Setup** | Create pending order (expires_at = now - 1min) |
| **Action 1** | Call `expire_pending_order()` |
| **Action 2** | Call `process_paymob_callback(success)` |
| **Expected** | Action 1: `code=expired`. Action 2: `code=already_processed` |
| **Assert: order** | `status = 'cancelled'` (NOT promoted to paid) |
| **Assert: payment** | `status = 'expired'` (NOT marked success) |
| **Assert: stock** | Restored exactly once |
| **Assert: audit** | `late_callback_rejected` record exists |

### T-RC03: Duplicate Callback

| Field | Value |
|-------|-------|
| **ID** | T-RC03 |
| **Priority** | High |
| **Category** | Idempotency |
| **Setup** | Create pending order |
| **Action 1** | Call `process_paymob_callback(success)` |
| **Action 2** | Call `process_paymob_callback(success)` again |
| **Expected** | Action 1: `code=success`. Action 2: `code=already_processed` |
| **Assert: stock** | Not double-restored |

### T-RC04: Double Expiry

| Field | Value |
|-------|-------|
| **ID** | T-RC04 |
| **Priority** | High |
| **Category** | Idempotency |
| **Setup** | Create pending order (expires_at = now - 1min) |
| **Action 1** | Call `expire_pending_order()` |
| **Action 2** | Call `expire_pending_order()` again |
| **Expected** | Action 1: `code=expired`. Action 2: `code=already_terminal` |
| **Assert: stock** | Restored exactly once |
| **Assert: stock_restorations** | Exactly 1 row |

### T-RC05: Callback Success Then Admin Cancel

| Field | Value |
|-------|-------|
| **ID** | T-RC05 |
| **Priority** | Medium |
| **Category** | Admin Interaction |
| **Setup** | Create pending order |
| **Action 1** | Call `process_paymob_callback(success)` |
| **Action 2** | Call `update_order_status('cancelled')` |
| **Expected** | Order transitions `pending → paid → cancelled` |
| **Assert: order** | `status = 'cancelled'` |
| **Assert: stock_restorations** | 1 row (admin cancel restores) |

### T-RC06: Admin Cancel Then Late Callback

| Field | Value |
|-------|-------|
| **ID** | T-RC06 |
| **Priority** | High |
| **Category** | Race Condition |
| **Setup** | Create pending order |
| **Action 1** | Call `update_order_status('cancelled')` |
| **Action 2** | Call `process_paymob_callback(success)` |
| **Expected** | Action 2: `code=already_processed` |
| **Assert: order** | `status = 'cancelled'` (NOT promoted to paid) |
| **Assert: payment** | `status = 'pending'` (NOT marked success) |

### T-RC07: Amount Mismatch

| Field | Value |
|-------|-------|
| **ID** | T-RC07 |
| **Priority** | High |
| **Category** | Security |
| **Setup** | Create pending order (total=10000) |
| **Action** | Call `process_paymob_callback(amount=9999)` |
| **Expected** | `ok=false, code=amount_mismatch` |
| **Assert: order** | `status = 'pending'` |
| **Assert: payment** | `status = 'pending'` |

### T-RC08: Stock Ledger — Cancel Restores Once

| Field | Value |
|-------|-------|
| **ID** | T-RC08 |
| **Priority** | High |
| **Category** | Stock Integrity |
| **Setup** | Create pending order, decrement stock |
| **Action 1** | `expire_pending_order()` |
| **Action 2** | `expire_pending_order()` (double) |
| **Assert: stock** | Restored exactly once |
| **Assert: stock_restorations** | 1 row |

### T-RC09: Stock Ledger — Callback-Fail Restores Once

| Field | Value |
|-------|-------|
| **ID** | T-RC09 |
| **Priority** | High |
| **Category** | Stock Integrity |
| **Setup** | Create pending order, decrement stock |
| **Action 1** | `process_paymob_callback(failure)` |
| **Action 2** | `process_paymob_callback(failure)` (duplicate) |
| **Assert: stock** | Restored exactly once |
| **Assert: stock_restorations** | 1 row |

### T-RC10: Stock Ledger — Double Cancel Restores Once

| Field | Value |
|-------|-------|
| **ID** | T-RC10 |
| **Priority** | High |
| **Category** | Stock Integrity |
| **Setup** | Create pending order, decrement stock |
| **Action 1** | `expire_pending_order()` |
| **Action 2** | `update_order_status('cancelled')` (rejected — already cancelled) |
| **Assert: stock** | Restored exactly once |

### T-RC11: Cancelled Order Late Success

| Field | Value |
|-------|-------|
| **ID** | T-RC11 |
| **Priority** | High |
| **Category** | Race Condition |
| **Setup** | Create pending order, expire it |
| **Action** | `process_paymob_callback(success)` |
| **Expected** | `code=already_processed` |
| **Assert: order** | `status = 'cancelled'` |
| **Assert: payment** | `status = 'expired'` (NOT promoted to success) |

### T-RC12: Audit Trail Completeness

| Field | Value |
|-------|-------|
| **ID** | T-RC12 |
| **Priority** | Medium |
| **Category** | Auditability |
| **Action** | Query `state_transitions` after running T-RC02 |
| **Assert** | `late_callback_rejected` record exists |
| **Assert** | `trigger_audit` records exist for status changes |

### T-RC13: COD Then Expiry

| Field | Value |
|-------|-------|
| **ID** | T-RC13 |
| **Priority** | Medium |
| **Category** | COD Flow |
| **Setup** | Create pending COD order |
| **Action 1** | `confirm_cod_payment()` |
| **Action 2** | Set expires_at to past |
| **Action 3** | `expire_pending_order()` |
| **Expected** | Action 1: `code=confirmed`. Action 3: `code=already_terminal` |
| **Assert: order** | `status = 'paid'` |

### T-RC14: Unmapped Payment (Invalid HMAC Fallback)

| Field | Value |
|-------|-------|
| **ID** | T-RC14 |
| **Priority** | High |
| **Category** | Security |
| **Action** | `process_paymob_callback('NONEXISTENT', ...)` |
| **Expected** | `ok=false, code=unmapped_payment` |
| **Assert** | No rows inserted into payments or orders |

---

## 3. Concurrency Test Execution (Staging)

### Prerequisites

1. Migration 025 applied to staging database
2. `supabase tests/test_race_conditions.sql` passes
3. Edge Functions deployed to staging

### Staging Concurrency Harness

```bash
#!/bin/bash
# concurrent_race_test.sh
# Run 10 parallel callback/expiry pairs against staging
# to validate PostgreSQL row-level locking under contention.

ORDER_IDS=()
PAYMOB_IDS=()

# Setup: create 10 orders via create_checkout_order RPC
for i in $(seq 1 10); do
  # Create order + payment via RPCs (authenticated client)
  ORDER_IDS+=("$(create_test_order $i)")
  PAYMOB_IDS+=("$(create_test_payment ${ORDER_IDS[$i]})")
done

# Race: fire callback and expiry simultaneously
for i in $(seq 1 10); do
  (
    # Thread A: callback (success)
    invoke_callback "${PAYMOB_IDS[$i]}" "success" &
    # Thread B: expiry (simulated by setting expires_at to past)
    invoke_expiry "${ORDER_IDS[$i]}" &
  )
done

wait

# Verify: all 10 orders should be in coherent terminal states
for i in $(seq 1 10); do
  verify_coherent_state "${ORDER_IDS[$i]}"
done
```

### Coherence Check

```sql
-- Run after concurrent test to verify no incoherent states.
SELECT
  o.id AS order_id,
  o.status AS order_status,
  p.status AS payment_status,
  CASE
    WHEN o.status = 'paid' AND p.status = 'success' THEN 'COHERENT'
    WHEN o.status = 'cancelled' AND p.status IN ('expired', 'failed') THEN 'COHERENT'
    WHEN o.status = 'pending' AND p.status = 'pending' THEN 'COHERENT'
    ELSE 'INCOHERENT'
  END AS coherence
FROM orders o
JOIN payments p ON p.order_id = o.id
WHERE o.placed_at > now() - interval '1 hour'
  AND o.payment_method = 'paymob_card';
```

---

## 4. Expected Audit Trail After Race Test

```sql
-- Verify no late callbacks were misreported as success.
SELECT
  reason,
  count(*) AS occurrences
FROM state_transitions
WHERE created_at > now() - interval '1 hour'
GROUP BY reason
ORDER BY count DESC;

-- Expected:
-- trigger_audit       | N  (automatic triggers)
-- payment_success     | M  (successful callbacks)
-- late_callback_rejected | K  (K >= 0, race arrivals)
-- order_expired       | J  (expiry cancellations)
```

---

## 5. Rollback Procedure

If staging tests fail:

```sql
-- Restore process_paymob_callback from migration 014
-- Restore expire_pending_order from migration 015
-- Restore confirm_cod_payment from migration 022
-- Drop audit table and triggers
DROP TABLE IF EXISTS state_transitions CASCADE;
DROP FUNCTION IF EXISTS audit_transition CASCADE;
DROP FUNCTION IF EXISTS audit_order_status_change CASCADE;
DROP FUNCTION IF EXISTS audit_payment_status_change CASCADE;
```
