# Staging Evidence Template — Migration 025

## How to Use

1. Deploy Migration 025 to staging
2. Deploy Edge Functions to staging
3. Run each evidence step below
4. Save output to `evidence/migration-025-[timestamp]/`
5. Fill in results before marking as PASS

---

## Step 1: Migration Applied

```bash
# Verify migration applied
supabase db diff --use-migra 2>&1 | head -20
```

**Expected:** No diff (migration matches schema)

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/01_migration_diff.txt`

---

## Step 2: Audit Table Exists

```sql
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'state_transitions'
ORDER BY ordinal_position;
```

**Expected:** 9 columns (id, entity_type, entity_id, old_status, new_status, caller, reason, metadata, created_at)

**Result:** [ ] PASS [ ] FAIL

---

## Step 3: Audit Triggers Exist

```sql
SELECT
  trigger_name,
  event_manipulation,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE 'trg_audit_%'
ORDER BY trigger_name;
```

**Expected:** 2 triggers (trg_audit_order_status, trg_audit_payment_status)

**Result:** [ ] PASS [ ] FAIL

---

## Step 4: RPC Privilege Matrix

```sql
SELECT
  f.proname AS rpc,
  has_function_privilege('PUBLIC', f.oid, 'EXECUTE') AS public_exec,
  has_function_privilege('anon', f.oid, 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated', f.oid, 'EXECUTE') AS auth_exec,
  has_function_privilege('service_role', f.oid, 'EXECUTE') AS svc_exec
FROM pg_proc f
WHERE f.proname IN (
  'process_paymob_callback',
  'expire_pending_order',
  'confirm_cod_payment',
  'create_checkout_order',
  'update_order_status'
)
AND f.pronamespace = 'public'::regnamespace
ORDER BY f.proname;
```

**Expected:**
| RPC | public | anon | auth | svc |
|-----|--------|------|------|-----|
| process_paymob_callback | false | false | false | true |
| expire_pending_order | false | false | false | true |
| confirm_cod_payment | false | false | true | true |
| create_checkout_order | false | false | true | true |
| update_order_status | false | false | true | true |

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/04_privilege_matrix.txt`

---

## Step 5: SQL Test Suite

```bash
psql "$DATABASE_URL" -f supabase/tests/test_race_conditions.sql 2>&1
```

**Expected:** `ALL 14 RACE CONDITION TESTS PASSED ✓`

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/05_race_tests.txt`

---

## Step 6: Edge Function Deployment

```bash
supabase functions deploy paymob-callback
supabase functions deploy cancel-expired-orders
```

**Expected:** Both deploy successfully

**Result:** [ ] PASS [ ] FAIL

---

## Step 7: Paymob Callback Test (Real Webhook)

### Setup
1. Create a test order via the app
2. Complete payment with Paymob test card
3. Wait for Paymob webhook to fire

### Check order state
```sql
SELECT
  o.id,
  o.status AS order_status,
  p.status AS payment_status,
  p.transaction_id
FROM orders o
JOIN payments p ON p.order_id = o.id
WHERE o.id = '<test_order_id>';
```

**Expected:** `order_status = 'paid'`, `payment_status = 'success'`

**Result:** [ ] PASS [ ] FAIL

### Check audit trail
```sql
SELECT * FROM state_transitions
WHERE entity_id = '<test_order_id>' OR entity_id = '<test_payment_id>'
ORDER BY created_at;
```

**Expected:** At least 2 records (order transition + payment transition)

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/07_webhook_audit.txt`

---

## Step 8: Expiry Worker Test

### Setup
1. Create a test order
2. Wait for expires_at to pass (or manually set to past)
3. Trigger cancel-expired-orders Edge Function

### Check order state
```sql
SELECT
  o.id,
  o.status AS order_status,
  p.status AS payment_status,
  sr.restored_at IS NOT NULL AS stock_restored
FROM orders o
JOIN payments p ON p.order_id = o.id
LEFT JOIN stock_restorations sr ON sr.order_id = o.id
WHERE o.id = '<expired_order_id>';
```

**Expected:** `order_status = 'cancelled'`, `payment_status = 'expired'`, `stock_restored = true`

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/08_expiry_test.txt`

---

## Step 9: Race Condition Simulation

### Setup
1. Create a test order (expires_at = now + 5s)
2. Simultaneously:
   - Thread A: Call paymob-callback with success
   - Thread B: Wait 5s then call cancel-expired-orders

### Verification
```sql
SELECT
  o.id,
  o.status AS order_status,
  p.status AS payment_status,
  CASE
    WHEN o.status = 'paid' AND p.status = 'success' THEN 'COHERENT'
    WHEN o.status = 'cancelled' AND p.status IN ('expired', 'failed') THEN 'COHERENT'
    ELSE 'INCOHERENT'
  END AS coherence
FROM orders o
JOIN payments p ON p.order_id = o.id
WHERE o.id = '<race_test_order_id>';
```

**Expected:** `COHERENT`

**Result:** [ ] PASS [ ] FAIL

**Saved output:** `evidence/09_race_simulation.txt`

---

## Step 10: Client-Side Verification

### Checkout Flow
1. Open app → Add item to cart → Checkout
2. Select Paymob Card → Complete payment
3. Verify order appears in "Active" tab with status "Paid"
4. Verify stock badge reflects correct count

### Expiry Flow
1. Create order → Close app before paying
2. Wait 15 minutes
3. Reopen app → Verify order appears in "Cancelled" tab
4. Verify stock restored

### COD Flow
1. Create order → Select "Cash on Delivery"
2. Verify order appears in "Active" tab with status "Paid"
3. Admin: Cancel → Verify order moves to "Cancelled" tab

**Result:** [ ] PASS [ ] FAIL

---

## Final Checklist

| # | Check | Status |
|---|-------|--------|
| 1 | Migration 025 applied | [ ] |
| 2 | Audit table exists with correct schema | [ ] |
| 3 | Audit triggers fire on status changes | [ ] |
| 4 | RPC privileges correct | [ ] |
| 5 | SQL test suite passes (14/14) | [ ] |
| 6 | Edge Functions deploy to staging | [ ] |
| 7 | Paymob webhook creates correct state | [ ] |
| 8 | Expiry worker cancels + restores stock | [ ] |
| 9 | Race condition simulation: coherent state | [ ] |
| 10 | Client-side flows work end-to-end | [ ] |
| 11 | Audit trail records all transitions | [ ] |
| 12 | No secrets/logs printed in evidence | [ ] |

**Overall Result:** [ ] PASS [ ] FAIL

**Reviewed by:** _______________

**Date:** _______________

**Notes:** _______________
