# DB Suite Results — Isolated Staging E2E (2026-08-23, wave 2)

Staging project: `zvpjngdgbpnkkqrorkul` · Authorization ref: `STAGING-E2E-ZVPJ-AC69C54-2026-08-23`
Connection: pooler **`aws-1-eu-west-1.pooler.supabase.com`** via `STAGING_DB_URL`
(never logged; imported from owner's user environment). All suites are guarded
runners that hard-refuse any other project ref. No production contact.

## Verdicts

| Suite | Runner | Result |
|---|---|---|
| RLS adversarial (regenerated for new project) | `run_rls_adversarial.mjs` | **44/44 PASS — ALL PASS, RLS VERIFIED** |
| Race-safe state machine (T-RC01…14) | `run_race_conditions.mjs` | **53/53 PASS — RACE-SAFE VERIFIED** |
| COD confirm RPC contract | `run_cod_payment.mjs` (NEW) | **14/14 PASS — CONTRACT VERIFIED** (sample txn `COD-1787510064-214b89e4`) |
| Paymob sandbox flows F1–F4 | `verify_paymob_sandbox.mjs` | **21/21 PASS incl. cleanup, zero residue** |
| HTTP callback probe A (forged HMAC) | `paymob_http_probe.mjs A` | **PASS** — HTTP 401 `{"message":"Invalid signature"}` |
| HTTP probe B (valid sig, amount mismatch) | `... B` | **PASS** — HTTP 400 `code=amount_mismatch`, zero state change |
| HTTP probe C (late callback after expiry) | `... C` | **PASS** — HTTP 200 `already_processed`; order cancelled / payment expired hold |

## Findings recorded during execution

1. **Pooler host drift:** new project answers on `aws-1-eu-west-1`, not the
   legacy `aws-0` baked into earlier docs (plan §0.2 corrected here). Discovery
   method: tenant-admission sweep across host groups; password never exposed.
2. **First-ever true race execution:** prior evidence (`STAGING_E2E_RACE.md`,
   e9a6deb) was BLOCKED/DEFERRED — today's run is the initial full execution.
   Six initial failures were all runner-porting defects, each fixed against the
   migration-of-record (014/025/026) after diffing live `pg_get_functiondef`
   snapshots (`db-function-snapshots/`):
   - RC02 audit expectation → m025 payment-terminal branch returns silently;
   - RC04 ledger expectation → expiry restores via `order_items.restored`
     flag+trigger; `stock_restorations` is update_order_status-only (m014);
   - RC10 expected-raise now isolated under its own SAVEPOINT;
   - RC13 fixture lacked a payments row + JWT context
     (`request.jwt.claim.sub`); confirm now asserted `ok=true`.
   **No behavioral defect found in staging DB code.**
3. **Legacy GUC:** `test_cod_payment.sql` uses `request.jwt.claims` JSON which
   this project's `auth.uid()` ignores; port supplies `claim.sub` directly.
4. **HMAC secret sync confirmed:** locally-signed callbacks cleared the wall,
   proving `.env.staging`'s `PAYMOB_HMAC_SECRET` equals the deployed edge secret.
5. Sandbox runner cleanup hardened: `RESET ROLE` before deletes + audit-row
   removal (flows leave `SET ROLE authenticated` scoped inside DO blocks).

## Still outstanding for gate rows

- Live app-side Paymob flow (checkout_url → hosted page): blocked on Paymob
  dashboard steps (owner) — DB-level F1–F4 and probes A/B/C cover the server contract.
- Sentry dashboard visual confirmation of event `1ef12b03…` (owner).
- Candidate SHA designation `fc0b2a2` vs `ac69c54` (owner pick).

## LIVE END-TO-END PAYMENT — REAL PROVIDER TRANSACTION (same night)

After owner supplied iframe ID **1062411**:

1. Set `PAYMOB_IFRAME_ID=1062411` on staging secrets (all four PAYMOB_* present).
2. **Deployment gap found & fixed:** `CORS_ALLOWED_ORIGINS` was never carried
   over during isolation — every edge function failed closed (500) for ALL
   clients including the Flutter app. Set to repo-documented
   `https://staging.albatal.app`. (`requireCors` fails closed when unset;
   absent request-Origin passes once configured — mobile-app path.)
3. Live chain probe (`paymob_live_initiate_probe.mjs`): signup →
   create_checkout_order RPC → paymob-initiate → **HTTP 200 checkout_url at
   `accept.paymob.com/api/acceptance/iframes/1062411`**, payment row created
   pending WITH provider order id persisted pre-redirect. 8/8 PASS.
4. Real hosted-page completion (headless browser, Accept test card):
   `txn_response_code=APPROVED`, provider txn **521025723**, provider order
   **593650832**.
5. Signed callback processed by staging function: HTTP 200
   `{"message":"Callback processed","code":"success"}` → DB terminal state:
   order **paid**, payment **success**, transaction_id **521025723** persisted.

### OWNER ACTION STILL REQUIRED (dashboard config)
Integration 1062411's redirect/callback URLs currently target the OLD project
(`alxwvyflasewslinufqe`): the browser GET redirect landed there during this test.
Set in Paymob dashboard for that integration:
- Transaction processed callback → `https://zvpjngdgbpnkkqrorkul.supabase.co/functions/v1/paymob-callback`
- Redirect/response URL → the app/site success page (NOT the function; GETs get 405).
Until changed, automatic provider callbacks land on production (harmless no-op
there — unmapped payment — but staging orders won't auto-flip from real traffic).

Note: replay nuance discovered — Paymob REDIRECT GETs use dotted
`source_data.*` keys while server POST callbacks use flat `source_data_*`;
canonical HMAC covers the flattened names. Function handles POST correctly.

## AUTOMATIC CALLBACK ROUTING — VERIFIED (2026-08-24, final)

Root cause of the earlier "no automatic POST" observations, proven by
field-name-only diagnostics captured from a live delivery:

- Paymob's **transaction processed callback** posts the transaction as a **raw
  JSON body** (`application/json`, ~5.2 KB, all 20 canonical fields present,
  `source_data` flattened) and carries the HMAC **outside the body** — as a
  query parameter on the callback URL. The function previously read the HMAC
  only from form fields → every real delivery failed verification (401) while
  redirect-style replays passed.
- Fix (`paymob-callback`): shape-aware extraction — flat form / `obj`-wrapped
  form / raw JSON — plus HMAC resolution order **body field → query parameter →
  `x-paymob-hmac` header**. `canonicalValuesFromTransaction` normalizes nested
  `order.id` / `source_data.*` and boolean rendering. 20/20 unit tests incl.
  obj-vs-flat equivalence.
- Deployed to staging; **transaction #5 on the fixed deployment flipped
  `paid`/`success` automatically at first poll (txn `521080502`) — zero manual
  action**. Diagnostic instrumentation removed after capture; debug table
  dropped.

Five real provider transactions total: `521025723` (kept as permanent paid
artifact), `521037655`, `521046055`, `521080502` (auto, kept), one cleaned.
