# Al Batal Elite — Migration 024 Evidence

**Date:** [YYYY-MM-DD]
**Staging Project:** al[REDACTED]
**Applied by:** [NAME]
**Verified by:** [NAME]

---

## 1. Migration Applied

```
migration_024_applied | PASS
```

---

## 2. RPC EXECUTE Privilege Matrix (Post-Hardening)

| RPC | PUBLIC | anon | authenticated | service_role | Expected | Status |
|-----|--------|------|---------------|--------------|----------|--------|
| `create_checkout_order` | false | false | **true** | false | authenticated | PASS |
| `confirm_cod_payment` | false | false | **true** | false | authenticated | PASS |
| `update_order_status` | false | false | **true** | false | authenticated | PASS |
| `process_paymob_callback` | false | false | false | **true** | service_role | PASS |
| `calculate_shipping_fee` | false | false | **true** | false | authenticated | PASS |
| `get_order_details` | false | false | **true** | false | authenticated | PASS |
| `get_low_stock_products` | false | false | **true** | false | authenticated | PASS |
| `set_payment_provider_order_id` | false | false | **true** | false | authenticated | PASS |
| `expire_pending_order` | false | false | false | **true** | service_role | PASS |
| `decrement_stock` | false | false | false | **true** | service_role | PASS |
| `increment_stock` | false | false | false | **true** | service_role | PASS |

**Total RPCs:** 11
**Hardened:** 11/11

---

## 3. Sensitive Tables — INSERT Posture

| Table | INSERT Policy | Risk Level | Status |
|-------|---------------|------------|--------|
| `payments` | **None** (RLS default-deny) | LOW | PASS |
| `notifications` | **None** (service_role bypass RLS) | LOW | PASS |
| `analytics_events` | `analytics_insert_narrow` (authenticated, user_id match, ≤10KB) | LOW | PASS |
| `error_logs` | `error_logs_insert_narrow` (authenticated, user_id match, ≤50KB) | LOW | PASS |
| `orders` | `orders_insert_denied` (WITH CHECK false) | LOW | PASS |
| `order_items` | `order_items_insert_denied` (WITH CHECK false) | LOW | PASS |

---

## 4. calculate_shipping_fee Hardening

| Check | Before | After | Status |
|-------|--------|-------|--------|
| PUBLIC EXECUTE | **true** | **false** | PASS |
| authenticated EXECUTE | **false** | **true** | PASS |
| Input validation | None | governorate required, subtotal ≥ 0 | PASS |
| search_path | none | `public` | PASS |
| Null threshold fallback | exception | returns 0 | PASS |

---

## 5. Functional Verification (Optional — requires test data)

```
# Test: calculate_shipping_fee with valid input
SELECT calculate_shipping_fee('Cairo', 10000);
-- Expected: 5000 (Cairo zone fee)

# Test: calculate_shipping_fee with empty governorate
SELECT calculate_shipping_fee('', 10000);
-- Expected: EXCEPTION 'Governorate is required'

# Test: calculate_shipping_fee with negative subtotal
SELECT calculate_shipping_fee('Cairo', -1);
-- Expected: EXCEPTION 'Subtotal must be a non-negative integer'
```

---

## 6. Rollback Tested

```
# On staging only:
\i supabase/migrations/024_rollback_hardening.sql

# Re-run privilege matrix to confirm pre-hardening state restored.
# Re-apply migration 024 before production deploy.
```

---

## 7. Sign-Off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Security Engineer | | | [ ] |
| Lead Developer | | | [ ] |
| DevOps | | | [ ] |

**Production deploy: BLOCKED until all three approvals received.**
