# paymob-callback Deployment Repair Plan

**Date:** 2026-07-25
**Status:** PLAN — DO NOT DEPLOY WITHOUT HUMAN APPROVAL
**Severity:** P0 — Payment callbacks are non-functional in staging

---

## 1. Root Cause

The deployed `paymob-callback` Edge Function is **blocked by the Supabase platform JWT gateway** before the function body executes.

| Layer | What happens |
|---|---|
| Supabase API Gateway | Enforces `verify_jwt` from the **deployed** function config. If `verify_jwt = true` (the default), every inbound request must carry a valid Supabase user JWT. |
| Paymob server-to-server callback | Sends a form-urlencoded POST with HMAC fields. **No JWT. No Authorization header.** |
| Result | Gateway returns `401 Unauthorized` or `403 Forbidden` before the function body ever runs. HMAC verification is never reached. Invalid HMAC tests fail at the gateway, not inside the function. |

**Local config.toml** already specifies `verify_jwt = false` (line 84). The deployed function has not been re-deployed with this configuration, or was deployed from an older version where the setting was absent (defaults to `true`).

---

## 2. Why paymob-callback Is Different

| Function | Caller | Auth mechanism | verify_jwt |
|---|---|---|---|
| `checkout` | Flutter client (user) | Supabase user JWT | `true` |
| `paymob-initiate` | Flutter client (user) | Supabase user JWT | `true` |
| `paymob-callback` | Paymob servers | HMAC-SHA512 signature | `false` |
| `cancel-expired-orders` | Scheduler (cron) | `x-scheduler-secret` header | `false` |
| `send-order-notification` | Internal service | `x-internal-key` header | `false` |

`paymob-callback` is a **provider webhook endpoint**, not a user-facing function. The Supabase JWT gateway is the wrong authentication boundary. The function implements its own authentication via HMAC verification at the application layer (see `hmac.ts`).

The security model is:

```
Paymob servers
  → POST /functions/v1/paymob-callback (form-urlencoded body + HMAC)
  → Supabase Gateway (verify_jwt=false → passes through)
  → paymob-callback/index.ts
    → requireSecret("PAYMOB_HMAC_SECRET")  — fail-closed 503 if missing
    → verifyHmac(values, secret, receivedHmac)  — constant-time HMAC-SHA512
    → Invalid HMAC → 401, no state change
    → Valid HMAC → service-role client → process_paymob_callback RPC
      → Atomic: payment + order + stock in one transaction
      → Idempotent: duplicate callback = 2xx no-op
```

---

## 3. Exact Deployment Commands

### 3a. Pre-deployment checks (read-only, safe)

```bash
# 1. Verify local config.toml has correct setting
grep -A2 'paymob-callback' supabase/config.toml
# Expected: verify_jwt = false

# 2. Verify function list
supabase functions list

# 3. Verify project link
cat supabase/.temp/project-ref
# Expected: alxwvyflasewslinufqe

# 4. Verify secrets are set (does NOT print values)
supabase secrets list
# Must include: PAYMOB_HMAC_SECRET, SUPABASE_SERVICE_ROLE_KEY, PAYMOB_API_KEY
```

### 3b. Deploy only paymob-callback (single function)

```bash
supabase functions deploy paymob-callback --project-ref alxwvyflasewslinufqe
```

This deploys the function with `verify_jwt = false` from `config.toml`. The gateway will no longer reject Paymob callbacks at the platform level.

### 3c. Do NOT deploy other functions

`checkout` and `paymob-initiate` keep `verify_jwt = true`. They are not part of this repair and must not be touched.

---

## 4. Exact Verification Commands

### 4a. Post-deploy config verification

```bash
# Confirm function is listed and active
supabase functions list

# Confirm function endpoint is reachable (anonymous GET should return 400, not 401/403)
curl -s -o /dev/null -w "%{http_code}" \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback"
# Expected: 400 (Method not allowed — function body executed, gateway passed through)
# If you get 401/403: verify_jwt is still true. STOP. Re-deploy.
```

### 4b. Verify HMAC gate is active

```bash
# POST with no body → should return 400, not 401
curl -s -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d ""
# Expected: 400 {"message":"Empty callback body"}
# If you get 401/403: gateway is still blocking. STOP.
```

### 4c. Verify HMAC verification is enforced

```bash
# POST with forged body → should reach function body, fail HMAC, return 401
curl -s -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=1000&currency=EGP&success=true&id=99999&order=12345&hmac=forged_hmac_value"
# Expected: 401 {"message":"Invalid signature"}
# CRITICAL: This response must come from the function body (HMAC failure),
#           NOT from the gateway (JWT failure).
# How to tell: 401 with {"message":"Invalid signature"} = function body reached.
#              401 with generic Supabase auth error = gateway still blocking.
```

---

## 5. Forged HMAC Test

**Purpose:** Prove the forged callback reaches the function body and returns `invalid-signature`.

```bash
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=1000&created_at=2026-07-25T00:00:00Z&currency=EGP&error_occured=false&has_parent_transaction=false&id=99999&integration_id=0&is_3d_secure=false&is_auth=false&is_capture=false&is_refunded=false&is_standalone_payment=true&is_voided=false&order=12345&owner=0&pending=false&source_data_pan=****&source_data_sub_type=VISA&source_data_type=token&success=true&hmac=000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
```

**Expected result:**
- HTTP 401
- Body: `{"message":"Invalid signature"}`
- **NOT** rejected by platform JWT gateway

**Acceptance criterion:** The `{"message":"Invalid signature"}` string proves the function body executed. A gateway JWT rejection returns a different Supabase-specific error body.

---

## 6. Valid Sandbox Callback Test

**Purpose:** Prove a valid callback changes order/payment exactly once.

This test requires:
1. A pending order in staging with `paymob_order_id` set
2. The actual `PAYMOB_HMAC_SECRET` for staging
3. A valid HMAC computed from real staging fields

### Steps:

```bash
# Step 1: Create test data via SQL (run in Supabase SQL Editor)
# Use the existing test fixture:
#   supabase/tests/test_paymob_callback.sql
# Or manually:

# Insert a test order + payment with a known paymob_order_id
INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at)
VALUES (
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  '<test-user-uuid>',
  'pending', 5000, 0, 5000,
  'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb, now()
);

INSERT INTO payments (id, order_id, user_id, method, amount,
  paymob_order_id, status)
VALUES (
  'ffffffff-aaaa-bbbb-cccc-dddddddddddd',
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  '<test-user-uuid>',
  'paymob_card', 5000, 'sandbox-order-001', 'pending'
);

# Step 2: Compute HMAC (use the staging PAYMOB_HMAC_SECRET)
# The HMAC is computed over the 20 canonical fields in order.
# Use a local Deno script or Python script to compute it.

# Step 3: Send the callback
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=5000&created_at=<timestamp>&currency=EGP&error_occured=false&has_parent_transaction=false&id=sandbox-txn-001&integration_id=<staging-integration-id>&is_3d_secure=false&is_auth=true&is_capture=true&is_refunded=false&is_standalone_payment=true&is_voided=false&order=sandbox-order-001&owner=0&pending=false&source_data_pan=4111111111111111&source_data_sub_type=VISA&source_data_type=token&success=true&hmac=<computed-hmac>"

# Step 4: Verify state change
# Run in SQL Editor:
SELECT p.status, p.transaction_id, o.status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.paymob_order_id = 'sandbox-order-001';
# Expected: p.status='success', p.transaction_id='sandbox-txn-001', o.status='paid'
```

---

## 7. Duplicate Callback Test

**Purpose:** Prove duplicate valid callback is a safe 2xx no-op.

```bash
# Send the same valid callback twice (reuse HMAC from Test 6)
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "<same payload as Test 6>"

# Expected: HTTP 200, body: {"message":"Callback processed","code":"already_processed"}
# State must not change: payment stays 'success', order stays 'paid'
# transaction_id must remain the original value (not overwritten)
```

**SQL verification:**
```sql
SELECT p.status, p.transaction_id, o.status, o.updated_at
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.paymob_order_id = 'sandbox-order-001';
-- Expected: unchanged from Test 6
```

---

## 8. Amount Mismatch Test

**Purpose:** Prove amount mismatch produces no state change.

```bash
# Send valid HMAC but with amount_cents=9999 (order total is 5000)
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=9999&created_at=<timestamp>&currency=EGP&error_occured=false&has_parent_transaction=false&id=sandbox-txn-mismatch&integration_id=<staging-integration-id>&is_3d_secure=false&is_auth=true&is_capture=true&is_refunded=false&is_standalone_payment=true&is_voided=false&order=sandbox-order-001&owner=0&pending=false&source_data_pan=4111111111111111&source_data_sub_type=VISA&source_data_type=token&success=true&hmac=<computed-hmac-for-mismatch>"

# Expected: HTTP 400, body: {"message":"Callback rejected","code":"amount_mismatch"}
# State must not change
```

**SQL verification:**
```sql
SELECT p.status, o.status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.paymob_order_id = 'sandbox-order-001';
-- Expected: unchanged (payment=success, order=paid)
```

---

## 9. Missing HMAC Secret Fail-Closed Test

**Purpose:** Prove missing HMAC secret returns 503 fail-closed.

This test requires temporarily removing the `PAYMOB_HMAC_SECRET` from the function's environment. **Do NOT do this in production.** In staging:

```bash
# Step 1: Remove the secret (STAGING ONLY)
supabase secrets unset PAYMOB_HMAC_SECRET --project-ref alxwvyflasewslinufqe

# Step 2: Send a callback
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=1000&currency=EGP&success=true&id=1&order=1&hmac=x"

# Expected: HTTP 503, body: {"message":"Server configuration unavailable"}
# No state change. No payment/order mutation.

# Step 3: RESTORE the secret immediately
supabase secrets set PAYMOB_HMAC_SECRET=<restored-value> --project-ref alxwvyflasewslinufqe
```

---

## 10. Late Callback After Expiry Test

**Purpose:** Prove a late failure callback cannot downgrade a paid order.

```bash
#前提: Order was already paid by a valid callback (Test 6)
# Send a failure callback with the same paymob_order_id
# (reuse HMAC but with success=false)

# Compute HMAC with success=false for the same order
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -X POST \
  "https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "amount_cents=5000&created_at=<timestamp>&currency=EGP&error_occured=true&has_parent_transaction=false&id=sandbox-txn-late-fail&integration_id=<staging-integration-id>&is_3d_secure=false&is_auth=false&is_capture=false&is_refunded=false&is_standalone_payment=true&is_voided=false&order=sandbox-order-001&owner=0&pending=true&source_data_pan=4111111111111111&source_data_sub_type=VISA&source_data_type=token&success=false&hmac=<computed-hmac>"

# Expected: HTTP 200, body: {"message":"Callback processed","code":"already_processed"}
# Order stays 'paid'. Payment stays 'success'.
# Late failure does NOT downgrade.
```

**SQL verification:**
```sql
SELECT p.status, o.status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.paymob_order_id = 'sandbox-order-001';
-- Expected: payment=success, order=paid (unchanged)
```

---

## 11. GO / NO-GO Recommendation

### NO-GO until live staging evidence exists

| # | Gate | Status |
|---|---|---|
| G1 | `config.toml` has `verify_jwt = false` for `paymob-callback` | ✅ Verified (line 84) |
| G2 | `config.toml` has `verify_jwt = true` for `checkout` and `paymob-initiate` | ✅ Verified (lines 74, 77) |
| G3 | Function code implements HMAC verification (`hmac.ts`) | ✅ Verified |
| G4 | Function code implements fail-closed for missing `PAYMOB_HMAC_SECRET` | ✅ Verified (line 73-74) |
| G5 | Function code implements constant-time HMAC comparison | ✅ Verified (`constantTimeEquals`) |
| G6 | Function code validates amount/currency via RPC | ✅ Verified (RPC `process_paymob_callback`) |
| G7 | `process_paymob_callback` is service_role only | ✅ Verified (migration 015, line 90) |
| G8 | Forged callback reaches function body → returns `invalid-signature` | ⏳ Requires live staging test |
| G9 | Valid callback changes order/payment exactly once | ⏳ Requires live staging test |
| G10 | Duplicate callback is safe 2xx no-op | ⏳ Requires live staging test |
| G11 | Amount mismatch produces no state change | ⏳ Requires live staging test |
| G12 | Missing HMAC secret returns 503 fail-closed | ⏳ Requires live staging test |
| G13 | Late callback after expiry cannot downgrade paid order | ⏳ Requires live staging test |

**All code-level gates (G1-G7) pass. All runtime gates (G8-G13) require live staging evidence.**

### Deployment procedure:

1. Run pre-deployment checks (§4a)
2. Deploy only `paymob-callback` (§3b)
3. Run post-deploy verification (§4b, §4c)
4. Execute tests §5-§10 against live staging
5. Record evidence (HTTP status + body + SQL state snapshots)
6. Update this document's status to `GO` only after ALL of §5-§10 pass

### Rollback:

If anything fails:

```bash
# Restore the previous function deployment
supabase functions deploy paymob-callback --project-ref alxwvyflasewslinufqe
# (from the last known-good commit)
```

---

## 12. Architecture Note: JWT Exception

### Why `paymob-callback` must be public at the gateway level

Supabase Edge Functions sit behind a platform JWT gateway. When `verify_jwt = true` (the default), the gateway:

1. Extracts the `Authorization: Bearer <token>` header
2. Validates the JWT signature against the project's JWT secret
3. Checks token expiry and audience
4. Injects the decoded `sub` claim into the request context
5. Only then forwards the request to the function body

This is the correct security boundary for **user-facing functions** (`checkout`, `paymob-initiate`) where the caller is the Flutter client authenticated via Supabase Auth.

However, **provider webhooks** (`paymob-callback`, `cancel-expired-orders`, `send-order-notification`) are called by external systems that cannot present a Supabase user JWT:

- **Paymob** sends server-to-server POST callbacks with HMAC signatures, not JWTs.
- **The scheduler** sends requests with a shared secret header.
- **Internal services** authenticate via an internal API key.

For these functions, the JWT gateway is the **wrong authentication boundary**. Setting `verify_jwt = false` does not make the function unauthenticated — it moves authentication to the **application layer** where it belongs:

| Function | Gateway layer | Application layer |
|---|---|---|
| `paymob-callback` | `verify_jwt = false` (pass through) | HMAC-SHA512 constant-time verification |
| `cancel-expired-orders` | `verify_jwt = false` (pass through) | `requireSecret("SCHEDULER_SECRET")` header check |
| `send-order-notification` | `verify_jwt = false` (pass through) | `requireSecretHeader("NOTIFICATIONS_INTERNAL_KEY")` |

This is a defense-in-depth pattern: the gateway is one layer, application-level verification is another. Removing the gateway layer for provider endpoints does not weaken security — it applies the correct auth mechanism for the caller type.

---

## 13. Security Invariants (Must Hold After Deployment)

1. **No state change on invalid HMAC.** A forged callback must return 401 with zero payment/order/stock mutations.
2. **Fail-closed on missing secret.** If `PAYMOB_HMAC_SECRET` is not set, the function returns 503. No callback is processed.
3. **Constant-time comparison.** HMAC verification uses `constantTimeEquals` — timing attacks cannot extract the secret.
4. **Idempotent processing.** A duplicate valid callback returns 2xx with no additional state change.
5. **Amount/currency validation.** The RPC validates callback amount against the internal order total. Mismatches are rejected.
6. **Service-role only.** `process_paymob_callback` RPC is executable only by `service_role`. No client-side path can call it.
7. **No orphan insert.** The callback never creates a fallback payment. It only acts on payments that already exist with a matching `paymob_order_id`.
8. **No downgrade.** A late failure callback cannot downgrade a `paid`/`processing`/`shipped`/`delivered` order.
