# Test Gap Analysis & Integration Test Plan

**Project:** Al Batal Elite
**Date:** 2026-07-23
**Mode:** L1 Report-Only (no code modified)
**Baseline:** 28 test files, 170+ passing tests, 0 integration_test/ directory

---

## 1. Current Test Coverage Summary

### 1.1 Flutter Unit & Widget Tests (28 files)

| Area | File | Tests | Coverage Strength |
|------|------|-------|-------------------|
| **Auth** | `auth_test.dart` | 7 | State + Profile model |
| **Auth** | `auth_cubit_test.dart` | 16 | checkSession, signIn, signUp, signOut, resetPassword, updatePassword, authStateChanges |
| **Catalog** | `catalog_cubit_test.dart` | 14 | Load, filter, sort, color, price range, debounce, combined filters |
| **Catalog** | `catalog_states_test.dart` | 2 | Error + loading widget states |
| **Cart** | `cart_cubit_test.dart` | 2 | Merge totals, restore from storage |
| **Cart** | `wishlist_cart_test.dart` | 3 | Wishlist↔Cart round-trip |
| **Product** | `product_detail_test.dart` | 8 | Product model, CartItem, ProductDetailsCubit |
| **Checkout** | `checkout_cubit_test.dart` | 11 | Success, stock error, idempotency retry, rollback, server totals, address snapshot, items mapping |
| **Checkout** | `checkout_address_test.dart` | 6 | Address select/clear/replace, address snapshot persistence |
| **Checkout** | `checkout_page_test.dart` | 3 | Step indicators, empty address, cart summary |
| **Orders** | `orders_cubit_test.dart` | 7 | Place, advance, reconcile upsert/append/update, persistence failure |
| **Payment** | `payment_test.dart` | 8 | PaymentState, PaymentResult, PaymentMethod models |
| **Payment** | `payment_integration_test.dart` | 7 | PaymentCubit initial, initPayment, COD, failure, pending, cancel, reset |
| **Payment** | `payment_checkout_flow_test.dart` | 8 | Pending → checkout URL, server success, failure, timeout, cancel, duplicate, close, empty orderId |
| **Payment** | `payment_security_test.dart` | 4 | No verifyPayment, no handleCallback, no secret getters, watch-only success |
| **Payment** | `cod_server_confirm_test.dart` | 7 | COD RPC call, success, rejection, network error, idempotency, interface contract |
| **Payment** | `paymob_url_guard_test.dart` | 9 | URL validation, HTTP rejection, host validation, redaction |
| **Payment** | `payment_navigation_test.dart` | 5 | Pending navigation, duplicate prevention, success navigation, invalid URL guard |
| **Orders Page** | `order_success_page_test.dart` | 3 | Real order ID, no legacy fallback, empty ID error |
| **Orders Page** | `integration_test.dart` | 1 | Orders page shows placed order (misnamed — this is a widget test, NOT a real integration test) |
| **Settings** | `settings_cubit_test.dart` | 2 | Load, optimistic locale + failure |
| **Crash** | `crash_reporting_scrub_test.dart` | 5 | Redacts sensitive keys, preserves safe keys, null/empty, NoOp service |
| **Details** | `details_page_test.dart` | 3 | Name+price, wishlist+share, variant chips |
| **Address** | `address_form_test.dart` | 3 | Fields shown, validation, valid submission |
| **App** | `app_widget_test.dart` | 1 | Arabic RTL directionality |
| **App** | `widget_test.dart` | 1 | App boots with Supabase initialized |
| **A11y** | `accessibility_test.dart` | 2 | Localized tooltips |
| **A11y** | `contrast_audit_test.dart` | 3+ | WCAG contrast ratios |

### 1.2 Supabase SQL Test Fixtures (6 files)

| File | Tests | Coverage |
|------|-------|----------|
| `test_cod_payment.sql` | 11 | COD confirm, idempotency, non-owner reject, anonymous reject, non-COD reject, cancelled reject, already-paid, failed payment, status transitions, transaction ID |
| `test_paymob_callback.sql` | 8 | Valid callback, amount mismatch, duplicate no-op, late failure, unmapped payment, stock restore, admin transition (structural) |
| `test_payments_update_and_stock.sql` | 8 | Provider order ID set, non-owner reject, already_set, not_pending, service-role-only callback, stock functions auth, checkout+admin callable, idempotent callback |
| `test_rpc_authorization.sql` | 8 | get_order_details auth/ownership/admin, low_stock admin, callback service-role, decrement/increment service-role, provider order ID owner |
| `test_create_checkout_order.sql` | 7 (commented templates) | Success, insufficient stock, idempotency retry, rollback, server price, server shipping, unauthorized |
| `test_019_rpc_payments_hardening.sql` | 12 | PUBLIC blocked, authenticated allowed, callback service-role-only, payments INSERT policy dropped |

### 1.3 Edge Function Tests (3 files)

| File | Tests | Coverage |
|------|-------|----------|
| `hmac_test.ts` | 11 | Field count, canonical order, payload concat, missing fields, deterministic HMAC, secret sensitivity, value sensitivity, constant-time equals, valid/invalid/wrong-secret verification |
| `paymob_initiate_test.ts` | 4 | No secret leaks in success, no tokens in errors, no raw error logging, response contract documented |
| `cancel_expired_orders_test.ts` | 5 | Scheduler secret required, atomic RPC, service-role key, safe error handling, no secret leaks |

### 1.4 Coverage Gaps (High-Level)

| Gap | Severity |
|-----|----------|
| **No `integration_test/` directory** — zero Flutter integration tests | CRITICAL |
| **No E2E Paymob sandbox proof** — callback path untested end-to-end | CRITICAL |
| **Supabase repositories untested** — `SupabaseCatalogRepository`, `SupabaseOrdersRepository`, `SupabaseAuthRepository`, `SupabaseAdminRepository` have zero unit tests | HIGH |
| **`CheckoutService` untested** — the RPC-calling repository has no unit tests | HIGH |
| **`PaymobPaymentService` untested** — `initiatePayment`, `confirmCodPayment`, `watchPaymentStatus` have no unit tests | HIGH |
| **No RLS denial SQL tests** — RLS policies exist but no test proves a non-owner is denied | HIGH |
| **No admin abuse SQL tests** — non-admin cannot escalate to admin via `update_order_status` is structurally asserted, not runtime-tested | MEDIUM |
| **Crash reporting init untested** — `init()` + `setUser` in `main.dart` wiring is not tested | MEDIUM |
| **`test_create_checkout_order.sql` is commented out** — templates only, no assertions | MEDIUM |

---

## 2. Missing Critical Tests

### 2.1 Auth Session Restore (CRITICAL)

**Gap:** `SupabaseAuthRepository.checkSession()` and `authStateChanges` stream have no unit tests against the real repository. The `AuthCubit` tests use stubs, not the Supabase-mapping repository.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| AUTH-01 | `checkSession()` returns `null` when no session exists | Unit | App must show login on cold start without session |
| AUTH-02 | `checkSession()` returns `Authenticated(userId)` when session exists | Unit | App must restore session on relaunch |
| AUTH-03 | `authStateChanges` emits `Authenticated` on TOKEN_REFRESHED | Unit | Silent token refresh must not log user out |
| AUTH-04 | `authStateChanges` emits `null` on SIGNED_OUT | Unit | Server-initiated sign-out must clear session |
| AUTH-05 | `signUp` maps `AuthException` to user-safe message | Unit | Error mapping lives in data layer, untested |
| AUTH-06 | `signIn` maps "Invalid login credentials" → "Invalid email or password" | Unit | User must never see raw Supabase strings |
| AUTH-07 | Session restore on app cold start (integration) | Integration | End-to-end session persistence |

### 2.2 Catalog Loading from Supabase (HIGH)

**Gap:** `SupabaseCatalogRepository` has zero tests. The `CatalogCubit` tests use `StubCatalogRepository` with hardcoded data.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| CAT-01 | `fetchProducts()` maps DB rows to `Product` entities correctly | Unit | Variant join, price mapping, stock map derivation |
| CAT-02 | `fetchProducts()` uses in-memory cache within TTL | Unit | Avoids redundant network calls |
| CAT-03 | `fetchProducts()` falls back to persistent cache on network error | Unit | Offline resilience after app restart |
| CAT-04 | `fetchProducts()` falls back to in-memory cache on network error | Unit | Offline resilience same session |
| CAT-05 | `fetchProducts()` returns `Failure` when no cache + network error | Unit | Must not silently return empty |
| CAT-06 | `fetchCategories()` maps DB rows to category name list | Unit | Category filter population |
| CAT-07 | `findProductById()` returns cached product synchronously | Unit | Cart hydration depends on synchronous lookup |
| CAT-08 | `findProductById()` returns null on cache miss | Unit | Graceful degradation |
| CAT-09 | Catalog loads from Supabase and renders in HomePage (integration) | Integration | E2E catalog display |

### 2.3 Cart Operations (MEDIUM — partially covered)

**Gap:** Cart merge and restore are tested, but quantity edge cases and stock-aware add are not.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| CART-01 | `add()` with quantity 0 is rejected | Unit | Prevents zero-quantity cart lines |
| CART-02 | `add()` with quantity exceeding stock is clamped | Unit | Cannot oversell |
| CART-03 | `remove()` non-existent key is a no-op | Unit | Defensive removal |
| CART-04 | `updateQuantity()` to 0 removes the item | Unit | Natural cart pruning |
| CART-05 | `clear()` empties the cart and persists | Unit | Post-checkout state |
| CART-06 | Cart survives app restart via SharedPreferences | Integration | Persistence contract |

### 2.4 Checkout RPC (HIGH)

**Gap:** `CheckoutService.placeOrder()` has zero unit tests. The `CheckoutCubit` tests use `MockCheckoutRepository`.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| CHK-01 | `placeOrder()` calls `create_checkout_order` RPC with correct params | Unit | Param mapping (items, address, idempotency key) |
| CHK-02 | `placeOrder()` parses RPC response into `PendingOrder` | Unit | orderId, subtotal, shipping, total, expiresAt |
| CHK-03 | `placeOrder()` maps `PostgrestException` to `Failure(AppError)` | Unit | Server error surface |
| CHK-04 | `placeOrder()` maps generic exception to `Failure` | Unit | Network error surface |
| CHK-05 | `placeOrder()` sends no price field (server-authoritative) | Unit | Client never sends price |
| CHK-06 | `placeOrder()` includes idempotency key when provided | Unit | Retry safety |
| CHK-07 | `placeOrder()` omits idempotency key param when null | Unit | Clean param shape |

### 2.5 COD Confirmation (PARTIALLY COVERED)

**Gap:** The cubit-level COD path is well-tested via stubs, but `PaymobPaymentService.confirmCodPayment()` (the real RPC caller) has zero unit tests.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| COD-01 | `confirmCodPayment()` calls `confirm_cod_payment` RPC with `p_order_id` | Unit | Correct param name |
| COD-02 | `confirmCodPayment()` parses `ok=true` → `PaymentSuccess` | Unit | Success path |
| COD-03 | `confirmCodPayment()` parses `ok=false` → `PaymentFailed` with code | Unit | Rejection path |
| COD-04 | `confirmCodPayment()` maps each code to user-safe message | Unit | 8 code → message mappings |
| COD-05 | `confirmCodPayment()` maps network error → `code: 'network_error'` | Unit | Connectivity failure |
| COD-06 | COD success end-to-end (integration) | Integration | Full COD checkout → confirm |

### 2.6 Paymob Success (CRITICAL — E2E unproven)

**Gap:** `PaymobPaymentService.initiatePayment()` and `watchPaymentStatus()` have zero unit tests. The `PaymentCubit` tests use stubs. No E2E sandbox test exists.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| PAY-S-01 | `initiatePayment()` invokes `paymob-initiate` Edge Function | Unit | Correct function name + body |
| PAY-S-02 | `initiatePayment()` parses `checkout_url` → `PaymentPending` | Unit | Success initiation |
| PAY-S-03 | `initiatePayment()` returns `PaymentFailed` on non-200 | Unit | Error surface |
| PAY-S-04 | `initiatePayment()` returns `PaymentFailed` on missing `checkout_url` | Unit | Malformed response |
| PAY-S-05 | `watchPaymentStatus()` emits `PaymentSuccess` on `status='success'` | Unit | Realtime callback → terminal state |
| PAY-S-06 | `watchPaymentStatus()` emits `PaymentFailed` on `status='failed'` | Unit | Realtime callback → failure |
| PAY-S-07 | `watchPaymentStatus()` ignores non-terminal status updates | Unit | No premature terminal |
| PAY-S-08 | `watchPaymentStatus()` unsubscribes channel on cancel | Unit | No listener leak |
| PAY-S-09 | Paymob sandbox success E2E (integration) | Integration | Full Paymob card success flow |

### 2.7 Paymob Failure (CRITICAL)

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| PAY-F-01 | `watchPaymentStatus()` emits `PaymentFailed` with declined message | Unit | Declined card |
| PAY-F-02 | Server failure callback does not downgrade a paid order | SQL (exists) | Already in `test_paymob_callback.sql` T10 |
| PAY-F-03 | Failed payment restores stock exactly once | SQL (exists) | Already in `test_paymob_callback.sql` T12 |
| PAY-F-04 | Paymob sandbox decline E2E (integration) | Integration | Full declined card flow |

### 2.8 Paymob Cancel (HIGH)

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| PAY-C-01 | User cancels hosted checkout → cubit emits `cancelled` | Unit | Already covered in `payment_checkout_flow_test.dart` |
| PAY-C-02 | Cancel does not mutate payment/order state | SQL | Order stays `pending`, payment stays `pending` |
| PAY-C-03 | User can retry after cancel | Integration | Cancel → re-initiate → success |

### 2.9 Invalid HMAC Rejection (COVERED)

**Gap:** Covered in `hmac_test.ts` (Edge Function) and `test_paymob_callback.sql` (SQL). No additional tests needed, but E2E is unproven.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| HMAC-01 | `verifyHmac` rejects invalid signature | Unit (exists) | ✅ `hmac_test.ts` |
| HMAC-02 | `verifyHmac` rejects wrong secret | Unit (exists) | ✅ `hmac_test.ts` |
| HMAC-03 | Callback returns 401 on invalid HMAC | E2E | Paymob callback rejection |
| HMAC-04 | HMAC field order is canonical (20 fields) | Unit (exists) | ✅ `hmac_test.ts` |

### 2.10 Amount Mismatch Rejection (COVERED in SQL)

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| AMT-01 | `process_paymob_callback` rejects mismatched amount | SQL (exists) | ✅ `test_paymob_callback.sql` T8 |
| AMT-02 | Edge Function validates `amount_cents` is parseable | Unit | Malformed amount → 400 |
| AMT-03 | Edge Function rejects negative amount | Unit | Defensive parsing |

### 2.11 RLS Denial Cases (HIGH — missing)

**Gap:** RLS policies exist in `002_rls_policies.sql` but no SQL test proves a non-owner is denied. The `test_rpc_authorization.sql` is structural only.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| RLS-01 | Non-owner cannot SELECT another user's order | SQL | `orders_select_own` enforcement |
| RLS-02 | Non-owner cannot SELECT another user's order_items | SQL | `order_items_select_own` enforcement |
| RLS-03 | Anonymous user cannot SELECT orders | SQL | No auth → no rows |
| RLS-04 | Anonymous user cannot INSERT into orders | SQL | No auth → no insert (checkout RPC bypasses via SECURITY DEFINER) |
| RLS-05 | Non-owner cannot DELETE another user's address | SQL | `addresses_delete_own` enforcement |
| RLS-06 | Non-owner cannot UPDATE another user's cart_items | SQL | `cart_update_own` enforcement |
| RLS-07 | No INSERT policy on payments (RLS default-deny) | SQL (exists) | ✅ `test_019_rpc_payments_hardening.sql` T12 |

### 2.12 Admin Abuse Cases (HIGH — missing runtime tests)

**Gap:** `update_order_status` is structurally asserted as admin-only, but no runtime test proves a non-admin is rejected.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| ADM-01 | Non-admin calling `update_order_status` is rejected | SQL | Privilege escalation prevention |
| ADM-02 | Non-admin calling `get_low_stock_products` is rejected | SQL | Admin-only data access |
| ADM-03 | Non-admin cannot SELECT all orders (only own) | SQL | `orders_select_own` limits scope |
| ADM-04 | Admin can SELECT all orders (bypass) | SQL | Admin fulfillment works |
| ADM-05 | `SupabaseAdminRepository.isCurrentUserAdmin()` returns false for non-admin | Unit | Gate UI access |
| ADM-06 | `SupabaseAdminRepository.isCurrentUserAdmin()` returns true for admin | Unit | Gate UI access |
| ADM-07 | Admin dashboard denies access for non-admin user (widget) | Widget | UI guard |

### 2.13 Orders Release Repository (HIGH — missing)

**Gap:** `SupabaseOrdersRepository.readOrders()` has zero unit tests. Row mapping, RLS-based filtering, and error handling are untested.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| ORD-01 | `readOrders()` returns empty list when user has no orders | Unit | Empty state |
| ORD-02 | `readOrders()` maps DB rows to `Order` entities | Unit | Row → entity mapping |
| ORD-03 | `readOrders()` maps nested `order_items` to `CartItem` list | Unit | Join mapping |
| ORD-04 | `readOrders()` maps `address_snapshot` JSONB to `Address` | Unit | Address snapshot rendering |
| ORD-05 | `readOrders()` returns `Failure` when not authenticated | Unit | No `currentUser` |
| ORD-06 | `readOrders()` returns `Failure` on network error | Unit | Error surface |
| ORD-07 | `writeOrders()` is a no-op returning `Success(null)` | Unit | Server-authoritative contract |

### 2.14 Address Snapshot Rendering (MEDIUM — partially covered)

**Gap:** `checkout_address_test.dart` tests the cubit, but the `_mapAddress` in `SupabaseOrdersRepository` is untested.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| ADDR-01 | `placeOrder()` includes all address fields in snapshot | Unit (exists) | ✅ `checkout_cubit_test.dart` |
| ADDR-02 | `_mapAddress()` handles missing `id` field (defaults to '') | Unit | Defensive parsing |
| ADDR-03 | `_mapAddress()` handles missing `country` field | Unit | Defensive parsing |
| ADDR-04 | `address_snapshot` renders correctly in order detail UI | Widget | Address display |
| ADDR-05 | `address_snapshot` survives order restore | Unit (exists) | ✅ `checkout_address_test.dart` |

### 2.15 Stock Decrement (COVERED in SQL)

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| STK-01 | `create_checkout_order` decrements stock atomically | SQL (template) | ✅ `test_create_checkout_order.sql` T1 (commented) |
| STK-02 | Insufficient stock raises exception, no stock change | SQL (template) | ✅ `test_create_checkout_order.sql` T2 (commented) |
| STK-03 | Failed payment restores stock exactly once | SQL (exists) | ✅ `test_paymob_callback.sql` T12 |
| STK-04 | `decrement_stock` is service-role-only | SQL (exists) | ✅ `test_payments_update_and_stock.sql` T6 |
| STK-05 | `increment_stock` is service-role-only | SQL (exists) | ✅ `test_payments_update_and_stock.sql` T7 |

### 2.16 Idempotency (PARTIALLY COVERED)

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| IDEM-01 | Retry with same idempotency key reuses key | Unit (exists) | ✅ `checkout_cubit_test.dart` |
| IDEM-02 | Different checkout attempts get different keys | Unit (exists) | ✅ `checkout_cubit_test.dart` |
| IDEM-03 | Idempotent retry returns existing order | Unit (exists) | ✅ `checkout_cubit_test.dart` |
| IDEM-04 | COD duplicate confirmation is idempotent | Unit (exists) | ✅ `cod_server_confirm_test.dart` |
| IDEM-05 | Duplicate Paymob callback is a no-op | SQL (exists) | ✅ `test_paymob_callback.sql` T9 |
| IDEM-06 | `create_checkout_order` idempotency at DB level | SQL (template) | ⚠️ `test_create_checkout_order.sql` T3 (commented, needs activation) |

### 2.17 Crash Reporting Initialization (MEDIUM — missing)

**Gap:** `CrashReportingService.scrubContext()` is tested, but the `init()` + `setUser()` wiring in `main.dart` is untested.

| ID | Test | Type | Why Critical |
|----|------|------|--------------|
| CRASH-01 | `NoOpCrashReportingService.init()` does not throw | Unit (exists) | ✅ `crash_reporting_scrub_test.dart` |
| CRASH-02 | `NoOpCrashReportingService.setUser(null)` does not throw | Unit (exists) | ✅ `crash_reporting_scrub_test.dart` |
| CRASH-03 | App initializes crash reporting before `runApp` | Integration | `main.dart` wiring |
| CRASH-04 | Crash reporting receives `FlutterError.onError` events | Integration | Zone error capture |
| CRASH-05 | `scrubContext` redacts nested sensitive keys | Unit | Deep redaction |

---

## 3. Recommended Unit Tests

### 3.1 `SupabaseAuthRepository` (AUTH-01 to AUTH-06)
- **File:** `test/supabase_auth_repository_test.dart`
- **Approach:** Mock `SupabaseClient` / `GoTrueClient` via a thin wrapper, or use `supabase_flutter` test helpers if available. Alternatively, extract `_mapAuthError` as a pure function and test it directly.
- **Tests:** 6
- **Effort:** M (Supabase mocking is non-trivial; may require extracting a `GoTrueClient` interface)

### 3.2 `SupabaseCatalogRepository` (CAT-01 to CAT-08)
- **File:** `test/supabase_catalog_repository_test.dart`
- **Approach:** Mock `SupabaseClient` `from('products').select(...)` chain. Test cache TTL logic, persistent cache fallback, and row mapping. Inject `SharedPreferences` mock.
- **Tests:** 8
- **Effort:** M-H (PostgREST query chain mocking is verbose)

### 3.3 `SupabaseOrdersRepository` (ORD-01 to ORD-07)
- **File:** `test/supabase_orders_repository_test.dart`
- **Approach:** Mock `SupabaseClient` query chain. Test `_mapOrder`, `_mapOrderItem`, `_mapAddress`, `_parseStatus`. Test unauthenticated path.
- **Tests:** 7
- **Effort:** M

### 3.4 `CheckoutService` (CHK-01 to CHK-07)
- **File:** `test/checkout_service_test.dart`
- **Approach:** Mock `SupabaseClient.rpc('create_checkout_order', ...)`. Test param mapping, response parsing, error mapping. Assert no `price` field is sent.
- **Tests:** 7
- **Effort:** S-M

### 3.5 `PaymobPaymentService` (PAY-S-01 to PAY-S-08, COD-01 to COD-06)
- **File:** `test/paymob_payment_service_test.dart`
- **Approach:** Mock `SupabaseClient.functions.invoke(...)` and `_client.rpc(...)`. For `watchPaymentStatus`, mock `RealtimeChannel` and drive the callback payload. Test all 8 COD code→message mappings.
- **Tests:** 14
- **Effort:** M-H (Realtime channel mocking is complex)

### 3.6 `SupabaseAdminRepository` (ADM-05, ADM-06)
- **File:** `test/supabase_admin_repository_test.dart`
- **Approach:** Mock `SupabaseClient`. Test `isCurrentUserAdmin()` with admin=true, admin=false, and no current user.
- **Tests:** 3
- **Effort:** S

### 3.7 Cart Edge Cases (CART-01 to CART-05)
- **File:** extend `test/cart_cubit_test.dart`
- **Approach:** Use `MemoryStorefrontPersistence` with products that have stock limits.
- **Tests:** 5
- **Effort:** S

### 3.8 Crash Reporting Deep Redaction (CRASH-05)
- **File:** extend `test/crash_reporting_scrub_test.dart`
- **Approach:** Test nested map keys, case variations, partial matches.
- **Tests:** 2
- **Effort:** S

**Unit test subtotal:** ~52 new tests

---

## 4. Recommended Widget Tests

### 4.1 Admin Access Denial (ADM-07)
- **File:** `test/admin_access_test.dart`
- Test that the admin dashboard route redirects non-admin users.
- **Tests:** 1
- **Effort:** S

### 4.2 Address Snapshot Rendering (ADDR-04)
- **File:** `test/order_address_rendering_test.dart`
- Test that `order.address` renders recipient, line, city in the order card.
- **Tests:** 2
- **Effort:** S

### 4.3 Crash Reporting `main.dart` Wiring (CRASH-03, CRASH-04)
- **File:** `test/main_crash_wiring_test.dart`
- Test that `FlutterError.onError` calls `CrashReportingService.captureError`.
- **Tests:** 2
- **Effort:** M (requires testing `main()` bootstrap)

**Widget test subtotal:** ~5 new tests

---

## 5. Recommended Integration Tests

> **Note:** `integration_test/` directory does not exist. Create it at `integration_test/` per Flutter's convention.

### 5.1 P0 — Auth Session Restore (AUTH-07)
- **File:** `integration_test/auth_session_restore_test.dart`
- **Scenario:** Sign in → kill app → relaunch → verify session restored → verify home page loads
- **Dependencies:** Staging Supabase project with test user
- **Effort:** M

### 5.2 P0 — Paymob Sandbox Success E2E (PAY-S-09)
- **File:** `integration_test/paymob_success_test.dart`
- **Scenario:** Add to cart → checkout → select Paymob card → initiate payment → open sandbox checkout URL → submit test card → verify `PaymentStatus.success` → verify order status `paid`
- **Dependencies:** Paymob sandbox credentials, staging Supabase, test card `4111 1111 1111 1111`
- **Effort:** L (WebView automation is complex; may require `flutter_test` driver + Paymob sandbox)

### 5.3 P0 — Paymob Sandbox Failure E2E (PAY-F-04)
- **File:** `integration_test/paymob_failure_test.dart`
- **Scenario:** Checkout → Paymob card → submit decline test card → verify `PaymentStatus.failed` → verify stock restored
- **Dependencies:** Paymob decline test card `4000 0000 0000 0002`
- **Effort:** L

### 5.4 P1 — COD Checkout E2E (COD-06)
- **File:** `integration_test/cod_checkout_test.dart`
- **Scenario:** Add to cart → checkout → select COD → confirm → verify order `paid` → verify order appears in orders list
- **Dependencies:** Staging Supabase
- **Effort:** M

### 5.5 P1 — Catalog Loads from Supabase (CAT-09)
- **File:** `integration_test/catalog_load_test.dart`
- **Scenario:** Launch app → verify catalog page loads products from staging DB → verify product names match seeded data
- **Dependencies:** Staging Supabase with `016_seed_product_catalog.sql` applied
- **Effort:** S-M

### 5.6 P1 — Cart Persistence Across Restart (CART-06)
- **File:** `integration_test/cart_persistence_test.dart`
- **Scenario:** Add items to cart → kill app → relaunch → verify cart restored from SharedPreferences
- **Dependencies:** None (local storage only)
- **Effort:** S-M

### 5.7 P2 — Paymob Cancel + Retry (PAY-C-03)
- **File:** `integration_test/paymob_cancel_retry_test.dart`
- **Scenario:** Checkout → initiate Paymob → cancel → re-initiate → success
- **Dependencies:** Paymob sandbox
- **Effort:** M

### 5.8 P2 — Invalid HMAC E2E (HMAC-03)
- **File:** `integration_test/hmac_rejection_test.dart`
- **Scenario:** POST to `paymob-callback` Edge Function with invalid HMAC → verify 401 response → verify no payment/order state changed
- **Dependencies:** Staging Supabase Edge Function URL
- **Effort:** S-M (can be a Dart HTTP test, not a full app integration)

**Integration test subtotal:** ~8 new test scenarios

---

## 6. Recommended Supabase SQL Tests

### 6.1 RLS Denial Cases (RLS-01 to RLS-06)
- **File:** `supabase/tests/test_rls_denial.sql`
- **Approach:** Use `set_config('request.jwt.claims', ...)` to simulate authenticated/non-owner/anonymous callers. Assert row counts are 0 for denied access.
- **Tests:** 6
- **Effort:** M (JWT claim simulation in SQL is fiddly but proven by `test_cod_payment.sql`)

### 6.2 Admin Abuse Runtime Cases (ADM-01 to ADM-04)
- **File:** `supabase/tests/test_admin_authorization.sql`
- **Approach:** Simulate non-admin JWT calling `update_order_status` → expect exception. Simulate admin JWT → expect success.
- **Tests:** 4
- **Effort:** M

### 6.3 Activate `test_create_checkout_order.sql` (IDEM-06, STK-01, STK-02)
- **File:** `supabase/tests/test_create_checkout_order.sql` (rewrite)
- **Approach:** Convert commented templates into executable assertions with `set_config` JWT simulation. Add `SELECT assert(...)` or row-count checks.
- **Tests:** 7 (uncomment + assert)
- **Effort:** M (needs real seeded product UUIDs in staging)

### 6.4 Amount Mismatch Edge Cases (AMT-02, AMT-03)
- **File:** extend `supabase/tests/test_paymob_callback.sql`
- **Approach:** Test malformed `amount_cents` (string, negative, NaN).
- **Tests:** 2
- **Effort:** S

**SQL test subtotal:** ~19 new test cases

---

## 7. Recommended Edge Function Tests

### 7.1 `paymob-callback` Integration Test (HMAC-03, AMT-02, AMT-03)
- **File:** `supabase/functions/paymob-callback/callback_integration_test.ts`
- **Approach:** Use Deno test with a mock `Request` object. Test the full request → response pipeline with crafted payloads. Assert HTTP status codes and that no DB mutations occur on rejection.
- **Tests:** 5
- **Effort:** M (requires mocking `createClient` or using a test Supabase instance)

### 7.2 `paymob-initiate` Auth + Ownership Test
- **File:** `supabase/functions/paymob-initiate/paymob_initiate_auth_test.ts`
- **Approach:** Test that missing `Authorization` header returns 401. Test that non-owner `order_id` returns 404. Test that non-pending order returns 400.
- **Tests:** 3
- **Effort:** M (source analysis or mock Supabase)

### 7.3 `cancel-expired-orders` Functional Test
- **File:** `supabase/functions/cancel-expired-orders/cancel_expired_orders_functional_test.ts`
- **Approach:** Test that missing `x-scheduler-secret` returns 401. Test that wrong secret returns 401.
- **Tests:** 2
- **Effort:** S

**Edge Function test subtotal:** ~10 new tests

---

## 8. Priority Order

### Tier 1 — CRITICAL (blocks staging acceptance)
| Priority | ID | Test | Effort |
|----------|----|----|---------|
| 1 | PAY-S-09 | Paymob sandbox success E2E | L |
| 2 | PAY-F-04 | Paymob sandbox failure E2E | L |
| 3 | AUTH-07 | Auth session restore integration | M |
| 4 | COD-06 | COD checkout E2E | M |
| 5 | PAY-S-01..08 | `PaymobPaymentService` unit tests | M-H |
| 6 | COD-01..06 | `confirmCodPayment` unit tests | S-M |

### Tier 2 — HIGH (security + data integrity)
| Priority | ID | Test | Effort |
|----------|----|----|---------|
| 7 | CHK-01..07 | `CheckoutService` unit tests | S-M |
| 8 | CAT-01..08 | `SupabaseCatalogRepository` unit tests | M-H |
| 9 | ORD-01..07 | `SupabaseOrdersRepository` unit tests | M |
| 10 | RLS-01..06 | RLS denial SQL tests | M |
| 11 | ADM-01..04 | Admin abuse SQL tests | M |
| 12 | AUTH-01..06 | `SupabaseAuthRepository` unit tests | M |

### Tier 3 — MEDIUM (completeness + robustness)
| Priority | ID | Test | Effort |
|----------|----|----|---------|
| 13 | CAT-09 | Catalog loads from Supabase integration | S-M |
| 14 | CART-06 | Cart persistence integration | S-M |
| 15 | ADM-05..07 | Admin repository unit + widget | S |
| 16 | IDEM-06 | Activate checkout idempotency SQL | M |
| 17 | CRASH-03..05 | Crash reporting wiring | M |
| 18 | CART-01..05 | Cart edge cases | S |
| 19 | ADDR-02..04 | Address snapshot rendering | S |
| 20 | PAY-C-03 | Paymob cancel + retry integration | M |

### Tier 4 — LOW (polish)
| Priority | ID | Test | Effort |
|----------|----|----|---------|
| 21 | HMAC-03 | Invalid HMAC E2E | S-M |
| 22 | AMT-02..03 | Amount edge cases | S |
| 23 | Edge Function auth tests | paymob-initiate + cancel-expired | M |

---

## 9. Effort Estimates

| Workstream | New Tests | Effort | Notes |
|------------|-----------|--------|-------|
| **Flutter unit tests** | ~52 | 3-4 days | Supabase mocking is the main cost |
| **Flutter widget tests** | ~5 | 0.5 day | |
| **Flutter integration tests** | ~8 scenarios | 3-5 days | Paymob E2E is the bottleneck (WebView automation) |
| **Supabase SQL tests** | ~19 cases | 1.5-2 days | JWT claim simulation is proven |
| **Edge Function tests** | ~10 | 1-1.5 days | Mock Supabase client or source analysis |
| **Total** | **~94 test cases** | **9-13 days** | |

### Effort Breakdown by Risk

| Risk Area | Tests | Effort | Risk if Untested |
|-----------|-------|--------|------------------|
| Paymob E2E (success + failure) | 2 | 3-4 days | **Production payment failure unproven** |
| Paymob service unit tests | 14 | 1.5 days | Realtime callback parsing unverified |
| Checkout service unit tests | 7 | 0.5 day | RPC param mapping unverified |
| Supabase repositories | 21 | 2 days | Data layer mapping unverified |
| RLS + admin SQL tests | 10 | 1 day | Security boundary unproven at runtime |
| Auth repository | 6 | 1 day | Session restore unproven |
| Integration tests (non-Paymob) | 6 | 2 days | E2E flows unproven |

### Key Assumptions
- Staging Supabase project is accessible with test users seeded
- Paymob sandbox credentials are available
- `supabase_flutter` can be mocked at the `SupabaseClient` level (may require extracting interfaces if the package doesn't support mocking natively)
- WebView automation for Paymob checkout may require `integration_test` + `webview_flutter` test helpers, or a fallback approach using direct HTTP calls to the Edge Function

### Recommended First Sprint (highest impact, 3 days)
1. `PaymobPaymentService` unit tests (PAY-S-01..08, COD-01..06) — 1.5 days
2. `CheckoutService` unit tests (CHK-01..07) — 0.5 day
3. COD checkout integration test (COD-06) — 1 day

### Recommended Second Sprint (security proof, 2 days)
1. RLS denial SQL tests (RLS-01..06) — 1 day
2. Admin abuse SQL tests (ADM-01..04) — 1 day

### Recommended Third Sprint (E2E proof, 3-4 days)
1. Paymob sandbox success E2E (PAY-S-09)
2. Paymob sandbox failure E2E (PAY-F-04)
3. Auth session restore integration (AUTH-07)

---

## Summary

The project has solid unit-test coverage for **cubit/presentation logic** (170+ tests) and **SQL security fixtures** (6 files covering COD, Paymob callback, RPC authorization, and payments hardening). However, three critical gaps exist:

1. **No integration tests** — the `integration_test/` directory is absent. No end-to-end flow is proven.
2. **No Paymob sandbox proof** — the payment success/failure paths are tested only via stubs at the cubit level. The real `PaymobPaymentService` (Edge Function invocation, Realtime subscription) has zero unit tests, and no sandbox E2E test exists.
3. **Supabase data layer untested** — `SupabaseCatalogRepository`, `SupabaseOrdersRepository`, `SupabaseAuthRepository`, `CheckoutService`, and `PaymobPaymentService` have no unit tests. Row mapping, error handling, and cache logic are all unverified.

The highest-risk untested path is the **Paymob card success flow**: Edge Function initiation → WebView checkout → Paymob callback → HMAC verification → `process_paymob_callback` RPC → Realtime subscription → `PaymentStatus.success`. Each segment has tests, but the full chain has never been proven end-to-end.
