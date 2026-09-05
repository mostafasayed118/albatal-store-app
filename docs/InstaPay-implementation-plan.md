# InstaPay Payment Method — Implementation Plan (UX parity item, backend-gated)

**Status:** PROPOSAL — awaiting owner decisions (D1–D4 below). No `supabase/` or
client changes are made until sign-off, per loop rules.
**Grounded in:** master `b716bc9` — migrations 001–040, edge functions, and the
payments feature as actually implemented.

---

## 1. What exists today (verified)

### Client (`lib/features/payments/`)

- `PaymentMethod` enum (`entities/payment.dart`): `paymobCard('Paymob Card', …, 'paymob_card')` and
  `cashOnDelivery('Cash on Delivery', …, 'cod')`. Each value carries a
  `serverValue` that is the canonical string stored in `orders.payment_method`.
- `PaymentService` (`domain/repositories/payment_service.dart`): `initiatePayment`,
  `confirmCodPayment`, `setOrderPaymentMethod`, `watchPaymentStatus`. The interface
  deliberately has **no** client-side `verifyPayment` — success is decided
  server-side (Paymob webhook / `confirm_cod_payment` RPC) and *observed* by the
  client via `watchPaymentStatus` (Realtime on `payments`).
- `SupabasePaymentService` (`data/paymob_payment_service.dart`) implements the above
  against the RPCs/edge functions.
- `PaymentCubit.processPayment` branches on the selected method:
  - `cashOnDelivery` → `setOrderPaymentMethod('cod')` → `confirmCodPayment` → success.
  - `paymobCard` → `setOrderPaymentMethod('card')`? (verified: card path currently
    relies on the order being created with `payment_method='card'`-compatible
    state; the initiate function re-reads method from the DB) → `initiatePayment`
    → WebView/URL flow → `watchPaymentStatus` until the webhook flips status.
- `PaymentMethodPage` renders the two `_PaymentOption` rows; the stepper was synced
  to Stitch in #35 (Address → Payment → Review).

### Database (verified against migrations)

- `payments` (migration 006): `id, order_id, user_id, method TEXT NOT NULL,
  amount INTEGER CHECK (>0), phone_number, transaction_id TEXT UNIQUE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','success','failed',
  'cancelled','expired','refunded'))` (constraint updated in 015). RLS: owner-only
  select/insert (006); Flutter never updates `payments` (015).
- `orders.payment_method TEXT NOT NULL` (001) — **no CHECK constraint** on values.
- `confirm_cod_payment(UUID)` (018, reworked 026/038): owner-only RPC; requires a
  COD-like stored method (`payment_not_cod` otherwise); atomically marks the
  payment `success` (server-generated transaction id) and the order `paid`.
- `set_pending_order_payment_method` (037/039): owner-only; allowlist
  **`('cod','card')`**; when switching to `cod`, ensures a pending COD payments row
  exists (039); audit-logs the change.
- `create_checkout_order` RPC (013/020): creates the pending order + snapshot
  server-side; accepts `p_payment_method` and stores it verbatim.
- Paymob path: `get_or_claim_paymob_payment(UUID)` (034) — the DB is the concurrency
  boundary; one pending card payment per order via partial unique index;
  `set_payment_provider_order_id` persists the provider bridge exactly once.

### Edge functions (`supabase/functions/`)

- `checkout/index.ts` — creates the order from JWT-authenticated context (never
  trusts client totals), passes `payment_method` through.
- `paymob-initiate/index.ts` — single-call initiation; reads amount/identity from
  DB; uses `get_or_claim_paymob_payment`; env: `PAYMOB_API_KEY`,
  `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID`; rejects non-card orders before any
  provider call; returns only `{ checkout_url }`.
- `paymob-callback/index.ts` — HMAC-verified webhook; flips `payments.status` and
  `orders.status`; the only writer of success for card payments.

---

## 2. What InstaPay actually is (constraints that shape the design)

- InstaPay is a **P2P bank-transfer rails** (IPN — Instant Payment Network) in
  Egypt. For merchants there is **no hosted-checkout + webhook product** like
  Paymob's. Common practical integrations:
  1. **Manual/wallet transfer + proof upload** — customer sends to a static
     InstaPay address (PSP), uploads a screenshot/reference; an **admin confirms
     manually** in a review queue.
  2. **Aggregator** — a PSP that offers InstaPay as a rails with an API +
     webhooks (e.g. via a local payment aggregator). Closest to the Paymob shape
     we already have; depends on the owner having such a contract.
  3. **Bank-provided instant-notification** — some banks push settlement
     notifications to a registered endpoint; bespoke per bank.

**This plan assumes (1) manual confirmation by default** — it is the only option
that works with zero third-party contract — and is structured so (2) can replace
the confirmation step later without schema churn.

---

## 3. Design (option 1: manual confirmation, reconciliation-friendly)

### 3.1 Data model — migration 041 `instapay_payment_method.sql` (forward-only, idempotent)

1. `payments.method` — **no enum/;** keep TEXT. Add a CHECK only if the owner wants
   strictness; recommend instead a small allowlist RPC surface (matches 037 style):
   nothing to change in 006.
2. `orders.payment_method` — add `'instapay'` to the 037/039 allowlists:
   `IF p_method IS NULL OR p_method NOT IN ('cod','card','instapay')`.
3. New table `instapay_proofs`:
   ```sql
   CREATE TABLE IF NOT EXISTS instapay_proofs (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
     storage_path TEXT NOT NULL,           -- bucket path of uploaded proof
     reference TEXT,                        -- customer-typed reference/number
     reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
     reviewed_at TIMESTAMPTZ,
     outcome TEXT CHECK (outcome IN ('approved','rejected')),
     note TEXT,
     created_at TIMESTAMPTZ NOT NULL DEFAULT now()
   );
   ALTER TABLE instapay_proofs ENABLE ROW LEVEL SECURITY;
   -- owner sees own; reviewer (admin) sees all; insert owner-only.
   ```
4. `payments.status` — reuse existing states; **no new status**. Pending →
   `success` on approval (same terminal write the COD path uses).
5. Audit: reuse `audit_log`-style patterns (034 lock audit) — record review events.

### 3.2 Edge functions

- **`instapay-initiate`** (new, ~Paymob-initiate shape, simpler):
  - JWT-authenticated owner; body `{ order_id }`.
  - Validates order is `pending` and method is `instapay` (via
    `set_pending_order_payment_method` first, or internally).
  - Atomically ensures a single pending `instapay` payments row per order
    (same partial-unique-index pattern as 034, `WHERE method = 'instapay'`).
  - Returns the **static** merchant InstaPay address + payable amount from the DB:
    `{ instapay_address, amount_minor, payment_id }`. Address comes from an env
    var (`INSTAPAY_MERCHANT_ADDRESS`) — never hard-coded, never client-supplied.
- **`instapay-submit-proof`** (new):
  - Owner; multipart or base64 body `{ payment_id, storage_path|base64, reference }`.
  - Validates ownership + `payments.status='pending'`; inserts
    `instapay_proofs`; flips nothing (status stays `pending`).
- **`instapay-review`** (new, admin-gated):
  - Admin JWT (reuse the admin check pattern from `delete-account`); body
    `{ proof_id, approve: bool, note }`.
  - On approve: in **one transaction**, mark `payments.status='success'`
    (server-generated transaction id — e.g. `instapay_<proofid>`), set
    `orders.status='paid'`, write `instapay_proofs.outcome/reviewed_*`.
  - On reject: `payments.status='failed'`, proof outcome recorded.
- **`cancel-expired-orders`** — extend to also cancel pending `instapay` payments
  past their window (mirrors the existing card-expiry behavior), so stale
  transfer claims self-heal.

### 3.3 Client

- `PaymentMethod.instapay('InstaPay', 'Transfer to our InstaPay address and upload the receipt', 'instapay')`.
- `PaymentService` additions:
  - `Future<InstaPayInitiation> initiateInstapay({required String orderId})` —
    returns address/amount/payment id.
  - `Future<Result<void>> submitInstapayProof({required String paymentId, required XFile proof, String? reference})`.
  - `watchPaymentStatus` reused for completion — no client-side success decision.
- `PaymentCubit`: `processPayment` gains an `instapay` branch — initiate →
  navigate to a new **InstaPayInstructionsPage** (address, amount, copy button,
  proof upload, reference field, "we confirm manually within X" copy) →
  `watchPaymentStatus`/manual-refresh for the approved transition → existing
  `OrderSuccessPage`.
- `PaymentMethodPage`: third `_PaymentOption` row (icon `Icons.account_balance`).
- l10n keys (EN + AR drafted; AR to join the native-AR review pack):
  `instapay`, `instapayDescription`, `instapayInstructionsTitle`,
  `instapayAddressLabel`, `instapayCopyAddress`, `instapayUploadProof`,
  `instapayReferenceLabel`, `instapayReferenceHint`, `instapaySubmitProof`,
  `instapayPendingReview`, `instapayRejected`, `instapayManualNote`.
- Admin surface: a minimal **review queue** (pending proofs list + approve/reject)
  fits the existing admin feature pattern (`Result`-based repo, typed entities).

### 3.4 Why this shape is aggregator-ready

- The confirmation authority is **one edge function** (`instapay-review` today;
  a webhook-verified function tomorrow).
- `instapay_proofs` becomes optional history; `payments`/`orders` state machine is
  untouched. Swapping manual for API confirmation = replacing one function's
  internals + env/contract, zero client churn.

---

## 4. Security posture (non-negotiables carried over)

- The client **never** decides success; only `instapay-review` (or a future
  verified webhook) writes `success`.
- Amounts always read from the DB (never client), like paymob-initiate.
- Proof upload to a **private** storage bucket; signed URLs for reviewers only;
  RLS owner-insert/owner-select on proofs; admin review via elevated JWT path.
- All new RPCs follow the 037 pattern: owner-only, allowlisted, audited.
- Function env (`INSTAPAY_MERCHANT_ADDRESS`, optional future aggregator keys)
  added via `supabase secrets` — committed only as `.env.example` additions.

## 5. Test plan

- **DB (staging, transactional):** allowlist accepts `instapay`; COD path still
  rejects `payment_not_cod` for instapay orders; proof insert RLS (owner yes,
  other user no); review approve flips payment+order atomically; double-approve
  idempotent-safe; expiry cancels stale pending.
- **Edge functions:** unauth 401; non-owner 403; wrong order state 409; happy
  path; approve/reject outcomes; fail-closed on missing env.
- **Client:** cubit branch tests (instapay initiate → instructions → proof
  submit → pending-review state); widget tests for the new option row and
  instructions page; `watchPaymentStatus` transition to success renders
  `OrderSuccessPage`. Mock the service per existing fakes pattern.
- **Manual E2E (staging):** full flow with a real screenshot; admin approve from
  a second account; verify order `paid`, notification sent, cart cleared.

## 6. Rollout sequence

1. Owner approves D1–D4 → merge plan doc (this PR).
2. PR-A `feat/instapay-backend` (migration 041 + 3 edge functions + config) —
   **human review + staging deploy gate** (`db push` with backup, `functions deploy`).
3. PR-B client (enum, service, cubit branch, instructions page, l10n, admin queue).
4. Staging E2E → production rollout.

## 7. Decision gate — owner must answer before implementation

- **D1 — Confirmation model:** manual admin review (recommended now) vs aggregator
  API now? *(If aggregator: which provider/contract? The plan then swaps §3.2
  review for a webhook function.)*
- **D2 — Expiry window:** how long does a pending instapay payment stay claimable
  before `cancel-expired-orders` cancels it? *(Recommend: 24h, matching card
  pending window if present.)*
- **D3 — Proof requirements:** screenshot mandatory, reference optional
  (recommended), or both mandatory?
- **D4 — Admin queue surface:** build the in-app admin review screen now, or
  review via SQL/Supabase dashboard initially (faster, less surface)?

---

## 8. Effort estimate

| Slice | Size |
|---|---|
| Migration 041 + RPC allowlist updates | S |
| 3 edge functions + config | M |
| Client enum/service/cubit/page/l10n | M |
| Admin review queue (if D4 = build) | M |
| Tests (all layers) | M |

Sequenced like UX-043: backend PR → owner deploy gate → client PR → E2E.
