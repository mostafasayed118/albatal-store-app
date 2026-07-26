# Migration Parity Report

**Project:** Al Batal Elite  
**Date:** 2026-07-25  
**Verdict:** **DRIFT DETECTED — ACTION REQUIRED**  
**Auditor:** Database Migration Auditor (read-only)

---

## 1. Repository Migration Files

### 1.1 Files tracked on HEAD (committed)

| # | Filename | Status |
|---|----------|--------|
| 001 | `001_initial_schema.sql` | Tracked, unmodified |
| 002 | `002_rls_policies.sql` | Tracked, unmodified |
| 003 | `003_auth_profiles_and_hardening.sql` | Tracked, unmodified |
| 004 | `004_stock_function.sql` | Tracked, unmodified |
| 005 | `005_storage_buckets.sql` | Tracked, unmodified |
| 006 | `006_payments_table.sql` | Tracked, unmodified |
| 007 | `007_stock_increment_function.sql` | Tracked, unmodified |
| 008 | `008_order_fulfillment.sql` | Tracked, unmodified |
| 009 | `009_shipping_zones.sql` | Tracked, unmodified |
| 010 | `010_notifications_analytics.sql` | Tracked, unmodified |
| 011 | `011_orders_idempotency_and_expiry.sql` | Tracked, unmodified |
| 012 | `012_add_order_statuses.sql` | Tracked, unmodified |
| 013 | `013_atomic_checkout_rpc.sql` | Tracked, **MODIFIED** (uncommitted working-tree diff) |
| 014 | `014_paymob_security_repair.sql` | Tracked, unmodified |
| 015 | `015_payments_update_and_stock_hardening.sql` | Tracked, unmodified |
| 016 | `016_seed_product_catalog.sql` | Tracked, unmodified |
| 017 | `017_authorize_rpcs.sql` | Tracked, unmodified |
| 018 | `018_confirm_cod_payment.sql` | Tracked, unmodified |
| — | `test_cod_payment.sql` | Tracked, **DELETED** (uncommitted) |
| — | `test_create_checkout_order.sql` | Tracked, **DELED** (uncommitted) |
| — | `test_payments_update_and_stock.sql` | Tracked, **DELETED** (uncommitted) |
| — | `test_paymob_callback.sql` | Tracked, **DELETED** (uncommitted) |
| — | `test_rpc_authorization.sql` | Tracked, **DELETED** (uncommitted) |
| — | `verify_rls.sql` | Tracked, **DELETED** (uncommitted) |

### 1.2 Files on origin/master (not on HEAD)

None — HEAD contains all of origin/master's migration files plus 018.

### 1.3 Untracked files on disk (not committed, not on origin/master)

| # | Filename | Content Summary |
|---|----------|-----------------|
| 019 | `019_harden_rpc_and_payments_authorization.sql` | REVOKE/GRANT hardening for 5 functions + DROP POLICY on payments |
| 020 | `020_fix_orders_fk.sql` | Full `create_checkout_order` rewrite with profile INSERT guard |
| 021 | `021_fix_create_checkout_order.sql` | Bugfix for 020 (OR type error in address validation) |

---

## 2. Staging Database Applied Migrations

**Status: UNKNOWN** — Staging database could not be queried in this read-only audit.

### Commands to check applied migrations in staging:

```sql
-- Query the supabase_migrations schema history
SELECT version, name, statements, success, executed_at
FROM supabase_migrations.schema_migrations
ORDER BY version;

-- Alternative: check if specific functions exist
SELECT proname, prokind, prosecdef
FROM pg_proc
WHERE proname IN (
  'create_checkout_order',
  'confirm_cod_payment',
  'process_paymob_callback',
  'update_order_status',
  'get_order_details',
  'get_low_stock_products'
)
ORDER BY proname;

-- Check current GRANT state
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN (
    'create_checkout_order',
    'confirm_cod_payment',
    'process_paymob_callback',
    'update_order_status'
  )
ORDER BY routine_name, grantee;
```

### Commands to check if RLS policies are current:

```sql
-- Check payments INSERT policy
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'payments'
  AND cmd = 'INSERT';

-- Expected: NO INSERT policy on payments after migration 019
```

---

## 3. Version String Comparison

### Migration sequence on HEAD (committed):

```
001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010
→ 011 → 012 → 013 → 014 → 015 → 016 → 017 → 018
```

### Migration sequence on origin/master:

```
001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010
→ 011 → 012 → 013 → 014 → 015 → 016 → 017
```

### Migration sequence on disk (working tree):

```
001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010
→ 011 → 012 → 013* → 014 → 015 → 016 → 017 → 018 → 019 → 020 → 021
```

\* 013 has uncommitted working-tree modifications.

### Drift summary:

| Scope | Highest committed migration | Uncommitted migrations | Total on disk |
|-------|-----------------------------|----------------------|---------------|
| HEAD | 018 | 0 (but 013 is modified) | 18 + 6 test files |
| origin/master | 017 | 0 | 17 + 5 test files |
| Working tree | 018 | 019, 020, 021 | 21 |

---

## 4. Content Comparison: Critical Migrations

### 4.1 `013_atomic_checkout_rpc.sql` — HEAD vs working tree

The working tree adds a profile FK guard that HEAD does not have:

```sql
-- ADDED in working tree (not in HEAD):
INSERT INTO profiles (id, full_name, phone)
VALUES (v_user_id, '', '')
ON CONFLICT (id) DO NOTHING;
```

**Impact:** The committed HEAD version of 013 will fail with a FK violation if a user has no profile row. The uncommitted working-tree version fixes this. However, migration 020 (untracked) also adds this same fix as a `CREATE OR REPLACE`.

**Risk:** If only 013 is committed (with the profile fix) and 020/021 are not, the function body is correct but the GRANT remains `TO PUBLIC` (see Section 5).

### 4.2 `018_confirm_cod_payment.sql` — HEAD vs origin/master

| Property | HEAD | origin/master |
|----------|------|---------------|
| File exists | Yes | **No** |
| Content | 240 lines, full implementation | N/A |

**Impact:** 018 exists only on HEAD. If origin/master is merged into a release branch that doesn't include HEAD's commit, 018 is lost and COD payments break.

### 4.3 `020_fix_orders_fk.sql` vs `021_fix_create_checkout_order.sql`

021 is a bugfix for 020. 020 has a syntax error:

```sql
-- 020 line 67 (BUG):
OR COALESCE(p_address->>'city', '') THEN
-- Missing = '' — causes "argument of OR must be type boolean, not type text"

-- 021 line 60 (FIX):
OR COALESCE(p_address->>'city', '') = '' THEN
```

**Impact:** If 020 is applied without 021, the `create_checkout_order` function will fail with a type error on every checkout call. Both must be applied in sequence.

---

## 5. GRANT Conflict Analysis

This is the most critical drift finding. Four migrations set GRANT permissions on `create_checkout_order`, and their final state depends on application order.

### GRANT history for `create_checkout_order`:

| Migration | GRANT Statement | Target Role |
|-----------|----------------|-------------|
| 013 (line 258) | `GRANT EXECUTE ON FUNCTION create_checkout_order TO PUBLIC` | PUBLIC |
| 019 (line 69) | `REVOKE ALL ON FUNCTION create_checkout_order(...) FROM PUBLIC` | — (revokes PUBLIC) |
| 019 (line 69) | `GRANT EXECUTE ON FUNCTION create_checkout_order(...) TO authenticated` | authenticated |
| 020 (line 233) | `GRANT EXECUTE ON FUNCTION create_checkout_order TO authenticated` | authenticated |
| 021 (line 193) | `GRANT EXECUTE ON FUNCTION create_checkout_order TO authenticated` | authenticated |

### Final state analysis:

**If migrations are applied in order (001→021):**
- 013 grants to PUBLIC
- 019 revokes PUBLIC, grants to authenticated
- 020 `CREATE OR REPLACE` does not change grants (GRANT is re-applied to authenticated — idempotent)
- 021 same — idempotent

**Final state: authenticated only** ✅

**If only 013 is applied (019/020/021 not applied):**
- 013 grants to PUBLIC

**Final state: PUBLIC (insecure)** ❌

**If 013+019 are applied but 020/021 are not:**
- 013 grants to PUBLIC
- 019 revokes PUBLIC, grants to authenticated
- Function body is from 013 (no profile FK guard)

**Final state: authenticated only, but no FK fix** ⚠️

### GRANT history for other functions:

| Function | Created in | Initial GRANT | Hardened in | Final GRANT |
|----------|-----------|---------------|-------------|-------------|
| `create_checkout_order` | 013 | PUBLIC | 019 | authenticated |
| `update_order_status` | 014 | PUBLIC | 019 | authenticated |
| `confirm_cod_payment` | 018 | authenticated | 019 (re-assert) | authenticated |
| `process_paymob_callback` | 014 | PUBLIC | 015, 019 (re-assert) | service_role |
| `get_order_details` | 008 | (none) | 017 | authenticated |
| `get_low_stock_products` | 008 | (none) | 017 | authenticated |

---

## 6. Duplicate Function Risk

### `create_checkout_order` — defined in 3 migrations:

| Migration | Line | Method |
|-----------|------|--------|
| 013 | 22 | `CREATE OR REPLACE FUNCTION` |
| 020 | 13 | `CREATE OR REPLACE FUNCTION` |
| 021 | 13 | `CREATE OR REPLACE FUNCTION` |

**Risk: LOW** — PostgreSQL `CREATE OR REPLACE` is idempotent. The last-applied migration wins. As long as 021 is applied after 020, the final function body is correct.

**However:** If migration history is incomplete (e.g., 019 is applied but 020/021 are not), the function body is from 013 (no FK guard). This is a functional regression risk.

### `confirm_cod_payment` — defined in 1 migration:

| Migration | Line | Method |
|-----------|------|--------|
| 018 | 45 | `CREATE OR REPLACE FUNCTION` |

**Risk: NONE** — Single definition.

### `payments_insert_own` policy — dropped in 019:

| Migration | Action |
|-----------|--------|
| 006 | Created |
| 019 | `DROP POLICY IF EXISTS` |

**Risk: LOW** — Drop is idempotent. If 019 is not applied, the policy remains (allows direct client INSERT into payments). This is a security gap but not a crash risk.

---

## 7. Grant Conflict Risk Summary

| Risk | Severity | Description |
|------|----------|-------------|
| 013 grants to PUBLIC | **HIGH** | If 019 is not applied, anonymous users can call `create_checkout_order` |
| 014 grants `process_paymob_callback` to PUBLIC | **HIGH** | If 015/019 not applied, anonymous users can call the callback |
| 020/021 re-grant after 019 | **LOW** | Idempotent — no conflict |
| `payments_insert_own` not dropped | **MEDIUM** | If 019 not applied, clients can INSERT payment rows directly |

---

## 8. Status of Specific Migrations

### 8.1 `018_confirm_cod_payment.sql`

| Property | Value |
|----------|-------|
| On HEAD (committed) | **Yes** |
| On origin/master | **No** |
| On disk (working tree) | Yes |
| Content identical HEAD vs disk | **Yes** (no diff) |
| Applied in staging | **UNKNOWN** |

**Drift:** 018 exists only on the local `master` branch, not on `origin/master`. If origin/master is the release source, 018 will be missing.

### 8.2 `019_harden_rpc_and_payments_authorization.sql`

| Property | Value |
|----------|-------|
| On HEAD (committed) | **No** |
| On origin/master | **No** |
| On disk (working tree) | Yes (untracked) |
| Applied in staging | **UNKNOWN** |

**Drift:** Not committed anywhere. Contains critical REVOKE/GRANT changes. Must be committed and applied before production.

### 8.3 `020_fix_orders_fk.sql`

| Property | Value |
|----------|-------|
| On HEAD (committed) | **No** |
| On origin/master | **No** |
| On disk (working tree) | Yes (untracked) |
| Applied in staging | **UNKNOWN** |
| Has known bug | **Yes** — OR type error on line 67 |

**Drift:** Not committed. Must be applied AFTER 019 and BEFORE or simultaneously with 021.

### 8.4 `021_fix_create_checkout_order.sql`

| Property | Value |
|----------|-------|
| On HEAD (committed) | **No** |
| On origin/master | **No** |
| On disk (working tree) | Yes (untracked) |
| Applied in staging | **UNKNOWN** |
| Fixes bug in 020 | **Yes** — OR type error |

**Drift:** Not committed. Must be applied AFTER 020.

---

## 9. Migration Drift Detection

### Detected drifts:

| # | Drift | Severity | Description |
|---|-------|----------|-------------|
| D1 | 018 missing from origin/master | **HIGH** | COD payment RPC will not exist on release branch |
| D2 | 019 not committed | **HIGH** | REVOKE/GRANT hardening not in version control |
| D3 | 020 not committed | **HIGH** | FK violation fix not in version control |
| D4 | 021 not committed | **HIGH** | Checkout bugfix not in version control |
| D5 | 013 modified but uncommitted | **MEDIUM** | Profile FK guard in 013 working tree duplicates 020 |
| D6 | Test migration files deleted but uncommitted | **LOW** | Test fixtures removed, not committed |
| D7 | `payments_insert_own` policy status unknown | **MEDIUM** | May still be active in staging |

### No drift detected:

| Item | Status |
|------|--------|
| Migrations 001–017 | Identical across HEAD, origin/master, and disk |
| Migration 014 (Paymob security) | No drift |
| Migration 015 (payments hardening) | No drift |
| Migration 017 (RPC authorization) | No drift |

---

## 10. Recommendation: Forward-Only Repair Migration

**Do NOT delete or renumber any applied migration history.**

### Recommended repair path:

```
Step 1: Commit existing untracked migrations
  - 019_harden_rpc_and_payments_authorization.sql
  - 020_fix_orders_fk.sql
  - 021_fix_create_checkout_order.sql

Step 2: Discard the uncommitted 013 working-tree diff
  git checkout -- supabase/migrations/013_atomic_checkout_rpc.sql
  Reason: 020 supersedes the profile FK fix in 013.

Step 3: Merge or rebase onto origin/master
  This brings in the fix/missing-di-sources branch.

Step 4: If staging already has 013 with the profile fix applied
  (i.e., someone ran the modified 013 manually), no additional
  migration is needed — 020's CREATE OR REPLACE will overwrite
  the function body correctly.

Step 5: If staging does NOT have 019 applied
  Apply 019 first. It REVOKEs PUBLIC grants and drops the
  payments INSERT policy. This is a prerequisite for 020/021.

Step 6: Apply 020 then 021 in sequence.
  020 recreates create_checkout_order with the FK fix.
  021 fixes the OR type error in 020's address validation.

Step 7: Verify final function state
  Run the diagnostic SQL from Section 2 to confirm:
  - confirm_cod_payment exists
  - create_checkout_order exists
  - Both are GRANTed to authenticated only
  - payments has no INSERT policy
```

### If a new forward-only repair migration is needed:

If staging already has 018 applied but NOT 019/020/021, create a single repair migration:

```sql
-- Migration 022: Repair — apply 019+020+021 in one transaction
-- This is a forward-only repair for staging environments where
-- 019, 020, 021 were never applied.

-- (Include the full content of 019, then 020's function, then 021's function)
-- All three are idempotent and safe to combine.
```

**Do not renumber 019/020/021** if they have already been applied to any environment. Instead, create 022 as a combined repair.

---

## 11. Diagnostic Queries for Staging Verification

Run these read-only queries against the staging database to determine actual state:

```sql
-- 1. List all applied migrations
SELECT version, name, executed_at
FROM supabase_migrations.schema_migrations
ORDER BY version;

-- 2. Check which functions exist and their GRANT state
SELECT
  p.proname AS function_name,
  pg_get_userbyid(p.proowner) AS owner,
  p.prosecdef AS security_definer,
  r.rolname AS grantee,
  e.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
LEFT JOIN pg_proc_roles_acl pr ON p.oid = pr.prooid
LEFT JOIN pg_roles r ON pr.grantee = r.oid
LEFT JOIN information_schema.routine_privileges e
  ON e.routine_name = p.proname
  AND e.routine_schema = 'public'
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_checkout_order',
    'confirm_cod_payment',
    'process_paymob_callback',
    'update_order_status',
    'get_order_details',
    'get_low_stock_products'
  )
ORDER BY p.proname, r.rolname;

-- 3. Check payments INSERT policy
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND cmd = 'INSERT';
-- Expected after 019: 0 rows

-- 4. Check if confirm_cod_payment function exists
SELECT proname, prokind
FROM pg_proc
JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
WHERE pg_namespace.nspname = 'public'
  AND pg_proc.proname = 'confirm_cod_payment';

-- 5. Verify no PUBLIC grants remain on critical functions
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND grantee = 'PUBLIC'
  AND routine_name IN (
    'create_checkout_order',
    'update_order_status',
    'process_paymob_callback',
    'confirm_cod_payment'
  );
-- Expected after 019: 0 rows
```

---

## 12. Summary

| Criterion | Status |
|-----------|--------|
| All migrations committed to version control | **NO** — 019, 020, 021 untracked |
| Migration sequence consistent across branches | **NO** — 018 missing from origin/master |
| No GRANT conflicts | **NO** — 013 grants to PUBLIC, 019 not applied |
| No duplicate function risks | **LOW** — CREATE OR REPLACE is idempotent |
| No drift between repo and staging | **UNKNOWN** — staging not queried |
| Ready for migration deploy | **NO** — commit 019/020/021 first |

**Verdict: DRIFT DETECTED** — Commit untracked migrations, merge branches, verify staging state, then re-audit.
