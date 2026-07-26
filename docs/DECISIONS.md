# DECISIONS.md — Professional Remediation Kit: Phase 0 Human Authorization

Project: Al Batal Elite  
Stack: Flutter + Supabase + Edge Functions + Paymob  
Release Verdict: NO-GO / BLOCKED  
Status: PHASE 0 APPROVED FOR PLANNING AND CONTROLLED EXECUTION
Created: 2026-07-25  
Last Updated: 2026-07-26

## Phase 0 Status

Phase 0 governance decisions are approved for planning and controlled execution.

This is not final release sign-off.

Final release sign-off remains pending until:
- all technical gates pass
- live evidence is tied to an immutable candidate SHA
- the four release roles sign `docs/RELEASE_SIGNOFF.md`

Owner names, dates, approval references, and final signatures have not been provided. All such fields remain `PENDING HUMAN SIGNATURE`.

HARD RULES for L2 implementation:
- Do NOT push to git.
- Do NOT merge to master.
- Do NOT apply migrations to staging or production.
- Do NOT deploy Edge Functions.
- Do NOT run Paymob tests with production keys.
- Do NOT print secrets.
- Do NOT commit secrets.
- Do NOT renumber applied migrations.
- Do NOT delete applied migration history.
- Do NOT remove NoOp crash reporting fallback.
- Do NOT change payment behavior unless create_checkout_order creates a pending COD payment row or Decision 2 is formally changed to auto-create.

The selected Phase 0 options may guide controlled implementation. Individual decision signatures and final release approval remain pending.

---

## Decision Log

| # | Decision | Status | Owner | Date | Risk if Not Decided |
|---|---|---|---|---|---|
| 1 | Migration repair strategy | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Schema drift between environments; broken migrations; unshippable local state |
| 2 | COD missing-payment behavior | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Inconsistent payment state; orphaned orders; broken checkout flow |
| 3 | Paymob callback gateway | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Webhook verification failure; revenue loss on missed callbacks |
| 4 | Staging and production Supabase projects | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Environment bleed; accidental production data exposure |
| 5 | Secret provisioning | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Secret leaks in client bundle; compromised credentials |
| 6 | Observability | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Invisible crashes; no error tracking; PII exposure in logs |
| 7 | Android release | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Unsigned or insecure APK; CI pipeline gaps |
| 8 | Beta scope | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Unclear rollout boundaries; untested platform combinations |
| 9 | Release gate ownership | Phase 0 selected / signature pending | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE | Accountability gaps; blocked releases; process ambiguity |

---

# Decision 1: Migration Repair Strategy

## Context

Local migration files `018_*`, `019_*`, and later repair drafts may not match the migrations already applied in staging or production. Some local files are incomplete, duplicated, or unshippable due to migration drift.

The project must repair the database schema without rewriting already-applied migration history.

## Options

| Option | Description |
|---|---|
| A — Forward-only repair migration (Recommended) | Create a new repair migration, for example `026_*` or a timestamped migration, that corrects schema without renumbering applied migrations. Leave existing applied migration history intact. |
| B — Renumber and force-rebase | Renumber local migrations to correct values. Requires coordination with all environments and creates high risk of migration conflicts. |

## Local 018/019 Disposition

| Option | Description |
|---|---|
| Commit as-is | Keep local files in repo with warnings. Risk: confusion and accidental application. |
| Discard | Remove files entirely. Risk: lost reference material. |
| Preserve separately (Recommended) | Move to `docs/migrations-pending/` as reference-only. Not applied by tooling. |

## Questions for Decision Maker

- [x] Approve forward-only repair migration, likely next available number such as `026_*` or timestamped?
- [x] Do NOT renumber already-applied migrations?
- [x] Are local `018`/`019` confirmed unshippable until re-scoped?
- [x] Disposition of local `018`/`019` files:
  - [ ] Commit as-is with warnings
  - [ ] Discard
  - [x] Preserve separately in `docs/migrations-pending/`

## Recommended Default

A — Forward-only repair migration + preserve local unshippable files separately.

## Recommended Solution

Approve the following migration strategy:

1. Do not renumber, delete, or rewrite already-applied migration history.
2. Treat local draft migrations that are not confirmed deployed as reference-only until reconciled.
3. Move unshippable local draft migrations, including conflicting `018`/`019` drafts and duplicate `confirm_cod_payment` drafts, into:

```text
docs/migrations-pending/
```

4. Use the next available forward-only repair migration, for example:

```text
supabase/migrations/026_forward_repair_confirm_cod_payment_and_grants.sql
```

or a timestamped equivalent.

5. The forward repair migration must reconcile:
   - `confirm_cod_payment`
   - RPC grants
   - payment policy hardening
   - race-safe state machine fixes
   - privilege matrix corrections
   - any missing indexes or triggers required for payment/order integrity

6. Before applying the repair migration, run a migration parity report comparing:
   - repository migration files
   - staging `supabase_migrations.schema_migrations`
   - production migration history when production exists

7. Staging and production must only receive migrations from one frozen approved SHA.

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 2: COD Missing-Payment Behavior

## Context

When a Cash on Delivery order is confirmed but no corresponding payment row exists in the database, the system must decide how to handle this inconsistency.

This decision affects:

- `confirm_cod_payment` RPC
- Flutter payment state mapping
- SQL tests
- integration tests
- payment specification
- staging acceptance evidence

## Options

| Option | Description |
|---|---|
| A — Reject with `payment_not_found` (Recommended) | Return explicit error. Client must resolve before proceeding. Clean data, explicit failure. |
| B — Auto-create COD payment row | Silently create a payment record. Convenient but may mask data issues. |

## Affected Surfaces

- RPC function server-side logic
- Client-side payment state mapping
- Test suite, unit and integration
- Specification document for payment flow
- Staging acceptance evidence

## Questions for Decision Maker

- [x] Choose COD missing-payment behavior:
  - [x] A — Reject with `payment_not_found`
  - [ ] B — Auto-create COD payment row
- [x] Confirm the chosen approach will be applied consistently across RPC, client mapping, tests, and spec?

## Recommended Default

A — Reject with `payment_not_found`.

This is fail-explicit, easier to debug, and safer for financial data.

## Recommended Solution

Approve:

```text
COD missing-payment behavior = reject with payment_not_found
```

Required implementation consequences:

1. `confirm_cod_payment` must return:

```json
{
  "ok": false,
  "code": "payment_not_found"
}
```

when no valid pending COD payment row exists for the order.

2. The Flutter client must map `payment_not_found` to a user-safe error message, for example:

```text
We could not confirm this payment. Please check your orders and try again.
```

3. The server checkout flow must ensure that a valid pending COD payment row exists before `confirm_cod_payment` is called.

4. If `create_checkout_order` does not currently create a pending COD payment row, then one of the following must be implemented:

   Option 1, preferred:

```text
create_checkout_order creates a pending COD payment row for COD orders.
```

   Option 2:

```text
A separate server-side RPC creates the pending COD payment row before confirmation.
```

5. Any existing migration that auto-creates a missing COD payment row must be superseded by the canonical forward-repair migration.

6. SQL tests must cover:

```text
missing payment row -> payment_not_found
existing pending COD payment -> confirmed
already confirmed -> already_confirmed
non-owner -> not_owner
anonymous -> authentication_required
non-COD payment -> payment_not_cod
cancelled order -> order_not_pending
failed payment -> invalid_state
```

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Product Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 3: Paymob Callback Gateway

## Context

The Paymob callback Edge Function receives server-to-server webhooks from Paymob.

Paymob callbacks do not carry a Supabase user JWT. Therefore, Supabase platform JWT verification must be disabled only for the public provider callback endpoint.

Application-level HMAC verification must remain enabled and fail closed.

## Configuration Matrix

| Gate | Setting | Recommended Default |
|---|---|---|
| `paymob-callback` JWT verification | `verify_jwt` | `false` because Paymob does not send JWTs |
| `checkout` JWT verification | `verify_jwt` | `true` |
| `paymob-initiate` JWT verification | `verify_jwt` | `true` |
| HMAC validation | Fail-closed | `true`, reject if HMAC invalid or missing |

## Questions for Decision Maker

- [x] Approve deploying `paymob-callback` with `verify_jwt = false`?
- [x] Keep JWT verification ON for `checkout` and `paymob-initiate`?
- [x] Keep HMAC fail-closed validation, rejecting invalid or missing HMAC?

## Recommended Default

Approve all defaults as listed:

```text
paymob-callback: verify_jwt = false
checkout: verify_jwt = true
paymob-initiate: verify_jwt = true
HMAC validation: fail-closed = true
```

## Recommended Solution

Approve the following deployment configuration:

1. Deploy `paymob-callback` with:

```bash
--no-verify-jwt
```

2. Keep `checkout` protected by JWT verification.

3. Keep `paymob-initiate` protected by JWT verification.

4. Keep HMAC verification inside `paymob-callback` mandatory and fail-closed.

5. Reject callback processing when:

```text
PAYMOB_HMAC_SECRET is missing
HMAC signature is invalid
amount mismatch occurs
currency mismatch occurs
provider order mapping is invalid
```

6. `process_paymob_callback` RPC must remain executable only by:

```text
service_role
```

7. `process_paymob_callback` must not be executable by:

```text
anon
authenticated
PUBLIC
```

8. Add an architecture note explaining why `paymob-callback` is the only endpoint with JWT verification disabled.

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 4: Staging and Production Supabase Projects

## Context

Environment isolation requires separate Supabase projects for staging and production to prevent data bleed and accidental production mutations.

The current repository evidence shows the same Supabase project credentials reused across environment files. This is not acceptable for production launch.

## Configuration

| Environment | Supabase Project | Paymob Integration | Status |
|---|---|---|---|
| Staging | `alxwvyflasewslinufqe` recommended as current staging project | Sandbox | ✅ RECOMMENDED |
| Production | New separate Supabase project to be created | Production | ✅ RECOMMENDED |

## Questions for Decision Maker

- [x] Approve separate Supabase projects for staging and production?
- [x] Which Supabase project is staging?

```text
alxwvyflasewslinufqe
```

- [x] Which Supabase project will be production?

```text
New dedicated production Supabase project to be created and named by the owner.
```

- [x] Are Paymob sandbox and production integrations confirmed as separate?

## Recommended Default

Approve separate projects. Use distinct Paymob merchant profiles or integration entries per environment.

## Recommended Solution

Approve the following environment isolation strategy:

1. Staging Supabase project:

```text
alxwvyflasewslinufqe
```

2. Production Supabase project:

```text
Create a new separate Supabase project.
Do not reuse the staging project for production.
```

3. Paymob staging:

```text
Use Paymob sandbox credentials only.
```

4. Paymob production:

```text
Use separate Paymob production credentials.
Do not reuse sandbox credentials for production.
```

5. Flutter client configuration must never contain:

```text
PAYMOB_API_KEY
PAYMOB_INTEGRATION_ID
PAYMOB_HMAC_SECRET
PAYMOB_IFRAME_ID
SUPABASE_SERVICE_ROLE_KEY
SCHEDULER_SECRET
CANCEL_EXPIRED_ORDERS_SECRET
NOTIFICATIONS_INTERNAL_KEY
```

6. Supabase `service_role` key must exist only in:

```text
Supabase Edge Function secrets
```

7. Staging and production secrets must never be mixed.

8. Production secrets must never be used on staging.

9. Staging secrets must never be used on production.

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 5: Secret Provisioning

## Context

Secrets such as Paymob API keys, HMAC secrets, and Supabase `service_role` keys must be provisioned securely.

Leaked secrets in client bundles, logs, git history, or CI artifacts are a critical security risk.

## Secret Inventory

| Secret | Storage Location | Client Bundle | Logs/Artifacts |
|---|---|---|---|
| Paymob API Key | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Paymob HMAC Secret | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Paymob Integration ID | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Paymob Iframe ID | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Supabase `service_role` | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Scheduler/internal secrets | Supabase Secrets / Edge Functions | ❌ NEVER | ❌ NEVER |
| Supabase Anon Key | Flutter build-time config | ✅ OK | ❌ NEVER |
| Sentry DSN | Flutter build-time config | ✅ OK | ❌ NEVER |

## Questions for Decision Maker

- [x] Approve secure secret provisioning through Supabase Secrets and GitHub Secrets only?
- [x] Confirm NO Paymob/service_role secrets in Flutter client bundle?
- [x] Confirm NO secrets printed, committed, or uploaded as CI artifacts?

## Recommended Default

Approve. Enforce via secret hygiene runbook:

```text
docs/secret-hygiene-runbook.md
```

## Recommended Solution

Approve the following secret handling rules:

1. All server secrets must be stored only in:

```text
Supabase Edge Function secrets
GitHub Actions secrets
Password manager or secure secret store
```

2. The Flutter client may only receive:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SENTRY_DSN
```

3. The Flutter client must never receive:

```text
PAYMOB_API_KEY
PAYMOB_INTEGRATION_ID
PAYMOB_HMAC_SECRET
PAYMOB_IFRAME_ID
SUPABASE_SERVICE_ROLE_KEY
SCHEDULER_SECRET
CANCEL_EXPIRED_ORDERS_SECRET
NOTIFICATIONS_INTERNAL_KEY
```

4. Do not package `.env` as a Flutter asset.

5. Use build-time configuration such as:

```bash
--dart-define-from-file=config/env.staging.json
```

or:

```bash
--dart-define-from-file=config/env.production.json
```

6. Local secret files must remain gitignored:

```text
.env
.env.staging
.env.production
secrets-staging.env
release-keystore.jks
android/key.properties
```

7. CI must never print secrets.

8. CI must never upload keystores, key properties, or secret files as artifacts.

9. CI must fail if high-risk secrets are detected.

10. Any accidentally committed secret must be rotated immediately.

## Decision

| Approved By | Name | Date |
|---|---|---|
| Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 6: Observability

## Context

Crash reporting, analytics, and PII handling must be defined before release.

The project currently uses a NoOp crash reporting service. This is acceptable for local development but not acceptable for production.

## Configuration

| Item | Recommended Default | Notes |
|---|---|---|
| Crash reporting provider | Sentry | Flutter SDK; standard in Flutter ecosystem |
| NoOp fallback when DSN is empty | Approved | App runs without crashes in dev/local; no crash data lost |
| PII scrubbing policy | Approved | Scrub user inputs, breadcrumbs, and metadata at transport layer |
| Analytics event schema | Approved | Event names, properties, and naming convention defined |

## Questions for Decision Maker

- [x] Approve Sentry as crash reporting provider?
- [x] Approve NoOp fallback when DSN is empty?
- [x] Approve PII scrubbing policy?
- [x] Approve analytics event schema?

## Recommended Default

Approve Sentry + NoOp fallback + PII scrubbing + analytics event schema.

## Recommended Solution

Approve the following observability plan:

1. Use Sentry as the crash reporting and observability provider.

2. Use `NoOpCrashReportingService` when `SENTRY_DSN` is empty.

3. Use `SentryCrashReportingService` when `SENTRY_DSN` is present.

4. Set Sentry configuration safely:

```text
sendDefaultPii = false
environment = staging or production
release = app version
dist = build number
attachScreenshot = false
```

5. Attach only the Supabase user UUID.

Never attach:

```text
email
phone
name
address
payment card
CVV
token
secret
```

6. Preserve `scrubContext` redaction.

7. Add defense-in-depth scrubbing in Sentry `beforeSend`.

8. Approve analytics event names:

```text
app_open
product_view
add_to_cart
begin_checkout
purchase_success
purchase_failure
paymob_initiate
paymob_success
paymob_failure
cod_confirm_success
cod_confirm_failure
```

9. Analytics parameters must be scrubbed before transmission.

10. Configure alerts for:

```text
crash-free user rate drop
checkout failure spike
payment failure rate
Paymob callback failure rate
Edge Function 5xx rate
expiry spike
stock restoration error
```

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Product Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 7: Android Release

## Context

Android release signing and CI pipeline must be secure and reproducible.

The current release build can silently fall back to debug signing when signing properties are missing. This is not acceptable.

## Configuration

| Item | Recommended Default | Notes |
|---|---|---|
| Release signing | Fail-closed | App must not build release if keystore missing; no debug-key release |
| CI release workflow | Protected | Manual approval gate; branch protection; artifact signing |
| `proguard-rules.pro` | Minimal approved rules | Keep only required Flutter/AndroidX/Kotlin/Play Services rules |

## Questions for Decision Maker

- [x] Approve fail-closed release signing?
- [x] Approve protected CI release workflow?
- [x] Approve minimal `proguard-rules.pro` after scope review?

## Recommended Default

Approve all:

```text
Fail-closed signing
Protected workflow
Minimal ProGuard rules
```

## Recommended Solution

Approve the following Android release policy:

1. The release build must fail if any required signing input is missing:

```text
KEYSTORE_BASE64
KEYSTORE_PASSWORD
KEY_ALIAS
KEY_PASSWORD
```

2. The release build must never fall back to debug signing.

3. The CI release workflow must:

   - decode keystore from GitHub secrets
   - write temporary ignored signing files
   - build APK/AAB
   - verify signature with `apksigner`
   - reject `androiddebugkey`
   - verify package name:

```text
com.albatal.elite
```

   - verify:

```text
debuggable=false
```

   - upload only verified artifact and redacted report

4. CI must never upload:

```text
keystore
key.properties
secrets
```

5. Approve minimal ProGuard rules for:

```text
Flutter engine
AndroidX
Google Play Services
Kotlin coroutines
native methods
@Keep annotation
```

6. Remove or strip debug logs in release where safe.

## Decision

| Approved By | Name | Date |
|---|---|---|
| Engineering Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 8: Beta Scope

## Context

Post-remediation beta must be scoped to limit blast radius while validating fixes.

The project should not launch publicly until all P0 and P1 gates pass.

## Configuration

| Item | Recommended Default | Notes |
|---|---|---|
| Beta user count | 10–20 users | After all P0/P1 gates pass |
| Platform scope | Android-only recommended | iOS requires separate TestFlight/App Store review |

## Questions for Decision Maker

- [x] Approve 10–20 user beta after all P0/P1 gates pass?
- [x] Platform scope:
  - [x] Android-only
  - [ ] Android + iOS, requires TestFlight setup

## Recommended Default

Android-only, 10–20 users. Expand to iOS after Android validation.

## Recommended Solution

Approve the following beta scope:

1. Beta begins only after:

```text
All P0 gates pass
All P1 launch-quality gates pass
Release gate document is signed
```

2. Beta size:

```text
10 to 20 users
```

3. Beta platform:

```text
Android only
```

4. iOS is deferred until:

```text
Android beta is stable
iOS signing is configured
TestFlight or App Store review path is ready
```

5. Beta monitoring must include:

```text
Sentry crash monitoring
payment failure alerts
checkout failure alerts
Edge Function error alerts
manual order reconciliation
```

6. Beta must be stopped immediately if:

```text
payment state inconsistency appears
stock restoration error appears
security issue appears
crash-free user rate drops below threshold
```

## Decision

| Approved By | Name | Date |
|---|---|---|
| Product Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| QA Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Decision 9: Release Gate Ownership

## Context

Each release gate requires a named approver. Without explicit ownership, releases are blocked or rushed.

## Gate Owners

| Gate | Recommended Approver Role | Name | Date |
|---|---|---|---|
| Product | Product Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Engineering | Engineering Lead | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| QA | QA Lead | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security | Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

## Questions for Decision Maker

- [x] Who approves Product gate?

```text
Product Owner — assign name
```

- [x] Who approves Engineering gate?

```text
Engineering Lead — assign name
```

- [x] Who approves QA gate?

```text
QA Lead — assign name
```

- [x] Who approves Security gate?

```text
Security Owner — assign name
```

## Recommended Default

Identify named individuals. No gate passes without named approver.

## Recommended Solution

Approve the following ownership model:

1. Product Owner approves:

```text
scope
beta size
user-facing risk
data policy
launch business readiness
```

2. Engineering Lead approves:

```text
code readiness
migration repair
Edge Function deployment
Flutter payment flow
Android release build
```

3. QA Lead approves:

```text
staging acceptance evidence
Paymob sandbox E2E
COD E2E
RLS negative tests
regression tests
```

4. Security Owner approves:

```text
secret hygiene
RPC grants
RLS verification
Paymob HMAC verification
Android signing proof
client trust boundary
```

5. No release is approved unless all four owners sign.

## Decision

| Gate | Approver Role | Name | Date |
|---|---|---|---|
| Product | Product Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Engineering | Engineering Lead | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| QA | QA Lead | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |
| Security | Security Owner | PENDING HUMAN SIGNATURE | PENDING HUMAN SIGNATURE |

---

# Summary: All Decisions Required

| # | Decision | Recommended Status | Final Status |
|---|---|---|---|
| 1 | Migration repair strategy | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 2 | COD missing-payment behavior | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 3 | Paymob callback gateway | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 4 | Staging and production Supabase projects | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 5 | Secret provisioning | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 6 | Observability | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 7 | Android release | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 8 | Beta scope | ✅ RECOMMENDED | Phase 0 selected / signature pending |
| 9 | Release gate ownership | ✅ RECOMMENDED | Phase 0 selected / signature pending |

---

## Signature Instructions

1. Preserve the selected Phase 0 options unless the project owner explicitly changes them.
2. Do not infer owner names, dates, approval references, or signatures.
3. Human owners must complete all `PENDING HUMAN SIGNATURE` fields before final release approval.
4. Final release sign-off is controlled by `docs/RELEASE_SIGNOFF.md` and remains pending until every technical gate has candidate-SHA-bound evidence.