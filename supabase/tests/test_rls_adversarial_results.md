# Adversarial RLS Verification — Expected Results & Launch Sign-Off

**Project:** Al Batal Elite
**Environment:** Staging (`alxwvyflasewslinufqe`)
**Date:** 2026-07-23
**Test script:** `supabase/tests/test_rls_adversarial.sql`
**Mode:** L1 report-only (no source code modified)

---

## How to Run

```bash
# From the project root, against the linked STAGING project:
supabase db execute --linked supabase/tests/test_rls_adversarial.sql

# Or paste the script into the Supabase SQL Editor on the staging project.
```

The script is wrapped in `BEGIN ... ROLLBACK`. It creates two disposable test
users, seeds their data, runs all tests, then discards everything. No real user
data is read or mutated. No secrets or JWT bodies are printed.

---

## 1. Expected Results

Each test prints `(test_id, description, expected, actual, status)`.
`status` is `PASS` when `actual = expected`, `FAIL` otherwise.

### Section 1 — Anonymous User (10 tests)

| Test | Description | Expected | RLS Policy Enforcing |
|------|-------------|----------|----------------------|
| 1.1 | anon cannot read profiles | `0` | `profiles_select_own` (002) |
| 1.2 | anon cannot read orders | `0` | `orders_select_own` (002) |
| 1.3 | anon cannot read order_items | `0` | `order_items_select_own` (002) |
| 1.4 | anon cannot read addresses | `0` | `addresses_select_own` (002) |
| 1.5 | anon cannot read cart_items | `0` | `cart_select_own` (002) |
| 1.6 | anon cannot read wishlists | `0` | `wishlists_select_own` (002) |
| 1.7 | anon cannot read payments | `0` | `payments_select_own` (006) |
| 1.8 | anon can read products | `>=1` | `products_select_public` (002) |
| 1.9 | anon can read categories | `>=1` | `categories_select_public` (002) |
| 1.10 | anon can read product_variants | `>=1` | `variants_select_public` (002) |
| 1.11 | anon can read product_images | `>=0` | `images_select_public` (002) |
| 1.12 | anon cannot read notifications | `0` | `notifications_select_own` (010) |
| 1.13 | anon cannot read analytics_events | `0` | `admin_select_analytics` (010) |
| 1.14 | anon cannot read error_logs | `0` | `admin_select_errors` (010) |

### Section 2 — User A: Own Data + Cross-User Isolation (14 tests)

| Test | Description | Expected | RLS Policy Enforcing |
|------|-------------|----------|----------------------|
| 2.1 | user_a can read own profile | `1` | `profiles_select_own` (002) |
| 2.2 | user_a can read own orders | `1` | `orders_select_own` (002) |
| 2.3 | user_a can read own order_items | `1` | `order_items_select_own` (002) |
| 2.4 | user_a can read own addresses | `1` | `addresses_select_own` (002) |
| 2.5 | user_a can read own cart_items | `1` | `cart_select_own` (002) |
| 2.6 | user_a can read own wishlists | `1` | `wishlists_select_own` (002) |
| 2.7 | user_a can read own payments | `1` | `payments_select_own` (006) |
| 2.8 | user_a cannot read user_b orders | `0` | `orders_select_own` (002) |
| 2.9 | user_a cannot read user_b addresses | `0` | `addresses_select_own` (002) |
| 2.10 | user_a cannot read user_b cart_items | `0` | `cart_select_own` (002) |
| 2.11 | user_a cannot read user_b wishlists | `0` | `wishlists_select_own` (002) |
| 2.12 | user_a cannot read user_b payments | `0` | `payments_select_own` (006) |
| 2.13 | user_a cannot read user_b profile | `0` | `profiles_select_own` (002) |
| 2.14 | user_a cannot read user_b order_items | `0` | `order_items_select_own` (002) |

### Section 3 — Non-Admin Escalation Attempts (9 tests)

| Test | Description | Expected | Enforcement Layer |
|------|-------------|----------|-------------------|
| 3.1 | non-admin cannot INSERT products | `0` | `admin_manage_products` (003) |
| 3.2 | non-admin cannot UPDATE products | `RLS Test Product` | `admin_manage_products` (003) |
| 3.3 | non-admin cannot DELETE products | `1` | `admin_manage_products` (003) |
| 3.4 | non-admin cannot INSERT categories | `0` | `admin_manage_categories` (003) |
| 3.5 | non-admin cannot UPDATE categories | `RLS Test Cat` | `admin_manage_categories` (003) |
| 3.6 | non-admin cannot update_order_status | `exception` | RPC internal `is_admin` check (014) |
| 3.7 | non-admin cannot set is_admin=true | `false` | `profiles_update_own_safe` WITH CHECK (003) |
| 3.8 | non-admin cannot call get_low_stock_products | `exception` | RPC internal `is_admin` check (017) |
| 3.9 | non-admin IDOR blocked on get_order_details | `exception` | RPC ownership check (017) |

### Section 4 — Authenticated User: Payment Integrity (7 tests)

| Test | Description | Expected | Enforcement Layer |
|------|-------------|----------|-------------------|
| 4.1 | authenticated cannot INSERT payments directly | `0` | No INSERT policy = default-deny (019) |
| 4.2 | authenticated cannot call process_paymob_callback | `exception` | GRANT to `service_role` only (019) |
| 4.3 | checkout ignores client-supplied price | `1000` | RPC reads DB price, ignores client (013) |
| 4.4 | authenticated cannot UPDATE payments | `pending` | No UPDATE policy on payments (006) |
| 4.5 | authenticated cannot UPDATE orders directly | `pending` | No non-admin UPDATE policy (003) |
| 4.6 | authenticated cannot INSERT orders directly | `0` | `orders_insert_denied` WITH CHECK false (003) |
| 4.7 | authenticated cannot INSERT order_items directly | `1` | `order_items_insert_denied` WITH CHECK false (003) |

---

## 2. Actual Results Template

> **Instructions:** Run the test script against staging, then paste the
> `=== RLS TEST RESULTS ===` output below. Replace each `[ ]` with the
> actual value from the run.

| Test | Description | Expected | Actual | Status |
|------|-------------|----------|--------|--------|
| 1.1 | anon cannot read profiles | `0` | `[ ]` | `[ ]` |
| 1.2 | anon cannot read orders | `0` | `[ ]` | `[ ]` |
| 1.3 | anon cannot read order_items | `0` | `[ ]` | `[ ]` |
| 1.4 | anon cannot read addresses | `0` | `[ ]` | `[ ]` |
| 1.5 | anon cannot read cart_items | `0` | `[ ]` | `[ ]` |
| 1.6 | anon cannot read wishlists | `0` | `[ ]` | `[ ]` |
| 1.7 | anon cannot read payments | `0` | `[ ]` | `[ ]` |
| 1.8 | anon can read products | `>=1` | `[ ]` | `[ ]` |
| 1.9 | anon can read categories | `>=1` | `[ ]` | `[ ]` |
| 1.10 | anon can read product_variants | `>=1` | `[ ]` | `[ ]` |
| 1.11 | anon can read product_images | `>=0` | `[ ]` | `[ ]` |
| 1.12 | anon cannot read notifications | `0` | `[ ]` | `[ ]` |
| 1.13 | anon cannot read analytics_events | `0` | `[ ]` | `[ ]` |
| 1.14 | anon cannot read error_logs | `0` | `[ ]` | `[ ]` |
| 2.1 | user_a can read own profile | `1` | `[ ]` | `[ ]` |
| 2.2 | user_a can read own orders | `1` | `[ ]` | `[ ]` |
| 2.3 | user_a can read own order_items | `1` | `[ ]` | `[ ]` |
| 2.4 | user_a can read own addresses | `1` | `[ ]` | `[ ]` |
| 2.5 | user_a can read own cart_items | `1` | `[ ]` | `[ ]` |
| 2.6 | user_a can read own wishlists | `1` | `[ ]` | `[ ]` |
| 2.7 | user_a can read own payments | `1` | `[ ]` | `[ ]` |
| 2.8 | user_a cannot read user_b orders | `0` | `[ ]` | `[ ]` |
| 2.9 | user_a cannot read user_b addresses | `0` | `[ ]` | `[ ]` |
| 2.10 | user_a cannot read user_b cart_items | `0` | `[ ]` | `[ ]` |
| 2.11 | user_a cannot read user_b wishlists | `0` | `[ ]` | `[ ]` |
| 2.12 | user_a cannot read user_b payments | `0` | `[ ]` | `[ ]` |
| 2.13 | user_a cannot read user_b profile | `0` | `[ ]` | `[ ]` |
| 2.14 | user_a cannot read user_b order_items | `0` | `[ ]` | `[ ]` |
| 3.1 | non-admin cannot INSERT products | `0` | `[ ]` | `[ ]` |
| 3.2 | non-admin cannot UPDATE products | `RLS Test Product` | `[ ]` | `[ ]` |
| 3.3 | non-admin cannot DELETE products | `1` | `[ ]` | `[ ]` |
| 3.4 | non-admin cannot INSERT categories | `0` | `[ ]` | `[ ]` |
| 3.5 | non-admin cannot UPDATE categories | `RLS Test Cat` | `[ ]` | `[ ]` |
| 3.6 | non-admin cannot update_order_status | `exception` | `[ ]` | `[ ]` |
| 3.7 | non-admin cannot set is_admin=true | `false` | `[ ]` | `[ ]` |
| 3.8 | non-admin cannot call get_low_stock_products | `exception` | `[ ]` | `[ ]` |
| 3.9 | non-admin IDOR blocked on get_order_details | `exception` | `[ ]` | `[ ]` |
| 4.1 | authenticated cannot INSERT payments directly | `0` | `[ ]` | `[ ]` |
| 4.2 | authenticated cannot call process_paymob_callback | `exception` | `[ ]` | `[ ]` |
| 4.3 | checkout ignores client-supplied price | `1000` | `[ ]` | `[ ]` |
| 4.4 | authenticated cannot UPDATE payments | `pending` | `[ ]` | `[ ]` |
| 4.5 | authenticated cannot UPDATE orders directly | `pending` | `[ ]` | `[ ]` |
| 4.6 | authenticated cannot INSERT orders directly | `0` | `[ ]` | `[ ]` |
| 4.7 | authenticated cannot INSERT order_items directly | `1` | `[ ]` | `[ ]` |

---

## 3. PASS/FAIL Summary

> **Instructions:** Paste the `=== PASS/FAIL SUMMARY ===` block from the
> script output here.

```
Passed:    [ ] / 44
Failed:    [ ] / 44
Verdict:   [ ]
```

**Launch gate:** `Failed` must be `0` for RLS to be considered verified.

---

## 4. Evidence Required for Launch Sign-Off

Before RLS can be marked VERIFIED for production launch, the following
evidence must be collected and stored (e.g., in the PR, the release
notes, or the security review folder):

| # | Evidence | How to Capture | Status |
|---|----------|----------------|--------|
| E1 | Full stdout of `test_rls_adversarial.sql` | Save the SQL Editor or `supabase db execute` output to a file (e.g., `evidence/rls-staging-YYYYMMDD.txt`) | `[ ]` |
| E2 | The `=== RLS TEST RESULTS ===` table | Paste into section 2 above | `[ ]` |
| E3 | The `=== PASS/FAIL SUMMARY ===` verdict | Paste into section 3 above | `[ ]` |
| E4 | The `=== FAILURES (if any) ===` block | Must be empty (0 rows) | `[ ]` |
| E5 | Staging project ref confirmation | `supabase status` output showing `alxwvyflasewslinufqe` (staging, not prod) | `[ ]` |
| E6 | Migration ledger confirmation | `SELECT count(*) FROM supabase_migrations.schema_migrations` >= 19 on staging | `[ ]` |
| E7 | RLS-enabled confirmation | `verify_staging_deployment.sql` Section 5 — all user-scoped tables show `enabled` | `[ ]` |
| E8 | Payments INSERT policy removed | `verify_staging_deployment.sql` Section 6 — `payments_insert_own` absent | `[ ]` |
| E9 | Human reviewer sign-off | Name + date of the engineer who reviewed the test output | `[ ]` |

**Sign-off statement:**

> I confirm that all 44 adversarial RLS tests passed against the staging
> environment (`alxwvyflasewslinufqe`) on `[date]`. No negative test
> failed. The payments INSERT policy is absent (default-deny). The
> `process_paymob_callback` RPC is `service_role`-only. Checkout
> pricing is server-authoritative. RLS is VERIFIED for this release.

**Reviewer:** `[name]`
**Date:** `[YYYY-MM-DD]`

---

## 5. What This Test Does NOT Cover

These items require separate verification and are out of scope for this
RLS test script:

- **Storage bucket policies** (product images, avatars) — test separately
  via the Supabase Storage API.
- **Edge Function auth** — the Paymob callback Edge Function's HMAC
  verification is tested via `test_paymob_callback.sql`, not here.
- **JWT forgery / token replay** — this script simulates identity via
  `set_config`, which is the authoritative source PostgREST uses. A
  real forged JWT would resolve to the same `auth.uid()` and is
  therefore covered by the same RLS checks.
- **Rate limiting / abuse prevention** — infrastructure-layer concern,
  not RLS.
- **Production data** — this script only touches disposable test users
  inside a rolled-back transaction. Production data is never read.
