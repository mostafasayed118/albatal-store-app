# E2E Gates Execution Plan — Al Batal Elite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear the five remaining release-gate evidence items (COD E2E, Paymob sandbox E2E, race conditions, Sentry controlled event, Android artifact re-tie) against the isolated staging project and drive RELEASE_GATE.md to a GO/NO-GO decision.

**Architecture:** Evidence-collection execution on the NEW isolated staging Supabase project (`zvpjngdgbpnkkqrorkul`), driven by env-gated Node `pg` runners that read `STAGING_DB_URL` and hard-refuse any other project ref. Code changes are limited to test runners, one kDebugMode-only crash trigger, and docs. All evidence lands in `docs/evidence/e2e-2026-08-23/`.

**Tech Stack:** Flutter 3.48 / Dart 3 (BLoC, GetIt, GoRouter, Supabase), Supabase CLI 2.109.1 (workdir linked to `zvpjngdgbpnkkqrorkul`), Node 22 + `pg` (repo-local `node_modules`), Deno 2.9.4, GitHub Actions + `gh` CLI 2.x, Android emulator (AVD `Pixel_9_Pro`, device `emulator-5556`).

**Spec:** `docs/RELEASE_GATE.md` (gate definitions and evidence requirements — binding authority) plus the execution draft approved by the owner in session on 2026-08-23 ("do all you need i approved"). Authorization reference: `STAGING-E2E-ZVPJ-AC69C54-2026-08-23`.

## Global Constraints

- **Staging-only:** every DB / edge-function / HTTP action targets project ref `zvpjvyflasewslinufqe`'s replacement — the isolated staging ref `zvpjngdgbpnkkqrorkul`. The prior project `alxwvyflasewslinufqe` is now **PRODUCTION** — never connect, probe, deploy, or run any runner against it.
- **No secret values** printed, logged, committed, or pasted into evidence files. DB access ONLY via the `STAGING_DB_URL` environment variable (set per-shell; never committed; never written into `.env*` files — those are owner-edited per AGENTS.md).
- **Never edit** `.env`, `.env.*`, `auth/`, `payments/`, `secrets/`, `credentials/`, or `supabase/migrations/`. Findings that would require a migration go to the ledger for an owner decision.
- **No push / merge / PR merge** without owner approval (AGENTS.md). Code work happens in worktree `C:\flutter_projects\albatal-e2e` on branch `fix/e2e-gates-evidence`, branched from master after the docs commit.
- Evidence directory: `docs/evidence/e2e-2026-08-23/` (created in Task 2). Every task writes its raw command + output there.
- State-mutating SQL suites must run inside BEGIN/ROLLBACK or clean up after themselves; record staging `orders` / `payments` counts before and after each run.
- For every L2 code change: `flutter analyze` (0 issues) and `flutter test` (243/243) in the worktree before claiming done.
- Runners on master still embed the OLD project URL until this branch merges — **do not execute any runner from the main workspace** until Task 1's branch is merged.
- Do not modify `.gitleaks.toml` or CI workflow files (AGENTS.md human gate); stale allowlist entries are reported, not edited.

## Task 0 — Owner prerequisites (human gate; blocks Tasks 2–6)

Not dispatchable. Track status in the ledger.

- [ ] **0.1 Paymob dashboard (blocks Task 4 live flow):** create second integration `al-batal-staging` with TEST credentials; set `PAYMOB_IFRAME_ID` secret on staging (`supabase secrets set PAYMOB_IFRAME_ID=<value> --project-ref zvpjngdgbpnkkqrorkul`); set transaction callback/redirect URL to `https://zvpjngdgbpnkkqrorkul.supabase.co/functions/v1/paymob-callback`; confirm `verify_jwt` is OFF for `paymob-callback` in the staging dashboard. (Details: `docs/evidence/isolation-2026-08-23/README.md`.)
- [ ] **0.2 Staging DB password (blocks Tasks 2, 3, 4, 5):** reset via Supabase dashboard on `zvpjngdgbpnkkqrorkul`, then set in each execution shell: `$env:STAGING_DB_URL = 'postgresql://postgres.zvpjngdgbpnkkqrorkul:<password>@aws-1-eu-west-1.pooler.supabase.com:5432/postgres'`. Never echo, never commit.
- [ ] **0.3 Sentry project (blocks Task 6 live event):** create a Sentry project, put its DSN into `config/env.staging.local.json` `SENTRY_DSN` (owner-edited file) and `.env.staging` if needed.
- [ ] **0.4 Production DB password rotation (security, no dependencies):** the committed runners embed a live connection string for the pre-isolation project (now production). The value persists in git history — rotate the production DB password in the dashboard.

---

### Task 1: Safety-guard the DB runners and remove embedded credentials

**Files:**
- Modify: `supabase/tests/verify_paymob_sandbox.mjs` (replace hardcoded `STAGING_URL` constant, lines ~1–10)
- Modify: `supabase/tests/run_rls_adversarial.mjs` (same treatment)
- No test files (verification is negative-run based; `node --check` for syntax)

**Interfaces:**
- Produces: env contract `STAGING_DB_URL` consumed by Tasks 2–5 runners; guard constant `REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul'` reusable by new runners in Tasks 3–5.

**Worktree:** `C:\flutter_projects\albatal-e2e`, branch `fix/e2e-gates-evidence`. Run `npm install` first (worktree has no `node_modules`).

- [ ] **Step 1: In both runners, replace the hardcoded connection constant with an env read + refusal guard.** The guard MUST run before any `new Client(...)` / `client.connect()` so a wrong target can never even attempt a connection. Exact replacement code:

```js
import { Client } from 'pg';

// ── SAFETY GUARD ─────────────────────────────────────────────
// This script may ONLY run against the isolated STAGING project.
// The previous staging project ref (alxwvyflasewslinufqe) is now
// PRODUCTION and must never be touched by test runners.
// Connection string comes from the STAGING_DB_URL env var only —
// never from a committed constant.
const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
const STAGING_URL = process.env.STAGING_DB_URL ?? '';

if (!STAGING_URL) {
  console.error('ABORT: STAGING_DB_URL is not set. Export the isolated staging connection string first.');
  process.exit(1);
}
if (!STAGING_URL.includes(REQUIRED_STAGING_REF)) {
  console.error(`ABORT: STAGING_DB_URL does not reference the isolated staging project ${REQUIRED_STAGING_REF}. Refusing to run.`);
  process.exit(1);
}
// ── END SAFETY GUARD ─────────────────────────────────────────
```

Delete the old `const STAGING_URL = 'postgresql://...'` line entirely (credential removal). Keep every other line of both files byte-identical where possible.

- [ ] **Step 2: Syntax check.** Run in worktree: `node --check supabase/tests/verify_paymob_sandbox.mjs` and `node --check supabase/tests/run_rls_adversarial.mjs`. Expected: both exit 0, no output.

- [ ] **Step 3: Negative run A (no env).** `node supabase/tests/verify_paymob_sandbox.mjs` with `STAGING_DB_URL` unset. Expected: prints `ABORT: STAGING_DB_URL is not set...`, exit code 1, **no connection attempt**.

- [ ] **Step 4: Negative run B (production-shaped URL).** `$env:STAGING_DB_URL='postgresql://postgres.alxwvyflasewslinufqe:dummy-not-real@aws-1-eu-west-1.pooler.supabase.com:5432/postgres'; node supabase/tests/verify_paymob_sandbox.mjs`. Expected: `ABORT: ... does not reference the isolated staging project...`, exit code 1, no connection attempt. Repeat both negative runs for `run_rls_adversarial.mjs`. Capture all four outputs to `.superpowers/sdd/2026-08-23-e2e-gates-execution-plan/task-1-guard-proofs.txt` (in the MAIN workspace, not the worktree).

- [ ] **Step 5: Positive-shape run.** `$env:STAGING_DB_URL='postgresql://postgres.zvpjngdgbpnkkqrorkul:dummy-not-real@aws-1-eu-west-1.pooler.supabase.com:5432/postgres'; node supabase/tests/verify_paymob_sandbox.mjs`. Expected: guard passes, script proceeds and fails at `client.connect()` with a connection/auth error (proves the guard admits the correct project). Connection failure here is the EXPECTED outcome — do not "fix" it.

- [ ] **Step 6: Confirm credential removal.** `Select-String -Path supabase\tests\*.mjs -Pattern 'postgresql://'` — expected: zero hits in the two edited files (other runner files are untouched by this task). Also confirm the string `alxwvyflasewslinufqe` no longer appears in either edited file except inside the guard comment, if at all.

- [ ] **Step 7: Standard gates.** In the worktree: `flutter analyze` (expect 0 issues) and `flutter test` (expect 243/243). This change touches no Dart code, but the gates run per AGENTS.md for L2 changes.

- [ ] **Step 8: Commit (worktree branch only, no push).**

```powershell
git add supabase/tests/verify_paymob_sandbox.mjs supabase/tests/run_rls_adversarial.mjs
git commit -m "test(runners): env-gate staging DB runners, remove embedded credentials

Runners now require STAGING_DB_URL referencing zvpjngdgbpnkkqrorkul
and refuse to run otherwise. Removes the hardcoded connection string
to the pre-isolation project (now production). Production DB password
rotation recommended — value persists in git history."
```

---

### Task 2: RLS adversarial 44/44 on the NEW staging (blocked on 0.2)

**Files:**
- Modify (regenerate): `supabase/tests/test_rls_adversarial_cli.sql` (generated artifact of `transform_rls.mjs`)
- Create: `docs/evidence/e2e-2026-08-23/rls-adversarial-output.txt`
- Create: `docs/evidence/e2e-2026-08-23/README.md` (evidence index for the whole run)

**Interfaces:**
- Consumes: Task 1 env contract (`STAGING_DB_URL` + guard) in `run_rls_adversarial.mjs`.
- Produces: evidence file referenced by RELEASE_GATE.md row "RLS adversarial" re-verification for `zvpjngdgbpnkkqrorkul`.

- [ ] **Step 1:** In worktree, regenerate the CLI-safe suite: `node supabase/tests/transform_rls.mjs` (verify it rewrites `supabase/tests/test_rls_adversarial_cli.sql`; if the transform script writes a different path, adapt and record in report).
- [ ] **Step 2:** Record pre-run counts: run a guarded one-shot query (see Task 3 probe script pattern) for `SELECT (SELECT count(*) FROM orders), (SELECT count(*) FROM payments);` — save output.
- [ ] **Step 3:** `node supabase/tests/run_rls_adversarial.mjs` with `STAGING_DB_URL` set. Expected: **44 PASS / 0 FAIL**.
- [ ] **Step 4:** Capture full console output to the evidence file; record post-run counts (must equal pre-run).
- [ ] **Step 5:** Create `docs/evidence/e2e-2026-08-23/README.md` index; commit evidence on the worktree branch.

---

### Task 3: COD E2E (blocked on 0.2; emulator flow also needs a signed-up user)

**Files:**
- Create: `supabase/tests/check_staging_probe.mjs` (guarded one-shot query runner, reusable by Tasks 2/4/5)
- Create: `docs/evidence/e2e-2026-08-23/cod-e2e-output.txt`

**Interfaces:**
- Consumes: Task 1 env contract.
- Produces: `check_staging_probe.mjs` usage pattern `node supabase/tests/check_staging_probe.mjs "SELECT ..."` for all later ad-hoc verification queries.

- [ ] **Step 1: Create the guarded probe runner** (full code; same guard block as Task 1):

```js
import { Client } from 'pg';

const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
const STAGING_URL = process.env.STAGING_DB_URL ?? '';
if (!STAGING_URL) { console.error('ABORT: STAGING_DB_URL is not set.'); process.exit(1); }
if (!STAGING_URL.includes(REQUIRED_STAGING_REF)) { console.error(`ABORT: not the isolated staging project ${REQUIRED_STAGING_REF}.`); process.exit(1); }

const sql = process.argv[2];
if (!sql) { console.error('usage: node check_staging_probe.mjs "<sql>"'); process.exit(1); }
const client = new Client({ connectionString: STAGING_URL, ssl: { rejectUnauthorized: false } });
try { await client.connect(); const r = await client.query(sql); console.log(JSON.stringify(r.rows, null, 2)); }
catch (e) { console.error('QUERY FAILED:', e.message); process.exit(1); }
finally { await client.end(); }
```

- [ ] **Step 2: RPC presence.** `node supabase/tests/check_staging_probe.mjs "SELECT proname FROM pg_proc WHERE proname = 'confirm_cod_payment';"` — expect one row.
- [ ] **Step 3: SQL suite.** Execute `supabase/tests/test_cod_payment.sql` through a node pg connection (read file, `client.query(fileText)`; it is BEGIN/ROLLBACK-wrapped). Expect all 8 documented scenarios pass. Then the same for `supabase/tests/test_confirm_cod_payment_repair.sql` (post-022/026 repaired behavior). Capture both outputs.
- [ ] **Step 4: Live emulator flow.** Boot AVD `Pixel_9_Pro` if none running (`emulator -avd Pixel_9_Pro` or use authorized device `emulator-5556`). Copy `config\env.staging.local.json` from main workspace into the worktree's `config\` (gitignored, client-safe values only). `flutter run --dart-define-from-file=config/env.staging.local.json`. In-app: sign up `cod-e2e@test.albatal` (autoconfirm is on), add a product to cart, checkout with COD, confirm order. Then verify via probe: order row `status='paid'`, payment row `status='success'`, variant stock decremented. Capture screenshots (`adb exec-out screencap -p > ...`) of cart, checkout, success. If adb-driven taps prove too brittle, fall back to owner-driven app interaction with agent-side DB verification — record which path was used.
- [ ] **Step 5:** Write evidence file, commit.

---

### Task 4: Paymob sandbox E2E (DB-level blocked on 0.2; live Flutter flow blocked on 0.1)

**Files:**
- Create: `supabase/tests/probe_paymob_callback.mjs` (HTTP probe with HMAC crafting)
- Create: `docs/evidence/e2e-2026-08-23/paymob-sandbox-output.txt`

**Interfaces:**
- Consumes: Task 1 env contract (DB checks); `PAYMOB_HMAC_SECRET` from the owner's local `.env.staging` (read via env var in the shell — the operator exports it; the script never reads `.env.staging` directly and never prints the value).
- Produces: evidence for RELEASE_GATE.md row "Paymob sandbox E2E".

- [ ] **Step 1: DB-level flows.** `node supabase/tests/verify_paymob_sandbox.mjs` — expect F1 success, F2 decline, F3 cancel, F4 idempotency all PASS with cleanup executed.
- [ ] **Step 2: Create the HTTP probe** (guarded: URL must contain staging ref; secret only from `process.env.PAYMOB_HMAC_SECRET`). It builds a canonical payload from the 20 documented fields in exact order (`amount_cents, created_at, currency, error_occured, has_parent_transaction, id, integration_id, is_3d_secure, is_auth, is_capture, is_refunded, is_standalone_payment, is_voided, order, owner, pending, source_data_pan, source_data_sub_type, source_data_type, success` — values concatenated with no separators), computes HMAC-SHA512 hex-lowercase with `crypto.createHmac`, and POSTs form-urlencoded to `https://zvpjngdgbpnkkqrorkul.supabase.co/functions/v1/paymob-callback`:
  - Probe A (forged hmac): garbage `hmac` field → expect **HTTP 401** `{"message":"Invalid signature"}`, zero state change.
  - Probe B (valid hmac, amount mismatch): correct signature but `amount_cents` ≠ order total → expect rejection (capture exact HTTP + body).
  - Probe C (valid hmac, late callback on an expired/cancelled order): expect `already_processed` semantics, order stays cancelled (verify via probe query).
- [ ] **Step 3: Full Flutter flow (blocked on 0.1):** checkout → `paymob-initiate` returns `checkout_url` → complete sandbox payment in the Paymob iframe → order flips to `paid` (verify via `check_staging_probe.mjs`). Capture screenshots.
- [ ] **Step 4:** Write evidence, commit.

---

### Task 5: Race-condition suite on new staging (blocked on 0.2)

**Files:**
- Create: `supabase/tests/run_race_conditions.mjs` (adapter)
- Create: `docs/evidence/e2e-2026-08-23/race-conditions-output.txt`

**Interfaces:**
- Consumes: Task 1 env contract; committed suite `supabase/tests/test_race_conditions.sql` (source of truth — not modified).
- Produces: evidence for RELEASE_GATE.md row "Race conditions" (T-RC01–T-RC14).

- [ ] **Step 1: Create the adapter** — reads `test_race_conditions.sql`, strips psql meta-command lines (`/^\s*\\/`), executes the remainder as a single multi-statement query inside the existing BEGIN/ROLLBACK, and reports PASS when no exception is raised (the suite uses `RAISE EXCEPTION` on failure — exit 0 with "14 scenarios PASS" summary; any exception = FAIL with the message). Same guard block as Task 1.
- [ ] **Step 2:** Run with `STAGING_DB_URL` set. Expected: exit 0, no exception → T-RC01–T-RC14 PASS.
- [ ] **Step 3:** Capture output to evidence file; verify orders/payments counts unchanged; commit.

---

### Task 6: Sentry controlled event (code part dispatchable now; live event blocked on 0.3)

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (add kDebugMode-only crash trigger tile)
- Test: `test/settings_crash_trigger_test.dart` (new — widget test asserting the trigger is visible in debug builds and invokes `CrashReportingService.captureError` with context whose sensitive keys arrive scrubbed)
- Create: `docs/evidence/e2e-2026-23-sentry-output.txt` → correct path: `docs/evidence/e2e-2026-08-23/sentry-output.txt`

**Interfaces:**
- Consumes: `CrashReportingService` from `lib/shared/services/crash_reporting_service.dart` (via the project's service locator — check `lib/shared/services/service_locator.dart` for the exact accessor), `scrubContext` static redaction.
- Produces: live Sentry event evidence for RELEASE_GATE.md row "Sentry".

- [ ] **Step 1: Write the failing widget test** (assert trigger tile exists in debug mode; assert `scrubContext({'card': 'x', 'email': 'y'})` values are `[REDACTED]` — scrub is already unit-tested, so the new assertion focuses on the trigger wiring).
- [ ] **Step 2: Run it, verify it fails** (tile doesn't exist yet).
- [ ] **Step 3: Implement the trigger** — debug-only `ListTile` in settings:

```dart
import 'package:flutter/foundation.dart' show kDebugMode;
// inside the settings page's build, after the existing tiles:
if (kDebugMode)
  ListTile(
    dense: true,
    title: const Text('Trigger test crash (debug only)'),
    subtitle: const Text('Controlled Sentry event — E2E gate evidence'),
    onTap: () {
      // Resolve via the project service locator (see service_locator.dart
      // for the exact registration/accessor name).
      locator<CrashReportingService>().captureError(
        StateError('e2e-controlled-crash-2026-08-23'),
        StackTrace.current,
        context: {
          'test_marker': 'e2e-2026-08-23',      // must arrive verbatim
          'card': '4111-1111-1111-1111',        // must arrive [REDACTED]
          'email': 'victim@example.com',        // must arrive [REDACTED]
        },
      );
    },
  ),
```

- [ ] **Step 4: Run the test, verify pass; run full gates** (`flutter analyze` 0 issues, `flutter test` 244/244).
- [ ] **Step 5: Commit.**
- [ ] **Step 6 (blocked on 0.3):** With DSN set in `config/env.staging.local.json`, run on emulator, tap the trigger, verify the event in the Sentry dashboard shows `test_marker` verbatim and `card`/`email` as `[REDACTED]`; screenshot dashboard event; write evidence; commit evidence.

---

### Task 7: Android artifact re-tie

**Files:**
- Create: `docs/evidence/e2e-2026-08-23/android-artifact-reetie.md`

**Interfaces:**
- Consumes: CI run `32646592228` on master `ac69c54` (conclusion success).
- Produces: re-tied "Android signed artifact" evidence row.

- [ ] **Step 1:** `gh api repos/<origin-slug>/actions/runs/32646592228/artifacts` (get slug from `git remote -v`) — list artifact names.
- [ ] **Step 2:** `gh run download 32646592228 --name <artifact> --dir .openclaw/tmp/e2e-artifact` (main workspace temp; artifact is a signed APK).
- [ ] **Step 3:** Record `Get-FileHash -Algorithm SHA256` of the APK; `jarsigner -verify -verbose:summary <apk>` (JDK ships with the Android toolchain); package identity via `aapt dump badging <apk> | Select-String "package:"` (aapt in `%LOCALAPPDATA%\Android\Sdk\build-tools\<ver>\`). Confirm `debuggable` absent.
- [ ] **Step 4:** Write evidence file (SHA-256, signature result, package identity, provenance: run ID + SHA `ac69c54`), commit.

---

### Task 8: Consolidation and GO/NO-GO

**Files:**
- Modify: `docs/RELEASE_GATE.md` (5 gate rows + candidate notes)
- Modify: `docs/RELEASE_SIGNOFF.md` (evidence links)
- Modify: `STATE.md` (run record)

- [ ] **Step 1:** Update each gate row with its evidence link from `docs/evidence/e2e-2026-08-23/`; any row lacking evidence stays NO-GO with the blocking owner item named.
- [ ] **Step 2:** Update STATE.md run record; list rulings from the ledger.
- [ ] **Step 3:** Present the branch for owner review (no merge without approval). Final whole-branch review per SDD skill before handoff.
