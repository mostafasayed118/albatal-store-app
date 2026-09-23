# Al Batal Elite — Security Audit (2026-09-21)

- **Tree audited:** `master` @ `ef91836` (2026-09-21)
- **Scope:** `lib/` (269 files), `supabase/migrations/` (65), `supabase/functions/` (10 + `_shared`),
  `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `config/*.json` (structure only)
- **Prior art read:** `docs/audit/2026-09-15/05-reaudit.md` (R1–R11 residual register)
- **Method:** read-only. Every finding below was produced by opening the cited file. No live DB or
  network probing was performed, so items whose control lives in the database are labelled
  *unverified*, never *missing*. No secret value is printed anywhere in this document.
- **Skipped as instructed:** `node_modules`, `.mimocode`, `.openclaw`, `build`, `.dart_tool`,
  `coverage`, `outputs`, `delivery`.

---

## Verification of the 2026-09-15 residual register (in-tree state on this tree)

| ID | Claim to verify | Verified in-tree state | Verdict |
|---|---|---|---|
| R1 / AUD-008 | `061_admin_profiles_read.sql` shipped; DB application owner-gated | File present at `supabase/migrations/061_admin_profiles_read.sql:1` with the `is_current_user_admin()` SECURITY DEFINER helper (30-41) and the additive `profiles_select_admin` policy (47-52). `STATE.md` records it applied to staging **and** production. | **Closed in-tree** |
| R6 | Release keystores in repo root | The two repo-root duplicates are gone. One live keystore remains **inside the tree** at `android/app/release-key.jks` (untracked; `git ls-files` shows zero `.jks`/`.keystore`/`key.properties`). See LOW finding below. | **Partially closed** |
| R7 | No certificate pinning | Confirmed absent: no `badCertificateCallback`, `onBadCertificate`, `setTrustedCertificates`, or `HttpOverrides` anywhere in `lib/`. Consistent with the owner's written waiver. | **Waived (documented)** |
| R10 / AUD-014 | Staging anon key placeholdered in-tree | Confirmed by shape, not by value: `config/env.staging.json` `SUPABASE_ANON_KEY` is **29 chars**, `config/env.production.json` is **32 chars** and its `SENTRY_DSN` is **34 chars** — all placeholder-shaped (real values in this stack are ~46 / ~95 chars, as the gitignored `.local.json` files show). `config/env.*.local.json` is gitignored (`.gitignore:22`); only `config/README.md`, `env.production.json`, `env.staging.json` are tracked. No JWT-shaped token (`eyJ…`) exists in any tracked file. | **Closed in-tree** |

New surfaces reviewed for this pass: admin customer tier (046 + `admin_set_membership_tier`), orders
CSV export (`orders_csv_exporter.dart`), coupons route (056 + `validate_coupon` + `admin_coupons_page`),
the Paymob initiate/callback pair, and the notification/OneSignal scaffold.

---

## MEDIUM — Applying a valid coupon sends `p_coupon_code` to a checkout RPC that no in-tree migration defines, so the money path breaks (or the advertised discount is never honored)

**Location:** `lib/features/storefront/data/checkout_service.dart:91` → `supabase/migrations/056_coupons.sql:63-70`

**Issue:** `CheckoutService.placeOrder` adds `'p_coupon_code': couponCode` to the
`create_checkout_order` RPC call whenever a coupon validated
(`checkout_cubit.dart:228` passes `couponCode: state.appliedCoupon?.code`). But the coupon migration
deliberately does **not** ship the server side: `056_coupons.sql:63-70` is a `NOTE FOR REVIEWER`
block stating that the rewritten function body "is intentionally NOT inlined here". A repo-wide grep
for `p_coupon_code` across `supabase/` and `lib/` returns only that comment and the client call — no
migration in this repository defines the parameter. `STATE.md:7421-7423` records that on staging
`validate_coupon` **is** callable, i.e. a coupon can validate successfully.

**Impact:** On any database where `validate_coupon` exists but `create_checkout_order` has not been
extended, the client sends an unknown RPC argument. PostgREST answers `PGRST202`
("Could not find the function … in the schema cache"), which `checkout_service.dart:125-133` collapses
to a generic `Checkout failed` — so **a customer who applies a valid coupon cannot complete checkout at
all**. The alternative failure mode (if the parameter is silently accepted and ignored) is worse for
trust: the customer is shown `couponApplied` (`checkout_page.dart:294`) and then charged the
undiscounted server total, because the discount is applied nowhere. This is a money-path
integrity/availability defect introduced with the new coupons route. *Caveat: I could not read the live
function definition (no DB access), so I cannot exclude an out-of-band application; what is certain is
that the repository contains no server-side coupon implementation to deploy.*

**Fix:** Ship the delta as a real migration before the client build that sends the parameter. Minimal
form, replacing the comment block at `056_coupons.sql:63-70`:

```sql
-- 066_coupons_checkout.sql — server-side coupon application
CREATE OR REPLACE FUNCTION public.create_checkout_order(
  p_payment_method text,
  p_address jsonb,
  p_items jsonb,
  p_idempotency_key text DEFAULT NULL,
  p_coupon_code text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_coupon_discount integer := 0;
  v_coupon_id       uuid;
BEGIN
  -- ... existing body unchanged up to the shipping computation ...
  IF p_coupon_code IS NOT NULL AND length(trim(p_coupon_code)) > 0 THEN
    SELECT c.id, c.discount_minor
      INTO v_coupon_id, v_coupon_discount
      FROM public.coupons c
     WHERE upper(trim(c.code)) = upper(trim(p_coupon_code))
       AND c.active
       AND (c.expires_at IS NULL OR c.expires_at > now());
    v_coupon_discount := coalesce(v_coupon_discount, 0);
  END IF;

  v_total := GREATEST(v_subtotal + v_shipping - v_coupon_discount, 0);
  -- ... insert with coupons_id = v_coupon_id, coupon_discount_minor = v_coupon_discount ...
END $$;
```

Until that lands, gate the client: in `checkout_cubit.dart:228` send `couponCode` only when a
build-time/remote-config flag says the server accepts it (the same fail-soft pattern already used by
`SupabaseCouponsRepository` for the missing RPC).

---

## MEDIUM — `validate_coupon` is executable by `anon` with no rate limit: an unauthenticated coupon-enumeration oracle

**Location:** `supabase/migrations/056_coupons.sql:44-61` → `lib/features/storefront/data/supabase_coupons_repository.dart:30`

**Issue:** The RPC is `SECURITY DEFINER` (`056_coupons.sql:45-53`) and returns the coupon's
`code`, `discount_minor` and `description` for any matching active, unexpired row, including
`description` which is free text an operator may use to note the campaign. Its grant is
`GRANT EXECUTE ON FUNCTION public.validate_coupon(text) TO anon, authenticated;`
(`056_coupons.sql:60-61`). There is no rate limiting on this RPC: `enforceRateLimit`
(`supabase/functions/_shared/rate_limit.ts`) is wired into `instapay-initiate`, `instapay-submit-proof`,
`delete-account` and `paymob-callback`, but `validate_coupon` is called directly from the client and
never passes through an Edge Function. The client call site is
`supabase_coupons_repository.dart:29-32`.

**Impact:** An unauthenticated attacker can loop guesses against a short, human-memorable code space
(`SAVE10`, `EID50`, …) and enumerate live promo codes — including the discount value — with no
credential and no throttle. Coupon codes are a revenue control; leaking the live set lets anyone claim
the discount and lets a competitor map the campaign calendar. Severity is held at MEDIUM rather than
HIGH because the discount is not currently applied server-side (see the finding above), so the leak has
no monetary effect *today*; the moment the checkout delta ships, this becomes the way to harvest every
active code.

**Fix:** Narrow the grant to authenticated callers and put a limiter in front of it.

```sql
-- in 066 (or a follow-up migration)
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.validate_coupon(text) TO authenticated;
```

and, because an authenticated customer can still brute-force, add an attempt counter to the same RPC
using the existing limiter primitive (`rate_limit_take`, `060_rate_limits.sql:29`) — bucket
`coupon:user:<auth.uid()>`, limit ~10/hour — returning a generic `invalid` past the budget so the
oracle's throughput collapses. If guest checkout with coupons is a product requirement, keep the `anon`
grant but route the check through a small Edge Function that applies `enforceRateLimit` on
`clientIp(req)` before calling the RPC.

---

## MEDIUM — A server-driven sign-out clears the profile but leaves the on-device address book and order snapshots (PII) intact

**Location:** `lib/features/auth/presentation/cubit/auth_cubit.dart:296-308` (vs. the correct path at `201-213`)

**Issue:** The explicit `signOut()` path is careful: it calls `_clearLocalSnapshots()` (line 207),
which wipes the address book and order snapshots with a retry
(`auth_cubit.dart:258-294`, `local_address_repository.dart:94-101`,
`storefront_persistence.dart:162-165`). The **auth-state listener** does not do this:

```dart
// auth_cubit.dart:296-308
void _listenToAuthChanges() {
  _authSubscription = _authRepository.authStateChanges.listen((outcome) async {
    if (outcome != null) { await _loadProfile(outcome.userId); }
    else {
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearProfile: true));
    }
  });
}
```

`authStateChanges` is backed by `SupabaseAuthRepository.authStateChanges`
(`supabase_auth_repository.dart:147-160`), which emits `null` for `AuthChangeEvent.signedOut`. That
event fires when the refresh token is rejected or the session is revoked server-side — a routine
occurrence (refresh-token rotation failure, an admin deleting the user, a revoked token) — and is
independent of the in-app sign-out button. This branch never calls `_clearLocalSnapshots()`.

**Impact:** After a server-side session death, the device keeps the full encrypted address book
(`saved_addresses_v1`) and the order-history snapshot (`storefront_orders_v1`, which per
`storefront_persistence.dart:207-231` embeds the complete shipping address for every past order). The
next person to use the device sees a signed-out shell but the PII is still at rest on it, and the
`AppLockGate` lock may be off. This is a defence-in-depth gap rather than a remote exploit: the values
are keystore-encrypted, so the exposure is local-device, not network.

**Fix:** Route the listener branch through the same wipe. In `auth_cubit.dart:302-307`:

```dart
} else {
  // signedOut — clear local state AND on-device PII (audit 2026-09-21 S3):
  // this branch also fires on server-side session death, not just the
  // in-app sign-out button.
  await _clearLocalSnapshots();
  if (isClosed) return;
  emit(state.copyWith(
    status: AuthStatus.unauthenticated,
    clearProfile: true,
  ));
}
```

`_clearLocalSnapshots` is already contained (it never throws, retries once, and re-schedules a
best-effort wipe), so calling it from a stream listener is safe. Add a test asserting that a
`Stream.value(null)` from the fake auth repository leaves `LocalAddressRepository.clearAddresses` and
`OrderSnapshotPort.clearOrderSnapshots` called.

---

## MEDIUM — Two externally-created tables (`notifications`, `analytics_events`) have no in-tree RLS evidence, and `053`'s policy on `analytics_events` is inert unless RLS was enabled out-of-band

**Location:** `supabase/migrations/048_external_lineage.sql:5-7`, `supabase/migrations/053_analytics_events.sql:13-26`, `supabase/functions/send-order-notification/index.ts:142-150`

**Issue:** `048_external_lineage.sql` documents that migrations 048–051 were applied to the linked
database by a parallel session and that their SQL was never committed: "Verified live objects
attributable to them: analytics_events … and notifications. … Content unknown."
`notifications` is written by the service-role path in
`send-order-notification/index.ts:142-150`, which inserts **`recipient_email`, `recipient_name`,
`order_id`, `subject`, `body`** — i.e. customer PII. Nothing in this repository states that
`notifications` has RLS enabled or what its policies are.

Separately, `053_analytics_events.sql:13-26` creates an `analytics_insert_own` INSERT policy via a
`DO` block but the file contains **no** `ALTER TABLE … ENABLE ROW LEVEL SECURITY` (verified: the
statement does not appear anywhere in 053, and the table is created by the external migration, not by
053). A policy on a table whose RLS is disabled has no effect at all — access is then governed purely
by table grants, which for an externally-created table in `public` are also unknown.

**Impact:** *Unverified, not claimed.* If either table was created without RLS and with Supabase's
default `GRANT ALL … TO anon, authenticated` (the default for objects created through the SQL editor /
some migration paths), then `notifications` is readable — including every customer email and name —
by any authenticated user (and possibly by `anon`) via PostgREST, and `analytics_events` is
world-writable/readable. That would be a silent PII exposure. I could not confirm it because the
creating SQL is not in the repository and live probing was out of scope, so this is reported as a
control that must be *proven*, not as a demonstrated vulnerability. The inert-policy half, however, is
certain from the file contents.

**Fix:** Two steps. (1) Prove the current posture with a read-only query and record the result in
`STATE.md`:

```sql
select c.relname, c.relrowsecurity, c.relforcerowsecurity,
       coalesce(p.polname, '(no policy)') as policy,
       coalesce(p.polcmd, '-')          as cmd
  from pg_class c
  left join pg_policy p on p.polrelid = c.oid
 where c.relnamespace = 'public'::regnamespace
   and c.relname in ('notifications', 'analytics_events');
```

(2) If `relrowsecurity` is false for either, close it with an explicit migration that both enables RLS
and states the intended policy:

```sql
-- 067_lock_external_lineage_tables.sql
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
-- Only admins read the notification log; the service role bypasses RLS.
CREATE POLICY notifications_admin_read ON public.notifications
  FOR SELECT USING (public.is_current_user_admin());   -- helper from 061
REVOKE ALL ON public.notifications FROM anon, authenticated;
GRANT  SELECT ON public.notifications TO authenticated;  -- policy still filters

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
-- (analytics_insert_own from 053 then becomes effective)
```

Also add `ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;` at the top of
`053_analytics_events.sql` so a fresh environment replaying the migrations gets RLS regardless of what
the external migration did.

---

## LOW — `public.rate_limits` never enables RLS; its only control is a `REVOKE`

**Location:** `supabase/migrations/060_rate_limits.sql:14-27`

**Issue:** The table is created (14-19) and locked down with
`revoke all on public.rate_limits from anon, authenticated, public;` (27), but there is no
`ENABLE ROW LEVEL SECURITY`. The revoke is a correct and sufficient control today — access is
grant-only, and the `SECURITY DEFINER` `rate_limit_take` (29-64) runs as the owner. The gap is
structural: RLS is the project's stated defence-in-depth boundary everywhere else, so a table that
relies solely on grants will silently become world-readable if a future migration or dashboard action
re-grants `SELECT`.

**Impact:** No exposure today. Buckets are `<kind>:<id>` (e.g. `proof:user:<uuid>`), so the table does
contain user identifiers, which is why the belt-and-braces matters.

**Fix:** Add `alter table public.rate_limits enable row level security;` immediately after line 19,
with no policies (the revoke plus RLS-off-for-all-roles is then double-locked and the
`SECURITY DEFINER` function is unaffected).

---

## LOW — Android `allowBackup` is unset, so it defaults to `true`

**Location:** `android/app/src/main/AndroidManifest.xml:15-18`

**Issue:** The `<application>` element declares `label`, `name` and `icon` only. There is no
`android:allowBackup="false"` and no `android:dataExtractionRules` / `android:fullBackupContent`, so
Android Auto Backup is on. The app's genuinely sensitive stores are safe by construction — the session
and PKCE verifier (`supabase_secure_storage.dart:19-133`), the address book
(`local_address_repository.dart:15-22`) and the order snapshots
(`storefront_persistence.dart:46-50`) all sit behind `FlutterSecureStore`, whose key lives in the
Android Keystore and is not backed up (`secure_store.dart:28-45`), so a restored copy is undecryptable.
What *is* backed up is the plaintext `SharedPreferences` set: cart lines, wishlist ids, recently-viewed
ids, recent searches, the checkout idempotency key, notification prefs, and the `app_lock_enabled_v1`
flag (`biometric_service.dart:64-75`).

**Impact:** Low. No credentials or PII are recoverable from the backup; the worst case is that a
restored device shows a previous user's cart/wishlist and search history. It is reported because the
project has an explicit at-rest PII programme and this is the one store outside it.

**Fix:** Declare the intent explicitly in `android/app/src/main/AndroidManifest.xml:15`:

```xml
<application
      android:label="albatal_store"
      android:name="${applicationName}"
      android:icon="@mipmap/ic_launcher"
      android:allowBackup="false"
      android:fullBackupContent="false"
      android:dataExtractionRules="@xml/data_extraction_rules">
```

with `android/app/src/main/res/xml/data_extraction_rules.xml` excluding `sharedpref` for both
`cloud-backup` and `device-transfer`. `test/platform/platform_config_test.dart` already guards this
manifest — extend it to assert `allowBackup="false"` so the setting cannot regress.

---

## LOW — The live release keystore still sits inside the repository tree

**Location:** `android/app/release-key.jks` (untracked; matched by `.gitignore`)

**Issue:** Residual R6 is only half closed. The two duplicate copies that used to sit in the repo root
were moved out, but the **live** signing keystore — the one `key.properties` resolves to via Gradle
`file()` — remains at `android/app/release-key.jks` inside the working tree. It is not tracked
(`git ls-files` returns nothing for `*.jks`, `*.keystore`, `key.properties`), so there is no git leak.

**Impact:** Filesystem-only exposure: any process, backup agent, or archive that sweeps the project
directory (a zip of the repo, a cloud-synced folder, a shared VM image) picks up the key that signs
production APKs. Signing-key compromise allows an attacker to ship a malicious update accepted by
installed clients.

**Fix:** Move the keystore outside the repository (e.g. `%USERPROFILE%\.albatal\release-key.jks`) and
point at it with an absolute path or an environment variable in `key.properties`
(`storeFile=${ALBATAL_KEYSTORE}`), keeping the file out of any synced folder. Rotate only if the file
has ever left the machine.

---

## LOW — `SECURITY DEFINER` `search_path` hardening is inconsistent (`''` in 060, `public` in 053/056/061)

**Location:** `supabase/migrations/060_rate_limits.sql:37`, `supabase/migrations/053_analytics_events.sql:31,40`, `supabase/migrations/056_coupons.sql:51`, `supabase/migrations/061_admin_profiles_read.sql:34`

**Issue:** Every `SECURITY DEFINER` function in the recent set does pin `search_path`, which is the
important part. But two styles coexist: `060` uses the strongest form
(`set search_path = ''` with fully-qualified `public.` references inside the body), while `053`, `056`
and `061` use `set search_path = public` (`053:31`, `053:40`, `056:51`, `061:34`); `033`'s
`assert_admin()` uses `search_path=public,pg_temp` (`033_admin_catalog_rpcs.sql:15`).

**Impact:** Low and conditional. `search_path = public` is only exploitable if an attacker can create
objects in the `public` schema; Supabase revokes `CREATE` on `public` from `anon`/`authenticated` by
default, and no migration in this repository grants it back (verified: no
`GRANT CREATE ON SCHEMA public` anywhere). So this is hygiene, not a live path.

**Fix:** Standardise new functions on the `060` form — `set search_path = ''` plus schema-qualified
references in the body — and convert `is_current_user_admin()` (`061:30-41`) and `validate_coupon()`
(`056:45-58`) at the next touch. Cheap, and it removes the dependency on the schema-grant default
holding forever.

---

## LOW — `app_config` is world-readable, so any future sensitive key placed there leaks immediately

**Location:** `supabase/migrations/054_app_config.sql:16-23`

**Issue:** `CREATE POLICY app_config_read ON public.app_config FOR SELECT USING (true);` makes the
whole key/value table readable by every caller, including `anon`. Today the seeded keys are
`maintenance_mode` and `min_supported_version` (`054:26-28`) and the client reads only those
(`remote_config_service.dart:26,69-70`) — genuinely non-sensitive. The `FOR ALL` admin write policy
(19-23) correctly falls back to its `USING` expression for `WITH CHECK`, so writes are admin-gated.

**Impact:** None today. The risk is that a generic "remote config" table is exactly where someone
later puts a feature flag with an embedded webhook URL or an internal hostname; `USING (true)` means
that value is public the moment it is inserted, with no review step in between.

**Fix:** Add a comment constraint at the table itself and a guard for the future, either by adding
`check (key !~* '(secret|token|key|password|webhook)')` to the table or by narrowing the read policy to
the known-public key allowlist:

```sql
DROP POLICY app_config_read ON public.app_config;
CREATE POLICY app_config_read ON public.app_config
  FOR SELECT USING (key IN ('maintenance_mode', 'min_supported_version'));
```

---

## What's done well

- **Paymob money path is server-authoritative and the webhook is properly authenticated.** The client
  sends only `order_id` (`paymob_payment_service.dart:45-52`); the amount is read under the order lock
  from the atomic claim RPC (`paymob-initiate/index.ts:225-311`) and the client-supplied
  `amount_cents` is ignored entirely. The callback verifies HMAC-SHA512 over the documented field list
  in the documented order with a constant-time compare
  (`paymob-callback/hmac.ts:65-99,134-169`) and fails **closed** with a 503 when the secret is absent
  (`paymob-callback/index.ts:101-103`), with a rate limit applied *before* the body parse
  (`index.ts:76-86`). Nothing in the WebView is trusted: success is observed only through the
  `payments` table watch, and navigation is restricted to three exact Paymob hosts with no suffix
  matching (`paymob_url_guard.dart:28-46`).
- **Order creation and payment rows are unreachable from the client.** `orders` has
  `WITH CHECK (false)` on INSERT (`003_auth_profiles_and_hardening.sql:98-101`) and admin-only UPDATE
  (`003:43-51`), so a client cannot create or flip an order's status; direct `payments` INSERT was
  deliberately re-closed (`028_reclose_payments_insert_policy.sql:18-22`). Privilege escalation is
  closed on both self-write paths: `is_admin` on INSERT and UPDATE
  (`046_membership_tier.sql:37-58`, `029_drop_profiles_update_own.sql:24-33`) and `membership_tier`,
  which is also server-only via `admin_set_membership_tier` gated by `assert_admin()`
  (`046:61-84`).
- **PII at rest is in hardware-backed storage, and log/Sentry hygiene is real rather than claimed.**
  Session, PKCE verifier, address book and order snapshots all go through `FlutterSecureStore` with
  `first_unlock_this_device` on iOS and Keystore AES-GCM on Android (`secure_store.dart:28-45`), each
  with a one-time cleartext→secure migration that removes the prefs copy
  (`supabase_secure_storage.dart:29-45`, `local_address_repository.dart:106-114`,
  `storefront_persistence.dart:170-178`). Sentry sets `sendDefaultPii = false` and
  `attachScreenshot = false` with a `beforeSend` scrubber that strips cookies/query/fragment, reduces
  the user to an id, and runs email/phone regexes over extras, contexts, breadcrumbs and request data
  (`sentry_crash_reporting_service.dart:41-44,104-219`, `logger.dart:116-144`). No log or `debugPrint`
  call site interpolates an email, phone, token or password (verified by grep across `lib/`).
- **The PostgREST `or`-tree in the new admin customer search is escaped against the classic filter
  injection.** The only place user text reaches an `or` tree is `fetchCustomers`
  (`supabase_admin_repository.dart:710`), and the term crosses both parsers safely: the LIKE stage
  neutralises `\`, `%`, `_`, and `_literalInOrTree` wraps the value in double quotes and
  backslash-escapes embedded quotes so a comma or parenthesis cannot become structure
  (`supabase_admin_repository.dart:193-245`). The keyset cursor is a UTC ISO-8601 timestamp whose
  alphabet cannot contain a structural character (`262-284`).
- **The new orders CSV export is formula-injection-safe.** Every cell passes `_formulaGuard` before
  quoting, prefixing values that start with `=`, `+`, `-`, `@`, TAB or CR with a single quote
  (`orders_csv_exporter.dart:37-50`), so a customer name cannot become a live spreadsheet formula.
  Upload paths are likewise hardened: traversal is rejected and filenames are reduced to their last
  segment with a fresh UUID prefix (`storage_service.dart:36-43,184-199`), and the InstaPay proof
  bucket is private with owner-scoped object policies keyed on
  `(storage.foldername(name))[1] = auth.uid()::text`
  (`041_instapay_payment_method.sql:179-205`), with an extension allowlist, a 5 MB cap and a
  per-payment proof count cap in the function (`instapay-submit-proof/index.ts:36,100-124,149-158`).
- **No privileged secret is present in the tracked tree.** A sweep of every tracked file for
  `service_role` / `sb_secret_` / `sk_live` / `paymob…api_key` / private-key headers returns only
  prose and variable-name references in docs and code — no key material; a JWT-shaped-token grep
  across tracked files returns nothing. `service_role` is read only from `Deno.env` in the Edge
  Functions, the deployed functions that need it fail closed without it
  (`_shared/secrets.ts:69-85`), and the helper scripts that need it read it from the environment
  (`scripts/seed_demo_staging.mjs:18-21`). The tracked config templates are placeholder-shaped by
  length (29 / 32 / 34 chars) with the real values confined to gitignored `.local.json` files.

---

SCORE: 8.5/10 — The payment boundary, RLS privilege model, secret handling and PII-at-rest story are genuinely strong and I found no privileged credential, no client-side amount control, and no path by which a customer can create or mutate an order or payment directly; the HMAC-verified, fail-closed callback and the escaped PostgREST filter deserve specific credit. The deduction is concentrated in the newest work and in one honest evidence gap: the coupons route ships a client that sends a server parameter no migration implements (a live checkout-breaker and a discount that is advertised but never applied), `validate_coupon` is an unthrottled `anon` oracle for live promo codes, a server-driven sign-out leaves the address book and order PII on the device, and the RLS posture of the two externally-created tables (`notifications`, which holds customer emails, and `analytics_events`, whose 053 policy is inert without an `ENABLE ROW LEVEL SECURITY` that exists nowhere in the repo) cannot be proven from the tree and must be closed with a read-only DB check before it can be scored as controlled.
