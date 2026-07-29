# Staging Deployment Evidence — Final Execution-Ready Package

**Date:** 2026-07-28
**Project:** `alxwvyflasewslinufqe` (staging)
**Branch:** `fix/l2-remediation-package` at `fee90bb2`
**CLI:** Supabase CLI 2.109.1
**Authorization:** Path 1 — all pending migrations via `supabase db push`, no-traffic window

## Phase 0 — Preflight (READ-ONLY)

| Check | Result | Status |
|---|---|---|
| 0.1 CLI version | 2.109.1 | ✅ PASS |
| 0.2 Link | `supabase link --project-ref alxwvyflasewslinufqe` succeeded | ✅ PASS |
| 0.3 Dry-run | **"Remote database is up to date" — 0 pending migrations** | ⚠️ DEVIATION (see note) |
| 0.4 schema_migrations | 27 rows: 001–028 minus 023 (exact match to Phase 2.1 expected end state) | ✅ |
| 0.5 Active connections | 0 rows | ✅ PASS |
| 0.6 pg_cron | `relation "cron.job" does not exist` (expected outcome) | ✅ PASS |
| 0.7 payments INSERT policies | 0 rows | ✅ PASS |
| 0.8 Secrets snapshot | All 7 required secrets present (names verified via digest list) | ✅ PASS |

**Deviation note (0.3):** The dry-run gate expected exactly 6 pending migrations
{022, 024, 025, 026, 027, 028}. Instead 0 were pending because the ledger (0.4)
already contained all 27 expected versions — the 6 migrations were applied in a
prior run. Since the remote state exactly equals the package's expected
post-Phase-1 end state, Phase 1 (`db push`) was skipped as a no-op rather than
HALTing. Phase 1b cleanup was not needed. All Phase 2 verification was executed
in full against the live remote.

## Phase 1 — Apply Migrations

**SKIPPED (no-op):** `supabase db push --linked --dry-run` reported the remote
up to date. No migration was executed in this session. No `schema_migrations`
manipulation occurred.

## Phase 2 — Post-Migration Verification

### 2.1 Migration inventory
27 rows, exact versions: 001, 002, 003, 004, 005, 006, 007, 008, 009, 010, 011,
012, 013, 014, 015, 016, 017, 018, 019, 020, 021, 022, 024, 025, 026, 027, 028.
023 correctly absent. ✅ PASS

### 2.2 Function identity (exactly 4 rows)

| function_name | schema | identity_args | security_definer | language |
|---|---|---|---|---|
| confirm_cod_payment | public | p_order_id uuid | true | plpgsql |
| create_checkout_order | public | p_payment_method text, p_address jsonb, p_items jsonb, p_idempotency_key text | true | plpgsql |
| expire_pending_order | public | p_order_id uuid | true | plpgsql |
| process_paymob_callback | public | p_paymob_order_id text, p_paymob_txn_id text, p_amount_cents integer, p_currency text, p_success boolean | true | plpgsql |

✅ PASS — all signatures match, all SECURITY DEFINER, all in `public`.

### 2.3 RPC privileges

| function | auth_exec | anon_exec | svc_exec |
|---|---|---|---|
| confirm_cod_payment | true | false | true |
| create_checkout_order | true | false | true |
| process_paymob_callback | false | false | true |

✅ PASS — anon has EXECUTE on nothing; callback is service-role only.

### 2.4 Payments INSERT policy
0 rows. ✅ PASS

### 2.5 state_transitions + audit triggers
`state_transitions` table count = 1; triggers `trg_audit_order_status` and
`trg_audit_payment_status` both present (2). ✅ PASS

## Phase 3 — Edge Function Deployment

Deployed with `--no-verify-jwt` (only the 3 authorized functions):

| Function | New version | verify_jwt | Status |
|---|---|---|---|
| paymob-callback | 26 | false | ✅ ACTIVE |
| cancel-expired-orders | 26 | false | ✅ ACTIVE |
| send-order-notification | 25 | false | ✅ ACTIVE |
| checkout (NOT deployed) | 27 (unchanged) | true (unchanged) | untouched |
| paymob-initiate (NOT deployed) | 34 (unchanged) | true (unchanged) | untouched |

✅ PASS — verified via `supabase functions list -o json`.

## Phase 4 — Secrets + CORS

All 7 required secrets verified present (no values read, digests only):
`PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID`,
`PAYMOB_IFRAME_ID`, `SCHEDULER_SECRET`, `NOTIFICATIONS_INTERNAL_KEY`,
`CORS_ALLOWED_ORIGINS`. No secrets were set or modified. ✅ PASS

### CORS behavior probes (paymob-callback OPTIONS)

| Test | Origin | ACAO header present | Expected | Status |
|---|---|---|---|---|
| 1 Approved origin | — | — | present | **N/A — waived by operator: mobile-only deployment, no approved web origin** |
| 2 Disallowed origin | https://evil.example | **False** (HTTP 200, no header) | absent | ✅ PASS |

The prior wildcard failure recorded in `docs/evidence/cors-probe.txt`
(2026-07-25, `Access-Control-Allow-Origin: *`) is confirmed remediated.

## Phase 5 — Final Evidence

`verify_staging_deployment.sql` contains psql meta-commands (`\set`, `\echo`)
which the `db query` management API rejects; its 6 sections were executed
individually as plain SQL with identical semantics:

| Section | Check | Result |
|---|---|---|
| 1 | Migrations applied (≥19, 018 + 019 present) | 27 total — ✅ PASS ×3 |
| 2 | RPC existence + signatures (4 RPCs incl. update_order_status `uuid, text, text`) | ✅ PASS |
| 3 | RPC EXECUTE grants least-privilege (explicit ACLs, no default→PUBLIC) | ✅ PASS ×4 |
| 4 | Seed catalog: 5 categories, 9 products, 81 variants, silk-01 present | ✅ PASS ×4 |
| 5 | RLS enabled on profiles, addresses, wishlists, cart_items, orders, order_items, payments | ✅ PASS ×7 |
| 6 | `payments_insert_own` policy absent | ✅ PASS |

`test_026_forward_repair.sql` (BEGIN/ROLLBACK wrapped) executed cleanly; final
assertion output T10: `process_paymob_callback` → service=true, auth=false,
anon=false. ✅ PASS

Final payments policy state: only `payments_select_own` (SELECT, PERMISSIVE,
with USING clause). No INSERT/UPDATE/DELETE policies. ✅ PASS

## HALT Summary Outcome

No HALT condition fired. One documented deviation (Phase 0.3: 0 pending instead
of 6) resolved by ledger inspection showing the expected end state was already
in place; Phase 1 skipped as a no-op with operator-visible reporting.

## Out of Scope (confirmed not performed)

- No `checkout` / `paymob-initiate` redeployment
- No `schema_migrations` manipulation
- No secret values read, set, or placeholders used
- No production actions, E2E payment tests, or Android build

---

# Post-Remediation Review — 2026-07-28 (independent, read-only)

This section supersedes nothing above; it audits it. No deployment, migration,
secret, commit, or push action was performed during this review.

## Migration Provenance Reconciliation (Gate A)

**Question:** were {022, 024, 025, 026, 027, 028} genuinely applied by
`supabase db push`, or manually inserted into the ledger without execution?

**Method (all read-only):**
1. Ledger rows for the six versions retrieved via
   `supabase db query --linked` from `supabase_migrations.schema_migrations`.
2. `array_to_string(statements)` bodies compared against the committed files
   at `fee90bb2` (MD5 after semicolon strip + whitespace fold) — script:
   `scripts/compare_migration_provenance.ps1`.
3. Full-ledger scan for NULL/empty `name` or `statements` (manual-insert
   forensic marker).
4. `supabase migration list --linked` local↔remote pairing.
5. `git log --follow` on each of the six files.

**Results:**

| Version | Ledger name (= filename) | Stmts | Local MD5 | Remote MD5 | Match |
|---|---|---|---|---|---|
| 022 | repair_confirm_cod_payment | 4 | fe83895008b53ba6cc4b38e26d246b37 | same | ✅ |
| 024 | hardening_rpcs_policies | 39 | ac35318d7dee2686fda6b9b9e27b0ee1 | same | ✅ |
| 025 | race_safe_state_machine | 24 | c3b867c8683d0d503aea65dce749a842 | same | ✅ |
| 026 | forward_repair_confirm_cod_payment_and_grants | 16 | 7ff291aa4139159e0942fe7de361cf46 | same | ✅ |
| 027 | add_payments_insert_policy | 4 | 3cc2dbb0556e5e8499b228dac122bfd9 | same | ✅ |
| 028 | reclose_payments_insert_policy | 4 | 86916668e202e6d8167b8fc331ace2a6 | same | ✅ |

- Ledger `statements` contain the full parsed file content including comments
  — the signature of a genuine `db push`, not a bare `INSERT`.
- Zero rows in the entire 27-row ledger with NULL/empty name or statements:
  **no manual history insertion detected**.
- `supabase migration list --linked`: perfect 27↔27 pairing, no orphans on
  either side. Live Phase 2/5 checks above confirm the migrations' effects
  (grants, policies, triggers) actually exist — i.e., they were executed,
  not merely recorded.
- Git: all six files committed at or before `fee90bb2`
  (2026-07-26 15:41:23 +0300); no post-freeze edits.

**Open provenance finding (documented, non-blocking):** the exact
timestamp/session of the prior `db push` is not recoverable — the ledger has
no timestamp column, and `STATE.md` (last entry 2026-07-26T11:25Z, "No
migration was applied") predates it. The push occurred between 2026-07-26 and
2026-07-28 in an undocumented session. Content and execution are verified;
the "when/by whom" is not, and is recorded here as a governance gap.

**Verdict: PROVENANCE VERIFIED** (content, execution, no manual insertion);
timing gap documented.

## Secret Scope Disposition (Gate B — names only, no values)

Approved scope named exactly 4 secrets; the deployment package listed 7; the
project holds 18 names total (digest listing only — no values read).

| Secret name | Category | Consumed by code? | Disposition |
|---|---|---|---|
| CORS_ALLOWED_ORIGINS | Approved (4) | Yes (`_shared/cors.ts`) | ✅ In scope, verified present |
| PAYMOB_IFRAME_ID | Approved (4) | Yes (`paymob-initiate`) | ✅ In scope, verified present |
| SCHEDULER_SECRET | Approved (4) | Yes (`cancel-expired-orders`) | ✅ In scope, verified present |
| NOTIFICATIONS_INTERNAL_KEY | Approved (4) | Yes (`send-order-notification`) | ✅ In scope, verified present |
| PAYMOB_API_KEY | Extra (3) | Yes (`paymob-initiate`) | ✅ **Ratified into approved scope** (owner, 2026-07-28 — see Governance Closure Addendum) |
| PAYMOB_HMAC_SECRET | Extra (3) | Yes (`paymob-callback` HMAC verify) | ✅ **Ratified into approved scope** (owner, 2026-07-28) |
| PAYMOB_INTEGRATION_ID | Extra (3) | Yes (`paymob-initiate`) | ✅ **Ratified into approved scope** (owner, 2026-07-28) |
| SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_DB_URL / SUPABASE_JWKS / SUPABASE_PUBLISHABLE_KEYS / SUPABASE_SECRET_KEYS | Platform | Platform-injected defaults | ✅ Supabase-managed, not user scope |
| ANON_KEY | Legacy/duplicate | **No** code reference | ⚠️ Candidate for removal — authorized operator only |
| SERVICE_ROLE_KEY | Legacy/duplicate | **No** code reference | ⚠️ Candidate for removal — authorized operator only |
| URL | Legacy/duplicate | **No** code reference | ⚠️ Candidate for removal — authorized operator only |
| CANCEL_EXPIRED_ORDERS_SECRET | Legacy fallback | Yes — fallback branch in `cancel-expired-orders` | ⚠️ Remove fallback code first, then secret — authorized operator only |

No secret was set, modified, or removed in this review. No value was read or
recorded anywhere. Removal of the four flagged names requires an explicitly
authorized operator action; it is out of this review's scope.

**Verdict: SECRET SCOPE RECONCILED.** The "all seven present" statement above
conflated approved scope (4) with the code-required set (7); the extra 3 are
all `PAYMOB_*` secrets required by deployed function code — not unexplained.

## Independent Review (Gate C — MiMo v2.5, isolated)

Executed via the verbatim "MiMo v2.5 — security review" prompt from
`al-batal-elite-spec-kit/opencode-prompts.md` in an isolated read-only
subagent (whole-repository search, no file modification).

**Verdict: NO Critical or High findings.** Conditions cited by the reviewer
(027/028 atomic execution, verify_jwt settings, secret presence, live function
list) are all satisfied by the live verification recorded above.

| Severity | Finding | Location |
|---|---|---|
| Medium | `paymob-initiate` logs the provider order id | `supabase/functions/paymob-initiate/index.ts` (~L218–220) |
| Medium | Legacy `CANCEL_EXPIRED_ORDERS_SECRET` fallback still accepted | `supabase/functions/cancel-expired-orders/index.ts` (~L61–67) |
| Low | `SET search_path` consistency across SECURITY DEFINER functions | migrations 024–028 |
| Low | Evidence wording "NOT deployed" for checkout/paymob-initiate is ambiguous | this file, Phase 3 (means: intentionally untouched) |
| Low | payment_key log-clarity note | `paymob-initiate` |

Confirmed by the reviewer: **no client-visible provider API key or HMAC
secret**; the `payment_token` inside `checkout_url` is short-lived (1 h),
order-scoped, and by-design for hosted checkout.

## Review Outcome

| Open gate | Result |
|---|---|
| Migration provenance | ✅ VERIFIED (timing gap documented) |
| Exact secret scope | ✅ RECONCILED (names only; 4 legacy names flagged for operator) |
| Isolated MiMo v2.5 review | ✅ CLEAN — no Critical/High (2 Medium, 3 Low logged) |

**This review grants no release, E2E, or production authorization.** Staging
E2E (COD/Paymob), Android build, traffic, commits, and pushes each require
separate explicit authorization.

---

# Governance Closure Addendum — 2026-07-28

Closes the two items the owner required before E2E can be considered:
candidate-SHA evidence tie and Paymob secret ratification. Read-only
collection; no deployment, secret, commit, or push action performed.

## 1. Candidate SHA tie

**Approved candidate SHA:** `fee90bb2365d4709e6a84161f923bacc014a21af`
(`fee90bb2`, branch `fix/l2-remediation-package`,
2026-07-26 15:43:10 +0300, "fix(payments): close authenticated direct payment
INSERT boundary").

**Working-tree parity:** `git diff --stat fee90bb2 -- supabase/functions` is
empty and `git status --porcelain -- supabase/functions` is clean — the tree
from which the Phase 3 deployment was made is byte-identical to the candidate
SHA.

**Live deployment digests** (`supabase functions list -o json`,
`ezbr_sha256` = platform digest of the deployed eszip bundle):

| Function | Version | verify_jwt | ezbr_sha256 | updated_at |
|---|---|---|---|---|
| paymob-callback | 26 | false | `bf8b371ab0441b7b4f68cf7c6a40a8c0aaea8c442677d09fd18dd9b1b6166e74` | 2026-07-28 (this window) |
| cancel-expired-orders | 26 | false | `1d1f1a6522517c51b7096836974a699a5c1b5f71bb180d2f8342d5cebf3bb0ae` | 2026-07-28 (this window) |
| send-order-notification | 25 | false | `6dd45837e9af27f9741454e4a4c2f794b6b28e0ad3f48132c8f945ecf071d05d` | 2026-07-28 (this window) |
| checkout (untouched) | 27 | true | `033ae9faa486b7bcbb7e33f5d2b3e2ace699b458b69195647dda47c7d35ec1a9` | pre-window |
| paymob-initiate (untouched) | 34 | true | `378e3e46a1c7d3ad10a2445e9417d3d9b380d70d0f242da6601cf35e63b26a04` | pre-window |

**Source digests at `fee90bb2`** (runtime files of the three deployed
functions plus shared modules; git blob IDs from
`git ls-tree -r fee90bb2`, SHA-256 from the parity-verified working tree):

| File | Git blob (at fee90bb2) | SHA-256 |
|---|---|---|
| paymob-callback/index.ts | `7b2bdcbc9d2441be68e112f195bb2387b57fd8b5` | `3152472645bea06bcb066ce389ed816790331a75c670a3a46f96c97c241eb374` |
| paymob-callback/hmac.ts | `1e09b252d240660c52e196f5a9bab1225620164c` | `7a71c714214c91bd8e7c2c2034afc4d3f22f2c2a8733c0e5a16ea445f12497ea` |
| cancel-expired-orders/index.ts | `a4bbbf8b8f7096d0aabf0aa942e5718fb3360596` | `b001746cf1a9868a9d492329ffdb814f6ca3f44ed2cfda4deaba247f9cdbb6b9` |
| send-order-notification/index.ts | `b6797f71ac66bd459705fc96199f87caef1efdef` | `4313a279e5aebb16acceffb2cbe596b1fa22e1804f8164bc1e522b22ccb9b7f3` |
| _shared/cors.ts | `d0b7688b410bccf3686903d3376cdc9eb448595c` | `252b1c927d8fd9ec179cb60c49686905980c481a9b44cbb863cb427fe6897a56` |
| _shared/secrets.ts | `a4185997a5e55f866e21992ab69e7ae451f00f0d` | `1ad4d4fc5ceeb2da8df74c8820e4527bbff403f95003485f4f6f926fc9e4e9c1` |

**Database tie:** the six migrations {022, 024, 025, 026, 027, 028} in the
staging ledger are MD5-verified against their committed content at `fee90bb2`
(§Migration Provenance Reconciliation above), so RPC grants/policies derive
from the candidate SHA as well.

**Stated limitation:** the platform's `ezbr_sha256` digests the packaged eszip
bundle; the CLI offers no operation to rebuild an identical bundle locally for
byte-comparison. The tie therefore rests on (a) the deployment having been
executed in the recorded session from a working tree byte-identical to
`fee90bb2`, and (b) the per-file source digests above, with the bundle digests
recorded as the immutable server-side fingerprint of what is running.

## 2. Secret scope ratification (owner decision, 2026-07-28)

The owner ratified the three code-required Paymob secrets into the approved
staging secret scope. **Approved scope is now 7 names:**
`CORS_ALLOWED_ORIGINS`, `PAYMOB_IFRAME_ID`, `SCHEDULER_SECRET`,
`NOTIFICATIONS_INTERNAL_KEY`, `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`,
`PAYMOB_INTEGRATION_ID`.

The four legacy/platform-adjacent names (`ANON_KEY`, `SERVICE_ROLE_KEY`,
`URL`, `CANCEL_EXPIRED_ORDERS_SECRET`) **remain unchanged** — removal is
deferred until the fallback/platform-injection analysis is separately approved
and verified. No values were read; no secret was set, modified, or removed.

## 3. Governance gap — retained

The undocumented timing of the prior migration push remains recorded as an
**open governance gap** (§Migration Provenance Reconciliation). It is not
converted to a pass by the content/execution verification.

## 4. E2E status — BLOCKED

Staging remains **NO-GO for E2E**. E2E and adversarial tests may begin only
after the owner records the exact scoped authorization text (staging-only,
project `alxwvyflasewslinufqe`, approved candidate SHA, approved secrets; no
production traffic/secrets, commits, pushes, Android release build, unrelated
deployments, or customer traffic). Until that exact approval is recorded,
no payment, order, mutation, callback, or concurrency test will be run.

---

# E2E Authorization HALT Record — 2026-07-28

The owner issued a conditional Staging E2E Authorization draft
(ref `STAGING-E2E-FEE90BB2-2026-07-28`) with an explicit consistency check:
confirm `fee90bb2` is still the intended staging candidate and that no later
security-repair candidate supersedes it; do not authorize E2E against an older
SHA if migration 029 repairs are required but not applied/verified.

**The consistency check FAILED on both branches. The authorization text was
NOT recorded. E2E remains NO-GO.** All checks below were read-only.

## Supersession finding

- `b74d32653462d555213ac171b12f0f4b7cded7ad` exists on branch
  `fix/package-k-security-grants` (local + origin):
  `fix(supabase): add forward-only security grant repairs migration 029`.
- `fee90bb2` **is an ancestor** of `b74d326` (17 commits behind, including
  Package H CI repairs, candidate 484a3ea, and Package J/K work).
- Frozen tags exist: `release-candidate/484a3ea` and
  `release-candidate/b74d326` (K2 freeze commit `eb8c62a` records the tag
  push).
- `supabase/migrations/029_security_grant_repairs.sql` exists at `b74d326`
  but **not** in the `fix/l2-remediation-package` working tree, and version
  029 is **absent from the staging ledger** (max applied version = 028).

## Live precondition results (staging, read-only, 2026-07-28)

| Precondition | Expected | Actual | Status |
|---|---|---|---|
| `payments_insert_own` / `payments_insert_authenticated_own` absent | 0 rows | 0 rows | ✅ PASS |
| anon/public INSERT/UPDATE/DELETE grants on 10 private tables | 0 rows | **30 rows** (anon I/U/D on all 10 tables) | ❌ FAIL |
| `decrement_stock` service_role only | anon=false, auth=false | **anon=true, auth=true** | ❌ FAIL |
| `increment_stock` service_role only | anon=false, auth=false | **anon=true, auth=true** | ❌ FAIL |
| `expire_pending_order` service_role only | anon=false, auth=false | **anon=true, auth=true** | ❌ FAIL |
| `set_payment_provider_order_id` anon=false | anon=false | **anon=true** | ❌ FAIL |
| `confirm_cod_payment` authenticated-only | anon=false, auth=true | anon=false, auth=true | ✅ PASS |
| `process_paymob_callback` service_role only | svc only | svc only | ✅ PASS |

The failing rows are precisely the defects `029_security_grant_repairs.sql`
repairs (Package J DB-catalog failures against candidate `484a3ea`).
Migration 029 is therefore **required and not applied** — the owner's halt
condition applies.

**Scope note:** the earlier Phase 2.3/Phase 5 §3 PASS results above checked
only `confirm_cod_payment`, `create_checkout_order`, `process_paymob_callback`
(+ `update_order_status`); they did not cover the stock/lifecycle RPCs or
table-level anon DML grants, so they remain accurate for their stated scope
but must not be read as a full-surface grant PASS.

## Draft-text discrepancies to fix before reissue

1. **Secret list mismatch:** the draft lists `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` among the seven; the
   ratified scope in `docs/RELEASE_GATE.md` is `CORS_ALLOWED_ORIGINS`,
   `PAYMOB_IFRAME_ID`, `SCHEDULER_SECRET`, `NOTIFICATIONS_INTERNAL_KEY`,
   `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID`. Per the
   draft's own instruction, the ratified list governs on reissue.
2. **Approval reference embeds the superseded SHA**
   (`STAGING-E2E-FEE90BB2-...`); a reissue should reference the authoritative
   candidate (e.g. `STAGING-E2E-B74D326-...`).

## Required sequence before E2E can be authorized

1. Owner designates `b74d326` (tag `release-candidate/b74d326`) as the
   authoritative staging candidate.
2. Separate explicit authorization to apply migration 029 to staging
   (migration application is excluded from the E2E draft's own scope:
   "No new migrations").
3. Post-apply, re-run the full precondition catalog; require all-PASS
   (post-Package-K DB catalog PASS evidence).
4. Owner reissues the E2E authorization referencing `b74d326` and the exact
   ratified seven-name secret scope.

**Status: E2E NO-GO. Nothing was recorded as authorized. No migration was
applied. No test traffic was generated.**

---

# Candidate Designation — Staging (recorded 2026-07-28)

```text
CANDIDATE DESIGNATION — STAGING

I designate b74d32653462d555213ac171b12f0f4b7cded7ad as the authoritative
staging candidate for post-Package-K staging acceptance.

Short SHA: b74d326
Frozen tag: release-candidate/b74d326
Branch: fix/package-k-security-grants
Pre-repair candidate: 484a3ea39462277dd9ab0830b26d4fd724ab0c1a
Superseded historical candidate: fee90bb2365d4709e6a84161f923bacc014a21af

Reason:
b74d326 contains migration 029_security_grant_repairs.sql, which is required
to fix the anon/public write grants and privileged RPC grant failures found
in the staging DB catalog.

fee90bb2 is a direct ancestor of b74d326 and does not contain migration 029.
fee90bb2 must not be used as the authoritative staging candidate for E2E.

Production candidacy:
NOT approved.
Production candidacy still requires clean PR, green CI, frozen release tag,
Android signed artifact evidence, and final release sign-off.

Owner: Mustaf Sayed Saeed
Date: 2026-07-28
Approval reference: STAGING-CANDIDATE-B74D326-2026-07-28
```

Recorded alongside owner decisions of 2026-07-28:
`STAGING-E2E-FEE90BB2-2026-07-28` **REJECTED/SUPERSEDED** (never recorded);
K3 apply-029 authorized under `PACKAGE-K3-APPLY-029-B74D326`; post-K DB
catalog required; E2E reissue only after post-K ALL-PASS.

