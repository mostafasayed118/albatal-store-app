# Audit Batch — Design Spec (single worktree, one draft PR)

Date: 2026-09-08 | Base: `master@bc4a9b4` (rebase to tip at implementation time)
Mode: L2 full + denylist overrides (payments/, auth/, supabase/ proposal-only where noted)
Delivery: Approach A — one branch `fix/audit-batch`, one worktree, slices §1→§6 as
separate revertable commits, one draft PR, verifier once, no push/merge without explicit owner call.

## 0. Report verdict (verified 2026-09-08)

Score 7.5/10 accepted as plausible. Prior L1 was 6.6; P1 (checkout scrub), P3 (typed
FlashSale), P4 (memoize/debounce/limit-50/ticker-adopt), P5 (safe-parse/dialog mixin) are
merged — those items are closed and must not be re-done.

Confirmed-open (spot-verified in lib/): payment EN strings in data layer with `code`
already present; `watchPaymentStatus` terminal-emit duplication; 2 silent `catch(e)`;
`processPayment` ~111 lines + cubit EN strings + `fireWatchTimeoutForTest`; dead
`place()/reconcile()` (zero lib callers; page comment confirms); admin
`getActiveFlashSales` Map-leak duplication of catalog typed RPC; 60s page Timer + magic
`'-15%'` in build; `s.errorMessage!` raw; `Log.w(userId=)`; address JSON ×3; product
select ×2; 8-char password + PII-clear + storage-policy gaps; 1Hz `flashRemaining` in
props with no page consumer (legacy timer gone per P4 — mechanism is now the ticker);
unbounded catalog load.

## 1. Approach (approved)

Single worktree, sliced commits, one draft PR. Rejected: phased PRs (owner chose single
batch), direct-to-master (violates binding constraints). YAGNI: no new dependencies, no
arch redesign, no state-signature changes, smallest diff per finding.

## 2. §1 Payment data boundary — `payments/data/paymob_payment_service.dart`

Keep `PaymentFailed(message, code)` shape. Data returns precise `code` + generic EN
fallback; presentation maps `code → context.l10n`. New EN/AR keys only for payment codes.
Add `Log.e(category: payment)` to catches at :142,:193 (diagnostic-only, P1 scrub pattern).
Extract `_emitTerminal()` owning hasEmitted/completer/timer-cancel/add; realtime callback
and 45s poll both call it. No rename/split; extend dartdoc to declare COD/InstaPay/Card
ownership. Tests: scrub (no raw $e/URL in UI), helper parity (realtime ≡ poll output).

## 3. §2 PaymentCubit — `payments/presentation/cubit/payment_cubit.dart`

Extract `_processCod()/_processInstapay()/_processCard(customerEmail)`; `processPayment`
keeps null-method + double-entry guards only. No `PaymentState` field changes. Cubit emits
machine-readable codes in `errorMessage` (`order_ref_required`, `verify_failed`,
`verify_timeout`); pages map to l10n with generic-EN fallback. Replace
`fireWatchTimeoutForTest()` with injectable `timerFactory` ctor param (default `Timer`;
existing `watchTimeout` unchanged; GetIt untouched); migrate timeout tests to fake timer.
`_handleWatchTimeout` awaitingVerification-only behavior kept (InstaPay expiry is
server-owned). Tests: dispatch per provider, double-entry guard, timer-factory timeout,
code assertions.

## 4. §3 Dead code + admin boundary

Grep-guard each deletion at slice start; if a caller appears, keep + wire instead.
Delete `OrdersCubit.place()/reconcile()`; shrink `OrdersRepository` to read-only
(remove `writeOrders` from interface + local/supabase impls + fakes); `restore()` kept.
Delete admin `getActiveFlashSales` (interface + impl + `AdminMappers.flashSalesFromRows`);
catalog typed RPC is canonical. No `AdminRepository` split. `settings_page`
cross-feature imports documented as future.
Tests: retire place/reconcile + admin-flash tests; keep restore + catalog flash green.

**REJECTED on implementation evidence (2026-09-08, Task 6):** (a) re-creating
`PaymentCubit` in the destination via GetIt instead of router `extra` — the shared
cubit passed via `extra` is deliberate single-watch architecture (PR #38: one Realtime
subscription across payment-method → paymob/instapay pages); forking it per page risks
duplicate terminal handling for a Low-severity style nit. (b) removing `checkout_page`'s
`SupabaseConfig` import — `SupabaseConfig` IS the shared service layer and its
`currentUser?.email` read is the only session-email seam in the app (`AuthState`/`Profile`
carry no email); any replacement is new auth plumbing with zero behavior gain.

## 5. §4 Codec + UI/l10n

New `core/data/address_codec.dart` with byte-identical `toJson/fromJson`; 3 call-sites
(`local_address_repository`, `storefront_persistence`, `checkout_cubit`) delegate;
round-trip test pins output. One `const` product-select in `supabase_catalog_repository`.
Pages map `AppError.code`/payment codes → l10n; re-apply unmerged `fix/row-popup-l10n`
3 keys in-slice; `'standard'/'premium'` → `MembershipTier` enum + l10n; dates via `intl`
`DateFormat` + UI locale (PR #41 pattern). `checkout_page`: extract totals/address cards,
move provider creation out of `build`. `home_page`: poll moves to `CatalogCubit`
(cubit-owned Timer, cancel in `close`); discount label derived/memoized in
`CatalogState`. P5 dialog mixin already adopted — skip. Add dartdoc to the 2 bare domain
repos. Tests: codec round-trip, select-shape, l10n-fallback, split widget tests.

## 6. §5 Security/PII

`sign_up_page`: 8-char minimum + tests; no custom breach service — Supabase dashboard
leaked-password protection is a recorded human step. `AuthCubit.signOut` + `deleteAccount`
success clear address/order snapshots (extends cart/wishlist wipe); no new dep
(`flutter_secure_storage` = documented future). Drop `Log.w(userId=)` / gate debug-only.
Storage RLS tightening and any migration-lineage assert ship as review-gated SQL/proposal
in the PR, not auto-applied. Tests: sign-out-clears, delete-clears, validator, log-scrub.

## 7. §6 Performance

`CatalogCubit` owns `FlashSaleTicker` (no ticks when `flashSales` empty; cancel in
`close`). Outer home `BlocBuilder` gets `buildWhen` ignoring `flashRemaining`-only emits;
countdown (if rendered) uses `BlocSelector<flashRemaining>` inside the flash card.
P4 memo-adopt kept. Catalog initial load bounded (`.limit()` + deterministic `.order()`,
default 100, same shape; `.limit(50)` precedent); cursor pagination = follow-up.
TTL refetch stays cache-first. Tests: ticker start/stop, `buildWhen` predicate, bounded
query; cold-load row count noted in PR body.

## 8. §7 Verification & release (binding)

Order §1→§6. Per slice: `flutter analyze` then `flutter test`, `dart format` touched
files, secret sweep (`git status/diff`, no .env/keys), ≤3 attempts then escalate +
`loop-ledger.json`. Batch: full `flutter test` + `analyze` clean, whole-repo format
check, verifier sub-agent (L2+ required) with evidence in `STATE.md`. Draft PR first;
router/supabase/policy items marked human-review; CI green before ready; no push/merge
without explicit owner call. Post-merge: offer INSTRUCTIONS.md learning walkthrough.

## 9. Out of scope

`PaymobPaymentService` rename/split; `AdminRepository` split; settings cross-feature move;
secure-storage migration; cursor pagination; custom breach checker; 4th-provider support;
anything in `pubspec.yaml`, workflows, `analysis_options.yaml` without separate approval.
