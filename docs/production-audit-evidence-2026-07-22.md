# Al Batal Elite — Independent Production Audit Evidence

| Field | Value |
|-------|--------|
| **Date** | 2026-07-22 |
| **Mode** | READ-ONLY code inspection (L1). No source fixes applied. |
| **Baseline commit** | `37118b1e8e745ee6d971f1ab1008c1a50fe9a9d6` |
| **Branch** | `fix/post-audit-production-repair` |
| **Working tree** | Dirty (~164 short-status lines; uncommitted local repairs present) |
| **Constraints read** | `AGENTS.md`, `loop-constraints.md` (L1 report-only; no L2 edits) |
| **Prior auditor reports** | **Not read** for this pass (`report.md` excluded from evidence basis) |
| **Live systems** | Not connected (no Supabase project, no Paymob dashboard, no CI run) |

---

## 0. Classification legend

| Label | Meaning |
|-------|---------|
| **proven** | Defect or property follows necessarily from inspected source |
| **code-inspected** | Inspected in repo; behavior not executed |
| **external-required** | Needs staging DB, Paymob, CI runner, or device |
| **not-verified** | Must not be claimed complete |

Severity scale for this document: **P0** ship-blocker for real money/users · **P1** launch-blocker · **P2** hardening · **P3** polish/docs.

---

## 1. Executive summary

Al Batal Elite implements a **server-authoritative checkout path** (`create_checkout_order` RPC) and a **hardened Paymob callback design** (HMAC fail-closed, payment lookup by `paymob_order_id`, amount/currency checks, no orphan payments, `process_paymob_callback` restricted to `service_role` in migration 015).

**It is not production-ready for real commerce traffic.**

Hard blockers proven in code:

1. **COD is client-only success** while the server order remains `pending` with a 15-minute expiry that cancels and restores stock.
2. **Paymob success after order expiry** can mark payment `success` while the order stays `cancelled` and stock is restored.
3. **Customer “Active” orders omit `paid`**, so successful card payments disappear from history tabs until admin advances status.
4. **Release hygiene**: large dirty worktree; untracked migrations on disk; docs that over-check readiness without staging evidence.

Positive architecture (not a ship green light): feature-first Clean Architecture, GetIt repos (cubits not in DI), server-computed money, Edge Function secrets not read by Flutter `EnvConfig`.

---

## 2. End-to-end flow traces (as coded)

### 2.1 Card (Paymob) happy path

```
CheckoutPage
  → CheckoutCubit.createPendingOrder
    → CheckoutService.placeOrder
      → RPC create_checkout_order
         (auth.uid, server prices/stock, INSERT order status=pending,
          expires_at=now()+15m, decrement stock, clear server cart_items)
  → PaymentMethodPage (args: orderId, total, email)
  → PaymentCubit.processPayment (paymob)
    → PaymobPaymentService → Edge paymob-initiate
         (JWT, load order total from DB, insert/reuse pending payment,
          Paymob auth/order/key, set paymob_order_id via RPC)
    → WebView paymob-checkout (URL guard)
    → Paymob POST → Edge paymob-callback
         (HMAC fail-closed → service_role process_paymob_callback)
         → payment success + order pending→paid (if still pending)
  → Realtime watch → PaymentStatus.success → clear local cart → order-success
```

### 2.2 COD path (broken)

```
create_checkout_order → order pending + stock reserved + 15m expiry
  → PaymentCubit COD branch emits local success + fake COD-* txn
  → UI success + cart clear
  → NO server promote / NO durable payment success
  → cancel-expired-orders / expire_pending_order → cancel + stock restore
```

### 2.3 Expiry path

```
Scheduler secret → cancel-expired-orders
  → expire_pending_order (service_role)
  → orders cancelled if still pending & past expires_at
  → payments pending → expired
  → order_items.restored = true → stock restore trigger
```

---

## 3. Findings

### P0

#### AUD-P0-01 — COD success is local-only; server auto-cancels

| Field | Content |
|-------|---------|
| **Severity** | P0 |
| **Location** | `lib/features/payments/presentation/cubit/payment_cubit.dart:120-127`; `supabase/migrations/013_atomic_checkout_rpc.sql:156-170`; `supabase/migrations/015_payments_update_and_stock_hardening.sql:154-197`; success UI `lib/features/payments/presentation/pages/payment_method_page.dart:85-99` |
| **Evidence** | COD branch only emits `PaymentStatus.success` with `COD-${timestamp}`. No RPC. Checkout always creates `pending` + 15m expiry. Expiry cancels pending and restores stock. |
| **Exploit / failure** | Customer places COD → success screen → within ~15 minutes order is cancelled and stock restored; warehouse never fulfills; customer believes order exists. |
| **Affected flow** | COD checkout / order lifecycle / inventory |
| **Acceptance test** | Staging: place COD; wait > expires_at; assert order still fulfillable (or COD disabled); assert stock not restored incorrectly. |
| **Classification** | **proven** |

#### AUD-P0-02 — Late Paymob success after expiry: charged + cancelled + stock restored

| Field | Content |
|-------|---------|
| **Severity** | P0 |
| **Location** | `014_paymob_security_repair.sql:348-364` (payment always success on `p_success`; order update only if `pending`); `015:...:expire_pending_order` cancels + restores independently |
| **Evidence** | Success path sets `payments.status = success` unconditionally for non-terminal payment, then promotes order only when `status = pending`. No reverse coupling if order already cancelled. |
| **Exploit / failure** | User pays near/after 15m; worker expires first (stock +1); Paymob success arrives; customer charged; order cancelled; inventory inflated. |
| **Affected flow** | Paymob success / expiry / inventory / finance |
| **Acceptance test** | Staging race: expire order then inject valid success callback; assert no payment success without fulfillable order (or automated refund queue). |
| **Classification** | **proven** (race timing **external-required**) |

#### AUD-P0-03 — Dirty release baseline (~164 dirty paths; untracked migrations)

| Field | Content |
|-------|---------|
| **Severity** | P0 (release hygiene) |
| **Location** | git worktree on `fix/post-audit-production-repair`; untracked `supabase/migrations/018_*.sql`, `019_*.sql` observed in status sampling |
| **Evidence** | `git status --short` non-empty at baseline; HEAD `37118b1` does not equal full working tree content. |
| **Exploit / failure** | Staging/prod deploy from wrong tree; privilege migrations present locally but not committed; unreproducible builds. |
| **Affected flow** | CI/CD / migrations / ops |
| **Acceptance test** | Clean commit/PR; CI green on that SHA; migration list matches applied DB. |
| **Classification** | **proven** |

#### AUD-P0-04 — `process_paymob_callback` PUBLIC grant in 014 (must be superseded by 015 live)

| Field | Content |
|-------|---------|
| **Severity** | P0 if 015 not applied; mitigated in source chain by 015 |
| **Location** | `014_paymob_security_repair.sql:410` `GRANT EXECUTE ... TO PUBLIC`; fix `015_payments_update_and_stock_hardening.sql:89-90` service_role only |
| **Evidence** | 014 intentionally grants PUBLIC; 015 revokes and grants service_role. Deploy without 015 = customer can invoke SECURITY DEFINER callback RPC with forged provider ids if they know/guess `paymob_order_id`. |
| **Exploit / failure** | Direct PostgREST RPC call forging payment success (if payment row exists and amount matches). |
| **Affected flow** | Payment authorization |
| **Acceptance test** | `has_function_privilege` for anon/authenticated = false; service_role = true on staging. |
| **Classification** | **code-inspected** (source fix present); **live apply external-required** |

---

### P1

#### AUD-P1-01 — Customer Active tab omits `OrderStatus.paid`

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `lib/features/storefront/presentation/cubit/orders_cubit.dart:36-42` |
| **Evidence** | Active = pending \| placed \| processing \| shipped only. Paymob success sets `paid` (014). Not in completed/cancelled either. |
| **Failure** | Paid order invisible in all customer tabs until admin moves status. |
| **Affected flow** | Order history / support |
| **Acceptance test** | After card pay, order appears under Active with paid semantics. |
| **Classification** | **proven** |

#### AUD-P1-02 — Order `payment_method` set before real method; default `"Credit Card"`

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `checkout_cubit.dart:14` default; `createPendingOrder` uses `state.payment` before PaymentMethodPage; real methods only later (COD vs Paymob). |
| **Evidence** | Order created with free-text method before selection; no server allowlist beyond non-empty string (013). |
| **Failure** | Ops/reports wrong method; cannot apply method-specific expiry/COD rules. |
| **Affected flow** | Checkout / admin / COD policy |
| **Acceptance test** | COD order stores cod; Paymob stores paymob_card; reject unknown. |
| **Classification** | **proven** |

#### AUD-P1-03 — Concurrent paymob-initiate can create multiple pending payments

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `supabase/functions/paymob-initiate/index.ts:180-249` select-then-insert without unique pending constraint |
| **Evidence** | Reuse latest pending if found; race between two initiates can both insert. |
| **Failure** | Double-tap / retry → two provider sessions; ambiguous callbacks. |
| **Affected flow** | Paymob initiate / idempotency |
| **Acceptance test** | Parallel initiate; assert ≤1 pending payment per order. |
| **Classification** | **proven** (concurrency **external-required**) |

#### AUD-P1-04 — Idempotency key returns cancelled/expired order forever

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `013_atomic_checkout_rpc.sql:82-101`; client reuses key `checkout_cubit.dart:129-135` |
| **Evidence** | Any existing row for (user, key) returned as-is including cancelled. |
| **Failure** | After expiry, retry reuses dead order → initiate “Order is not pending”. |
| **Affected flow** | Checkout retry |
| **Acceptance test** | Expire order; retry checkout; must create new pending order or clear key. |
| **Classification** | **proven** |

#### AUD-P1-05 — Failure callback restores stock without requiring cancel transition

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `014_paymob_security_repair.sql:381-392` |
| **Evidence** | Cancel if pending; **always** set `order_items.restored=true` where false, not gated on cancel rowcount. |
| **Failure** | Anomalous state (order not pending but payment pending) can restore stock while order open → oversell risk. |
| **Affected flow** | Paymob failure / inventory |
| **Acceptance test** | Inject fail callback against non-pending order; stock must not increase. |
| **Classification** | **proven** |

#### AUD-P1-06 — Auth redirect query ignored after sign-in

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `app_router.dart:60,79` sets `?redirect=`; `sign_in_page.dart:37` always `context.go('/home')` |
| **Evidence** | Redirect parameter never read. |
| **Failure** | Checkout/admin deep link lost after login. |
| **Affected flow** | Auth / navigation / conversion |
| **Acceptance test** | Unauth `/checkout` → sign-in → lands on checkout (allowlisted). |
| **Classification** | **proven** |

#### AUD-P1-07 — Flutter bundles `.env` as asset

| Field | Content |
|-------|---------|
| **Severity** | P1 |
| **Location** | `pubspec.yaml` assets includes `.env`; `EnvConfig` loads dotenv |
| **Evidence** | Asset packaging means env file contents can land in APK/IPA. Keys are public-ish (anon + URL) but pattern invites secret leakage; templates may still list Paymob server keys for humans. |
| **Failure** | Misconfigured secrets in client env file shipped to every install. |
| **Affected flow** | Secrets / client trust boundary |
| **Acceptance test** | Unpack release artifact; no server secrets present; document allowed client keys only. |
| **Classification** | **proven** (packaging); secret contents **not-verified** (values not read) |

#### AUD-P1-08 — Product images mapping without seed assets

| Field | Content |
|-------|---------|
| **Severity** | P1 (product completeness) |
| **Location** | catalog repository image mapping (working tree); seed `016` historically inserts products without complete image rows/uploads |
| **Evidence** | Mapping code exists; production catalog UX depends on Storage objects that are not guaranteed in seed. |
| **Failure** | Placeholder-only catalog in staging/prod. |
| **Affected flow** | Catalog / conversion |
| **Acceptance test** | Seeded product primary image loads from public bucket URL. |
| **Classification** | **code-inspected**; render **external-required** |

#### AUD-P1-09 — Docs overclaim payment/COD readiness

| Field | Content |
|-------|---------|
| **Severity** | P1 (process) |
| **Location** | `docs/release-readiness.md` checks COD, HMAC, stock restore, “14 migrations” as done |
| **Evidence** | COD client path contradicts COD “done”; migration count outdated vs 015–019 chain. |
| **Failure** | False production confidence. |
| **Affected flow** | Release governance |
| **Acceptance test** | Checklist items only checked with linked staging evidence. |
| **Classification** | **proven** (doc vs code mismatch) |

---

### P2

#### AUD-P2-01 — Open INSERT policies on notifications / analytics / error_logs

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `010_notifications_analytics.sql:61-74` `WITH CHECK (true)` |
| **Evidence** | Authenticated (or broader) clients can spam inserts if policies apply to those roles. |
| **Failure** | Storage DoS / fake notification history. |
| **Affected flow** | Observability tables |
| **Acceptance test** | Client insert denied; service_role/trigger only. |
| **Classification** | **code-inspected** |

#### AUD-P2-02 — `stock_restorations` created without RLS enable in 014

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `014_paymob_security_repair.sql` stock_restorations table (~195+) |
| **Evidence** | No `ENABLE ROW LEVEL SECURITY` observed in migration text for that table. |
| **Failure** | Depends on default grants; possible unexpected access. |
| **Affected flow** | Inventory ledger |
| **Acceptance test** | Live privilege matrix. |
| **Classification** | **code-inspected** |

#### AUD-P2-03 — Admin cancel of paid restores stock without refund state

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `014` `update_order_status` paid→cancelled + stock restore path |
| **Evidence** | Financial state incomplete (payment may remain success). |
| **Failure** | Accounting mismatch; inventory returned while money not refunded. |
| **Affected flow** | Admin fulfillment / finance |
| **Acceptance test** | Cancel paid requires refund workflow. |
| **Classification** | **code-inspected** |

#### AUD-P2-04 — Notification key length early-exit breaks pure constant-time

| Field | Content |
|-------|---------|
| **Severity** | P2 (Low practical if fixed-length high-entropy keys) |
| **Location** | `send-order-notification/index.ts:86-102` |
| **Evidence** | Length mismatch returns before byte loop. |
| **Failure** | Theoretical timing oracle on secret length. |
| **Affected flow** | Internal notification auth |
| **Acceptance test** | Hash both sides then fixed-length compare. |
| **Classification** | **proven** |

#### AUD-P2-05 — cancel-expired-orders secret uses non-constant-time `!==`

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `cancel-expired-orders/index.ts:25-31` |
| **Evidence** | String inequality compare. |
| **Failure** | Theoretical timing leak (scheduler secret). |
| **Affected flow** | Expiry worker auth |
| **Acceptance test** | Constant-time compare; reject missing secret config. |
| **Classification** | **proven** |

#### AUD-P2-06 — Payment routes depend on `GoRouterState.extra`

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `app_router.dart:101-129` |
| **Evidence** | order-success, payment-method, paymob-checkout use `extra`. |
| **Failure** | Process death / cold start → empty orderId/checkout URL. |
| **Affected flow** | Navigation / payment resume |
| **Acceptance test** | Kill app mid-checkout; resume safe error, not blank success. |
| **Classification** | **proven** |

#### AUD-P2-07 — Guest cart policy vs auth-required `/cart`

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `app_router.dart:66-75` `/cart` auth-required |
| **Evidence** | Router blocks unauthenticated cart route. |
| **Failure** | Guest browse/add may work via cubit while cart page blocked — product inconsistency. |
| **Affected flow** | Guest shopping |
| **Acceptance test** | Policy matrix: guest can/cannot open cart and checkout as designed. |
| **Classification** | **proven** |

#### AUD-P2-08 — Admin dashboard may not load stats on entry

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | admin dashboard presentation (inspect load lifecycle) |
| **Evidence** | Historical pattern: stats widgets without init load (verify on current tree before fixing). |
| **Failure** | Ops sees zeros. |
| **Affected flow** | Admin |
| **Acceptance test** | Open `/admin` → non-zero/loaded empty states with real data. |
| **Classification** | **code-inspected** (confirm UI load wiring on ship branch) |

#### AUD-P2-09 — Debug vs release OrdersRepository split

| Field | Content |
|-------|---------|
| **Severity** | P2 |
| **Location** | `service_locator.dart:65-68` |
| **Evidence** | Debug uses local orders; release Supabase. Local place/advance may still exist on cubit. |
| **Failure** | Debug false confidence; accidental client advance UI in release if exposed. |
| **Affected flow** | Order history integrity |
| **Acceptance test** | Release build: no local-only order mutation path. |
| **Classification** | **proven** (DI split) |

#### AUD-P2-10 — HMAC field list unit-tested only

| Field | Content |
|-------|---------|
| **Severity** | P2 → P0 if wrong in production merchant config |
| **Location** | `paymob-callback/hmac.ts`, `hmac_test.ts` |
| **Evidence** | Fail-closed and constant-time compare present; live Paymob account field order not proven. |
| **Failure** | All callbacks 401 if field order wrong. |
| **Affected flow** | Paymob |
| **Acceptance test** | Real sandbox callback sample verifies. |
| **Classification** | **code-inspected**; **external-required** |

---

### P3

#### AUD-P3-01 — Sentry / crash reporting init may not be fully awaited

| Field | Content |
|-------|---------|
| **Severity** | P3 |
| **Location** | bootstrap / `SentryCrashReportingService` |
| **Evidence** | Async init patterns can miss early crashes. |
| **Affected flow** | Observability |
| **Classification** | **code-inspected** |

#### AUD-P3-02 — Auth error strings not localized

| Field | Content |
|-------|---------|
| **Severity** | P3 |
| **Location** | auth data layer error mapping |
| **Affected flow** | EN/AR UX |
| **Classification** | **code-inspected** |

#### AUD-P3-03 — Client may still send amount fields ignored by initiate

| Field | Content |
|-------|---------|
| **Severity** | P3 |
| **Location** | Paymob client service vs initiate body contract |
| **Evidence** | Initiate documents server-only amount; dead client fields confuse trust model. |
| **Classification** | **code-inspected** |

#### AUD-P3-04 — Local keystore file present on disk (gitignored)

| Field | Content |
|-------|---------|
| **Severity** | P3 (ops) |
| **Location** | `release-keystore.jks` present; gitignored (`*.jks`) |
| **Evidence** | Not tracked; still a workstation risk if shared drives/backups. |
| **Classification** | **proven** (ignore + untracked) |

---

## 4. False positives and explicit non-findings

| Claim sometimes raised | This audit’s position |
|------------------------|----------------------|
| “Paymob tokens returned to client” | **Not found** in inspected initiate contract (returns `checkout_url` only). **not-verified** against deployed function logs. |
| “PUBLIC execute on process_paymob_callback still intended” | **False if 015 applied**. Source chain revokes PUBLIC. Live must prove. |
| “Atomic checkout missing” | **False** — 013 implements atomic RPC; live still **external-required**. |
| “Vodafone Cash active payment path” | **Not found** in current `PaymentCubit` methods (COD + Paymob). Residual docs only. |
| “Flutter reads Paymob API key” | **False** for `EnvConfig` (explicitly excluded). Templates may still list keys for humans. |
| “All RLS broken” | **Overclaim**. Orders insert denied + SECURITY DEFINER patterns present. Residual: open INSERT on analytics tables; privilege apply order matters. |
| “223 tests prove production” | **False**. Local unit tests ≠ RLS/Paymob/device/staging. **not-verified** this session (tests not re-run). |

### Assumptions (must not be treated as facts)

1. Migration chain 001→019 is applied in order on target environments.  
2. Edge secrets (`PAYMOB_*`, `NOTIFICATIONS_INTERNAL_KEY`, `CANCEL_EXPIRED_ORDERS_SECRET`, service role) are set correctly.  
3. Scheduler invokes cancel-expired-orders with secret on a schedule.  
4. Paymob merchant HMAC algorithm matches `hmac.ts`.  
5. Working tree repairs match eventual commit content.  

---

## 5. Architecture / trust boundary notes

| Boundary | Assessment |
|----------|------------|
| Client → checkout | Client sends ids/qty/address/idempotency; **not** prices — good (`checkout_service.dart`) |
| Client → Paymob initiate | Auth JWT; amount from DB — good |
| Paymob → callback | HMAC then service_role RPC — good design |
| Admin status | `update_order_status` checks `is_admin` — good design; grant must not be PUBLIC on prod (019 aims authenticated) |
| Cart/wishlist/addresses | Local SharedPreferences — multi-device not consistent; product decision |
| Orders in release | Supabase repository — good if wired; Active filter bug remains |

---

## 6. CI / release operations (inspection only)

| Topic | Status |
|-------|--------|
| Workflow exists | `.github/workflows/ci.yml` (working tree may differ from HEAD) |
| Green CI on current tree | **not-verified** |
| Android release + `.env` asset | Risk of missing/empty env at build — **code-inspected** |
| Signing | Keystore gitignored; CI secret wiring **external-required** |
| Deploy scripts | Present under `scripts/`; not executed |

---

## 7. Prioritized staging-blocker list

Ship or open real money **only after**:

| # | Blocker | Maps to |
|---|---------|---------|
| 1 | Resolve COD: server confirm **or** remove COD from UI | AUD-P0-01 |
| 2 | Prove/fix expiry vs success race (no charge without fulfillable order) | AUD-P0-02 |
| 3 | Freeze clean release commit; apply migrations including 015 (+ intentional 018/019) | AUD-P0-03, AUD-P0-04 |
| 4 | Privilege matrix: callback/stock/expire = service_role only | AUD-P0-04 |
| 5 | Live Paymob HMAC sandbox callback | AUD-P2-10 |
| 6 | Customer Active includes `paid` | AUD-P1-01 |
| 7 | payment_method lifecycle + allowlist | AUD-P1-02 |
| 8 | Single pending payment per order under double-tap | AUD-P1-03 |
| 9 | Checkout retry after expiry creates new order | AUD-P1-04 |
| 10 | Product images seed + bucket render | AUD-P1-08 |
| 11 | Auth post-login redirect allowlist | AUD-P1-06 |
| 12 | Release artifact contains no server secrets | AUD-P1-07 |
| 13 | cancel-expired-orders scheduled with secret | flow 2.3 |
| 14 | Reconcile release-readiness checklist to evidence only | AUD-P1-09 |
| 15 | Manual EN/AR device acceptance (checkout, admin, RTL) | external |

---

## 8. Commands and files inspected (this pass)

**Read/constraints:** `AGENTS.md`, `loop-constraints.md`  

**Git (read-only):** `git rev-parse HEAD`, `git branch --show-current`, `git status --short` (count), `git log --oneline -5`, `git check-ignore` for keystore/secrets  

**Core code:**  
`payment_cubit.dart`, `payment_method_page.dart`, `checkout_service.dart`, `checkout_cubit.dart`, `orders_cubit.dart`, `service_locator.dart`, `app_router.dart`, `sign_in_page.dart` (redirect usage), `env_config.dart`  

**Edge:** `paymob-callback/index.ts`, `paymob-initiate/index.ts` (partial + initiate payment create), `send-order-notification/index.ts`, `cancel-expired-orders/index.ts`  

**SQL:** `013_atomic_checkout_rpc.sql`, `014_paymob_security_repair.sql` (callback RPC), `015_payments_update_and_stock_hardening.sql`, greps across migrations for GRANT/REVOKE/RLS/WITH CHECK  

**Config:** `pubspec.yaml` assets, `.gitignore` secret patterns  

**Not done:** `flutter test`, `flutter analyze`, Deno tests, Supabase SQL apply, Paymob live, reading secret file values, reading prior `report.md` as authority  

---

## 9. Verdict

| Question | Answer |
|----------|--------|
| Production-ready for real payments? | **No** |
| Strongest subsystem on paper? | Server checkout + Paymob callback design (post-015) |
| Hardest code-proven money bugs? | **COD local success (P0-01)** and **pay-after-expiry split brain (P0-02)** |
| What must not be claimed? | Staging/RLS/Paymob/CI success without external evidence |

---

*End of independent audit evidence. Implementation suggestions in findings are diagnostic acceptance criteria only — not applied fixes.*
