# Staging E2E — InstaPay (migration 041)

Candidate SHA: ffaa420748e494954ea449aa1d6126f29ff1775b (master)
Staging project: al-batal-staging (`zvpjngdgbpnkkqrorkul`)
Date: 2026-09-06
Executed by: Buffy (automated harness `scripts/_pkgL/_e2e_instapay.mjs`)
Authorization: staging only, disposable `@albatal-e2e.test` fixtures

Result: **5/6 scored PASS — full flow works; Realtime `postgres_changes` delivery is broken platform-side (unscored defect, pre-existing, affects Paymob watch equally).**

## Matrix

| # | Step | Result | Evidence |
|---|------|--------|----------|
| 1 | `create_checkout_order('instapay')` | PASS | order `e7e7c1bb-091c-4066-902e-70d5aa7d35a2`, total 69000, status `pending`, method `instapay` |
| 2 | `instapay-initiate` edge function | PASS | HTTP 200; payment `cb690000-…`; address `mustafasayed118@instapay`; amount 69000 = order total (`690 EGP`) |
| 3 | Realtime subscribe (channel `payment-<orderId>`) | PASS | `SUBSCRIBED`, server ack `Subscribed to PostgreSQL`, change registration accepted |
| 4 | `instapay-submit-proof` (PNG proof, D3) | PASS | HTTP 201; proof `5267e0b3-…`; payment stays `pending`; sha256 `b1ff9c8e…` |
| 5 | `instapay-review` approve (via edge function, D4) | PASS (after 042) | HTTP 200 `ok=true code=approved`; tx id `instapay_5267e0b3-…`; order → `paid`; payment → `success`; payment_count 1 |
| 6 | Realtime terminal event flips client to paid | **FAIL** | zero `postgres_changes` events delivered; server state flip verified by direct read instead |

## Defects found

### D-A: `review_instapay_proof` missing EXECUTE grant (fixed by migration 042)

Migration 041 created the RPC with `REVOKE ALL … FROM PUBLIC, anon, authenticated`
and never granted EXECUTE back; deployed ACL was `{postgres, service_role}` only.
The `instapay-review` function calls the RPC under the admin caller's JWT (role
`authenticated`) → SQLSTATE `42501 permission denied for function` → clients saw
`{"message":"rpc_error"}` (HTTP 400). The entire approval path was unusable.

- Reproduced: `SET ROLE authenticated; SELECT review_instapay_proof(...)` → 42501.
- Fix: `supabase/migrations/042_fix_041_review_grant.sql` — mirrors the sibling
  `set_pending_order_payment_method` grant pattern (`REVOKE PUBLIC/anon`,
  `GRANT EXECUTE TO authenticated`). Admin safety unchanged: the RPC is SECURITY
  DEFINER and re-verifies `profiles.is_admin` from the JWT inside its body.
- Post-fix ACL verified: `{postgres, service_role, authenticated}`; step 5 then passed.

### D-B: Realtime `postgres_changes` events never delivered (OPEN — platform side)

The app's payment-status watch (`payment-<orderId>` channel on `public.payments`
UPDATE, per `paymob_payment_service.watchPaymentStatus`) receives **no events**.
Bisect evidence (probes in `scripts/_pkgL/_probe_realtime*.mjs`):

- Websocket + channel layer works: two-client broadcast delivered (`received: 1`).
- Subscribe handshake works: `SUBSCRIBED`, `postgres_changes` registration acked
  with a change id, `system: Subscribed to PostgreSQL` (twice).
- But `realtime.subscription` (server-side persistence table) has **0 rows** for
  the lifetime of an active subscription, and zero events arrive for UPDATEs on
  `payments` (direct-DB and service paths), `orders`, or `instapay_proofs`.
- Ruled out (all verified healthy): publication membership (`payments` in
  `supabase_realtime`, all ops enabled), `wal_level=logical`, replica identity
  FULL, replication slots active with 0 lag, `realtime.messages` recent.
- Publication drop/re-add resync attempted: no change.

Conclusion: the Realtime service accepts subscriptions but fails to persist them
→ WAL events are never matched to any subscriber. Not caused by project schema,
RLS, client code, or migrations. Affects the Paymob watch identically (masked
there by its 45s REST fallback poll; the InstaPay watch has no fallback).

**Action:** escalate to Supabase support / check Realtime service logs for
`zvpjngdgbpnkkqrorkul`. Interim mitigation option: add a periodic REST status
poll to `PaymentCubit` (same fallback pattern as the Paymob watch) so approval
navigation doesn't depend on Realtime.

## Hygiene

- Admin elevation for step 5 was applied to a disposable e2e user via DB and
  restored immediately after the review call (verified `is_admin = false`).
- All e2e orders/payments/proofs deleted; `remaining_pending_instapay_orders: 0`.
- 3 orphaned ~69-byte synthetic test PNGs from e2e users remain in the private
  `instapay-proofs` bucket (DB rows deleted via CASCADE first; storage API
  refuses direct table deletion). Clean up later via service-role storage API.
- No secrets printed by any harness; `STAGING_DB_URL` ref-guarded.

## Verdict

InstaPay staging flow is functional end-to-end for initiate → proof → admin
approval → paid, with the client-side approval watch blocked only by the
platform Realtime defect D-B. Recommend: merge migration 042, track D-B with
Supabase, add the REST polling fallback to the payment watch.
