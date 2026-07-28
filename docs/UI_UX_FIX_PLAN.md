# Al Batal Elite — UI/UX Fix Plan (Package UI-0)

> **STATUS:** AUTHORIZED — `PACKAGE-UI0-2026-07-28`
> **OWNER:** Mustaf Sayed Saeed · **DATE:** 2026-07-28
> **BASE:** `release-candidate/e9a6deb` (`e9a6debbb3f807030bab698f8b92241e5b3526d4`) — frozen tag, do not modify
> **BRANCH:** `fix/ui-phase-0` (new branch from the frozen tag)
> **AUDIT BASELINE:** `docs/UI_UX_AUDIT.md`
> **RELEASE VERDICT:** NO-GO (unchanged until Package M + UI-0 complete)

---

## 1. Decision

Fix only the P0 and money-trust issues first (Package UI-0). Do **not** fix all 47
audit issues at once. Do **not** modify the frozen tag `release-candidate/e9a6deb`.

### Relationship to existing packages

```text
PACKAGE M  — Paymob service-role runtime fix: REQUIRED
PACKAGE UI-0 — P0 UI/UX fixes: REQUIRED
E2E        — Paymob/callback/race: BLOCKED until Package M
RELEASE    — NO-GO until both Package M and UI-0 are complete
```

Parallel execution:

- **Track A — Package M:** human verifies/refreshes `SUPABASE_SERVICE_ROLE_KEY`,
  redeploys `paymob-initiate`, completes Paymob/callback/race E2E on candidate `e9a6deb`.
- **Track B — Package UI-0:** developer fixes P0 UI/UX issues on `fix/ui-phase-0`,
  CI green, new candidate tag, UI regression verification.

After both tracks: re-run COD smoke, Paymob initiation smoke, order history
verification, and address/checkout verification on the final UI-fixed candidate.

---

## 2. Package UI-0 Scope

Must fix (P0 + money trust):

| ID | Fix |
|---|---|
| UX-001 | Remove customer "Advance order" button; verify server authorization |
| UX-002 | Product details must show "Not found", never fall back to first product |
| UX-003 | Add required phone number field to address form for COD delivery |
| UX-004 | Stop discarding country in address form (`country: ''`) |
| UX-006 | Cancelled orders must not display "Delivered" |
| UX-010 | Add `awaitingVerification` UI and block duplicate Pay Now |
| UX-017 | Stop leaking raw exceptions to users (checkout snackbar) |
| UX-018 | Guard empty-cart checkout |
| UX-022 | Show real payment/order status, not collapsed "Placed" for everything |
| UX-005 | Localize payment error/status strings (EN + AR ARB) |

Optional if effort remains (otherwise early Phase 1):

| ID | Fix |
|---|---|
| UX-019 | Money formatting: replace wrong "EGY" code with localized EGP display |

### Not authorized under UI-0

- Modifying Supabase migrations (unless a separate backend package is authorized)
- Modifying Edge Functions
- Modifying the payment state machine expectations
- Changing server RPC contracts
- Setting secrets / deploying functions
- Merging to master / force push / deleting frozen tags
- Production or beta release

---

## 3. `update_order_status` Security Investigation

**Question:** does the backend allow non-admin users to advance order status
(the customer-facing "Advance order" button would then be a P0 security defect,
not just a UI defect)?

**Migration-level finding (read-only, 2026-07-29):**

- `supabase/migrations/014_paymob_security_repair.sql` (L90–146) redefines
  `update_order_status(uuid, text, text)` as `SECURITY DEFINER` with an explicit
  internal admin check: `SELECT COALESCE(profiles.is_admin, false) … IF NOT v_is_admin
  THEN RAISE EXCEPTION 'Admin access required'`. It also enforces a strict status
  transition matrix and row locking, and only admins may cancel `pending` orders;
  `pending → paid` is exclusively the callback RPC's path.
- `supabase/migrations/024_hardening_rpcs_policies.sql` (L216–219) revokes
  `PUBLIC`/`anon` and grants `EXECUTE` to `authenticated` only (admin-checked
  internally).
- Adversarial coverage exists: `supabase/tests/test_rls_adversarial.sql` case 3.6
  asserts "non-admin cannot update_order_status → exception".

**Conclusion (migration record):** the customer "Advance order" button is a
**UI-only defect** — the client-side `OrdersCubit.advance()` mutates local state
only in debug/local repo mode, and the server rejects non-admin status changes.
**Package N is not required based on the migration record.**

**Residual verification (human, staging, read-only):** run the privilege query
from the audit acceptance note against staging to confirm the deployed function
matches migration 014/024 (drift check):

```sql
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'update_order_status';

SELECT pg_get_functiondef('update_order_status(uuid,text,text)'::regprocedure);
```

If staging drifts from the migration record → open **PACKAGE N — ORDER STATUS
AUTHORIZATION REPAIR** (restrict to admin/service role, SQL test, re-run RLS
adversarial suite, freeze new candidate). Do not apply any migration under UI-0.

---

## 4. Implementation Requirements (per issue)

### UX-001 — Remove customer "Advance order" button
- Remove the button from the customer order card; remove/guard any customer-facing
  `advanceOrder` action. Keep admin functionality if behind an admin guard.
- Test: customer order card exposes no status-advance control.

### UX-002 — Product details wrong-product fallback
- Never fall back to the first catalog product; add a not-found state with
  localized "Product not found" + back action.
- Test: unknown product ID renders not-found.

### UX-003 — Address form phone number
- Required phone field in address forms: `TextInputType.phone`,
  `AutofillHints.telephoneNumber`, Egyptian mobile validation (`01XXXXXXXXX`).
- Include phone in the address snapshot object; AR + EN labels/errors.
- Tests: required phone + invalid phone rejected.

### UX-004 — Country preserved
- Pass the entered country into the `Address` object; never `country: ''`.
- Test: country preserved in the created address.

### UX-006 — Cancelled orders show "Delivered"
- Date/status label must depend on real status; cancelled never says Delivered;
  use "Placed on" or status-specific label; localized.
- Test: cancelled status label.

### UX-010 — awaitingVerification UI
- Persistent "Verifying payment…" panel while `awaitingVerification`; Pay Now
  disabled; duplicate payment initiation blocked; localized copy.
- Test: Pay Now disabled during `awaitingVerification`.

### UX-017 — Raw exception in checkout snackbar
- Friendly localized error in UI; raw error goes to logger/crash reporting only.
- Test: exception text never rendered.

### UX-018 — Empty-cart checkout
- Empty cart → checkout shows empty state or redirects; place-order disabled.
- Widget test.

### UX-022 — Truthful status labels
- Distinct localized labels: pending payment, paid, processing, placed,
  cancelled, delivered, refunded. No collapse of paid card orders into "Placed".
- Test: paid vs pending vs cancelled labels.

### UX-005 — Localize payment strings
- All hardcoded English payment error/status strings → ARB (EN + AR); no
  hardcoded English UI strings remain in `features/payments`.

### UX-019 (optional) — Money formatting
- Replace "EGY" with localized EGP (`intl NumberFormat.currency` or a single
  PriceText/PriceFormatter). EN: `EGP 1,290`; AR: `١٬٢٩٠ ج.م.` (or agreed style).
- Keep integer minor-unit math unchanged. Formatting tests EN/AR.

### Localization rules
- Every new user-visible string exists in `app_en.arb` **and** `app_ar.arb`;
  no hardcoded English in touched screens; preserve key naming style.

### Testing requirements
- `flutter analyze` passes; `flutter test` passes; widget tests per fixed flow;
  never delete existing passing tests to make CI green.

---

## 5. Branch Setup

```bash
git fetch origin --prune --tags
git worktree add ../albatal-ui-phase-0 -b fix/ui-phase-0 release-candidate/e9a6deb
cd ../albatal-ui-phase-0
git rev-parse HEAD   # expect e9a6debbb3f807030bab698f8b92241e5b3526d4
```

## 6. Commit Structure

Separate commits; stage explicitly (never `git add .` / `git add -A`):

```text
fix(orders): remove customer order advance control and fix status labels
fix(product): show not-found state instead of fallback product
fix(address): add phone field and preserve country
fix(payments): add awaiting verification state and block duplicate payment
fix(checkout): guard empty cart and replace raw error messages
fix(l10n): localize payment and order status strings
fix(money): localize currency formatting
test(ui): add coverage for UI-0 fixes
```

## 7. Definition of Done

```text
UX-001 … UX-022 + UX-005 fixed and tested
No hardcoded English strings remain in touched payment/order/address flows
flutter analyze passes
flutter test passes
CI passes
Draft PR open
New candidate tag created after CI green
update_order_status security investigation recorded  ✅ (see §3)
```

## 8. Manual QA Checklist (run in EN and AR)

**Product details:** valid product opens correct product; invalid ID shows
"Product not found"; no fallback; back works.

**Address form:** phone visible + required; invalid phone blocked; country
preserved; save works; Arabic labels correct.

**Checkout:** empty cart cannot checkout; raw exceptions not shown; friendly
error on failure; address phone included in order snapshot.

**Payments:** Pay Now disabled while verifying; awaiting-verification panel
visible; failure/cancel/timeout messages localized; no duplicate initiation.

**Orders:** no customer advance-order button; cancelled order never says
Delivered; paid shows paid; pending shows pending; dates and Arabic labels correct.

---

## 9. Later Phases (from audit §4 — not in UI-0)

- **Phase 1 — Core usability:** UX-008, UX-011, UX-012, UX-014, UX-015, UX-023,
  UX-025, UX-026, UX-020 (+ UX-019 if deferred)
- **Phase 2 — Trust & clarity:** UX-007, UX-009, UX-013, UX-021, UX-024, UX-041,
  UX-042, UX-016 (guest cart — product decision)
- **Phase 3 — Accessibility & RTL:** UX-031…UX-036
- **Phase 4 — Visual polish & design system:** UX-027…UX-029, UX-037, UX-039,
  UX-045…UX-047, component inventory, tokens
- **Phase 5 — Performance & delight:** UX-030, UX-038, UX-044
- **Backend-dependent (human review):** UX-040 (server addresses), UX-043
  (account deletion), image URLs for UX-009

## 10. Updated Release Blockers

```text
Package M   — Paymob service-role runtime fix
Package UI-0 — P0 UI/UX purchase/trust fixes
Package N   — only if staging drift found in update_order_status (unlikely per §3)
Paymob/callback/race E2E completion
Android signed artifact
Sentry staging crash evidence (if still missing)
Final release sign-off
```

**RELEASE: NO-GO** until the above complete.
