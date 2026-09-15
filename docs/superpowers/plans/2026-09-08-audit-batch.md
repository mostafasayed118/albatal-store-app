# Audit Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all confirmed findings from the 7.5/10 quality audit in one worktree and one draft PR, sliced §1→§6 with batch gates.

**Architecture:** Keep all public contracts (`PaymentFailed(message, code)`, `PaymentState` fields, repository method names that survive) unchanged; move user copy to `context.l10n` via code-mapping, dedupe terminal emission behind one helper, split cubit internals without touching state shape, shrink dead APIs, centralize address JSON in one codec, gate 1Hz ticks behind `buildWhen`/selector, bound catalog queries. One branch, sequential revertable commits.

**Tech Stack:** Flutter 3.x, Dart 3.x, bloc/flutter_bloc, equatable, get_it, go_router, supabase_flutter, intl, flutter_test/bloc_test/mocktail.

**Spec:** `docs/superpowers/specs/2026-09-08-audit-batch-design.md`

## Global Constraints

- Work in worktree `.trees/audit-batch`, branch `fix/audit-batch` from current `master` tip; never edit `master` directly.
- Auto-fix code only in `lib/`; `supabase/` SQL ships as review-gated proposal only, never applied by the worker.
- Do not modify `pubspec.yaml`, `pubspec.lock`, `.github/workflows/`, `analysis_options.yaml` without separate explicit approval.
- Do not change `PaymentState`/`CatalogState`/`OrdersState` public field lists; additive private helpers and ctor-defaulted params only.
- Do not add dependencies.
- Every slice: run `flutter analyze` BEFORE `flutter test`; then `dart format` touched files; then `git status --short` + `git diff --check` secret sweep (no `.env`, keys, tokens, keystores).
- TDD: failing test first for every logic change; at most 3 attempts per item then escalate and log to `loop-ledger.json`.
- Draft PR first; no push/merge/ready without explicit owner call; verifier sub-agent required at batch end with evidence in `STATE.md`.

---

## File map

- `lib/features/payments/data/paymob_payment_service.dart` — add logging, `_emitTerminal`, keep codes.
- `lib/features/payments/presentation/payment_error_mapper.dart` (new) — pure `code → l10n` with fallback.
- `lib/features/payments/presentation/cubit/payment_cubit.dart` — split internals, `timerFactory`, code emits.
- `lib/features/payments/presentation/pages/payment_method_page.dart`, `paymob_checkout_page.dart`, `instapay_instructions_page.dart` — map codes to l10n.
- `l10n/app_en.arb`, `l10n/app_ar.arb` (+ regenerate `lib/generated/`) — payment/auth/checkout keys only.
- `lib/features/storefront/presentation/cubit/orders_cubit.dart`, `lib/features/storefront/domain/repositories/orders_repository.dart`, `lib/features/storefront/data/local_orders_repository.dart`, `lib/features/storefront/data/supabase_orders_repository.dart`, `lib/features/storefront/data/storefront_persistence.dart` — read-only shrink.
- `lib/features/admin/domain/repositories/admin_repository.dart`, `lib/features/admin/data/supabase_admin_repository.dart`, `lib/features/admin/data/admin_mappers.dart` — delete flash duplication.
- `lib/features/storefront/presentation/pages/checkout_page.dart` — split cards, remove config import, map errors.
- `lib/core/data/address_codec.dart` (new) — single address JSON codec.
- `lib/features/addresses/data/local_address_repository.dart`, `lib/features/storefront/data/storefront_persistence.dart`, `lib/features/storefront/presentation/cubit/checkout_cubit.dart` — delegate to codec.
- `lib/features/storefront/data/supabase_catalog_repository.dart` — one select const + bounded limit.
- `lib/features/storefront/presentation/cubit/catalog_cubit.dart`, `lib/features/storefront/presentation/cubit/flash_sale_ticker.dart`, `lib/features/storefront/presentation/pages/home_page.dart` — cubit-owned poll/ticker, `buildWhen`, selector, memoized label.
- `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/auth/presentation/pages/sign_up_page.dart` — 8-char rule, PII clear on sign-out/delete.
- `supabase/` policy tightening — proposal text inside PR body only, no file edits.
- Tests: `test/features/payments/data/paymob_payment_service_scrub_test.dart`, `test/payment_test.dart`, `test/orders_cubit_test.dart`, `test/features/storefront/data/supabase_orders_repository_test.dart`, `test/catalog_cubit_test.dart`, `test/catalog_perf_test.dart`, `test/features/storefront/data/supabase_catalog_repository_test.dart`, `test/checkout_page_test.dart`, `test/auth_cubit_test.dart`, plus 4 new test files named below.

---

### Task 1: Worktree + baseline

**Files:**
- Modify: none (environment only)
- Test: none (baseline record)

**Interfaces:**
- Consumes: `master` tip commit hash
- Produces: worktree path `.trees/audit-batch`, branch `fix/audit-batch`, baseline numbers

- [ ] **Step 1: Create worktree and branch from current master tip**

```bash
git fetch origin
git worktree add .trees/audit-batch -b fix/audit-batch origin/master
```

- [ ] **Step 2: Record baseline static analysis (must pass before touching code)**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Record baseline test suite**

Run: `flutter test`
Expected: all tests pass (record exact count, e.g. `547/547`, in the commit body and STATE.md evidence later)

- [ ] **Step 4: Empty commit marking baseline**

```bash
git -C .trees/audit-batch commit --allow-empty -m "chore(audit-batch): baseline at <tip-hash>, analyze clean, tests <n/n>"
```

---

### Task 2: Payment error-code mapper (pure, tested)

**Files:**
- Create: `lib/features/payments/presentation/payment_error_mapper.dart`
- Test: `test/features/payments/presentation/payment_error_mapper_test.dart`

**Interfaces:**
- Consumes: `PaymentFailed.code` (`String?`), `AppLocalizations` (has `paymentGenericFailure`, `paymentNotPending`, `paymentVerifyFailed`, `paymentTimeout`, `orderRefRequired`)
- Produces: `String paymentMessageForCode(AppLocalizations l10n, String? code, String fallback)` — returns `fallback` for unknown/null codes, never throws

- [ ] **Step 1: Write the failing test**

```dart
import 'package:al_batal_elite/features/payments/presentation/payment_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';

void main() {
  test('known codes map, unknown falls back', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(paymentMessageForCode(l10n, 'payment_not_pending', 'RAW'), isNot('RAW'));
    expect(paymentMessageForCode(l10n, 'no_such_code', 'RAW'), 'RAW');
    expect(paymentMessageForCode(l10n, null, 'RAW'), 'RAW');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter analyze`
Expected: `No issues found!` (new files parse)
Run: `flutter test test/features/payments/presentation/payment_error_mapper_test.dart`
Expected: FAIL with "payment_error_mapper.dart not found"

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';

String paymentMessageForCode(AppLocalizations l10n, String? code, String fallback) {
  return switch (code) {
    'payment_not_pending' => l10n.paymentNotPending,
    'payment_not_cod' => l10n.paymentNotPending,
    'order_ref_required' => l10n.orderRefRequired,
    'verify_failed' => l10n.paymentVerifyFailed,
    'verify_timeout' => l10n.paymentTimeout,
    'rpc_timeout' => l10n.paymentTimeout,
    'network_error' => l10n.paymentGenericFailure,
    _ => fallback,
  };
}
```

- [ ] **Step 4: Add the 5 EN/AR keys, regenerate, run tests**

Add to `l10n/app_en.arb` (and matching `l10n/app_ar.arb` with native-reviewed Arabic):
`paymentGenericFailure`, `paymentNotPending`, `paymentVerifyFailed`, `paymentTimeout`, `orderRefRequired`. Regenerate localizations, then run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/payments/presentation/payment_error_mapper_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/presentation/payment_error_mapper.dart test/features/payments/presentation/payment_error_mapper_test.dart l10n/app_en.arb l10n/app_ar.arb lib/generated/
git commit -m "feat(payments): code-to-l10n error mapper with fallback"
```

---

### Task 3: Payment service — logging + single terminal helper

**Files:**
- Modify: `lib/features/payments/data/paymob_payment_service.dart:142,193,342-456`
- Test: `test/features/payments/data/paymob_payment_service_scrub_test.dart`

**Interfaces:**
- Consumes: `Log.e(String, {Object? error, LogCategory category})`, `PaymentSuccess`, `PaymentFailed`
- Produces: private `void _emitTerminal(StreamController<PaymentResult> c, PaymentResult r, {required Completer<void> done, required Timer? Function() timer})` — exactly-once add, cancels fallback timer, completes `done`

- [ ] **Step 1: Write failing parity test (realtime-success equals poll-success)**

```dart
test('realtime and poll terminal paths emit identical results', () async {
  // Drive watchPaymentStatus with a fake client whose realtime never fires,
  // then whose poll returns status=success + transaction_id=TX1.
  // Expect single PaymentSuccess(transactionId: TX1); second poll emits nothing.
  expect(emissions.length, 1);
  expect((emissions.single as PaymentSuccess).transactionId, 'TX1');
});
```

- [ ] **Step 2: Run to verify it fails (helper missing)**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/payments/data/paymob_payment_service_scrub_test.dart`
Expected: FAIL (duplicate branches still inline; parity test has no hook)

- [ ] **Step 3: Minimal implementation — logging + helper, no behavior change**

```dart
} catch (e) {
  Log.e('COD confirm failed', error: e, category: LogCategory.payment);
  return const PaymentFailed(message: 'Failed to confirm payment. Please try again.', code: 'network_error');
}
```

```dart
void _emitTerminal(
  StreamController<PaymentResult> controller,
  PaymentResult result, {
  required Completer<void> done,
  required Timer? Function() takeTimer,
  required bool Function() hasEmitted,
  required void Function() markEmitted,
}) {
  if (done.isCompleted || controller.isClosed || hasEmitted()) return;
  markEmitted();
  if (!done.isCompleted) done.complete();
  takeTimer()?.cancel();
  controller.add(result);
}
```

Replace both inline success/failed blocks (realtime callback and 45s poll) with `_emitTerminal` calls carrying the same `PaymentSuccess(transactionId: ...)` / `PaymentFailed(message: 'Payment was declined by the gateway', code: 'gateway_declined')` payloads.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/payments/data/paymob_payment_service_scrub_test.dart test/payment_security_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/data/paymob_payment_service.dart test/features/payments/data/paymob_payment_service_scrub_test.dart
git commit -m "refactor(payments): structured logging plus single terminal emitter"
```

---

### Task 4: PaymentCubit split + timer factory + code emits

**Files:**
- Modify: `lib/features/payments/presentation/cubit/payment_cubit.dart:128-239,302-366`
- Modify: `lib/features/payments/presentation/pages/payment_method_page.dart`, `paymob_checkout_page.dart`, `instapay_instructions_page.dart` (map via Task 2 helper only)
- Test: `test/payment_test.dart`

**Interfaces:**
- Consumes: `PaymentService` methods, `paymentMessageForCode` from Task 2, `Timer Function(Duration, void Function()) timerFactory`
- Produces: ctor `PaymentCubit(this._paymentService, {Duration watchTimeout = _defaultWatchTimeout, Timer Function(Duration, void Function()) timerFactory = Timer})`; private `Future<void> _processCod()`, `_processInstapay()`, `_processCard({required String customerEmail})`; `errorMessage` carries codes `order_ref_required`/`verify_failed`/`verify_timeout`

- [ ] **Step 1: Write failing test for factory-driven timeout (no test-only API)**

```dart
test('watch timeout fires via injected timer factory', () async {
  var fired = false;
  Timer fakeFactory(Duration d, void Function() cb) {
    fired = true;
    cb();
    return Timer(const Duration(milliseconds: 1), () {});
  }
  final cubit = PaymentCubit(service, timerFactory: fakeFactory);
  cubit.initPayment(amount: Money(100), orderId: 'O1');
  await cubit.startWatching('O1');
  expect(fired, isTrue);
  await cubit.close();
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/payment_test.dart --plain-name "watch timeout fires via injected timer factory"`
Expected: FAIL (no `timerFactory` param)

- [ ] **Step 3: Minimal implementation**

```dart
PaymentCubit(this._paymentService,
    {Duration watchTimeout = _defaultWatchTimeout,
    Timer Function(Duration, void Function()) timerFactory = Timer})
    : _watchTimeout = watchTimeout,
      _timerFactory = timerFactory,
      super(const PaymentState());
```

Split bodies verbatim into the three private methods; `processPayment` keeps:

```dart
if (state.selectedMethod == null) return;
if (state.status == PaymentStatus.processing) return;
if (state.selectedMethod == PaymentMethod.cashOnDelivery) return _processCod();
if (state.selectedMethod == PaymentMethod.instapay) return _processInstapay();
return _processCard(customerEmail: customerEmail);
```

Replace EN emits with codes: `'A valid order reference is required...'` → `code: order_ref_required` path (emit `errorMessage: 'order_ref_required'`), onError → `'verify_failed'`, timeout → `'verify_timeout'`. Delete `fireWatchTimeoutForTest`; use `_timerFactory(_watchTimeout, _handleWatchTimeout)`. Pages render `paymentMessageForCode(l10n, state.errorMessage, state.errorMessage ?? '')` — note: `errorMessage` now carries either a code or a legacy fallback string.

- [ ] **Step 4: Migrate old timeout tests to the factory, verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/payment_test.dart test/payment_checkout_flow_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/presentation/cubit/payment_cubit.dart lib/features/payments/presentation/pages/ test/payment_test.dart
git commit -m "refactor(payments): split processPayment, injectable watch timer, code emits"
```

---

### Task 5: Dead code + admin boundary shrink

**Files:**
- Modify: `lib/features/storefront/presentation/cubit/orders_cubit.dart:130-181` (delete), `lib/features/storefront/domain/repositories/orders_repository.dart:11` (delete `writeOrders`), `lib/features/storefront/data/local_orders_repository.dart:24-27`, `lib/features/storefront/data/supabase_orders_repository.dart:66-72`, `lib/features/storefront/data/storefront_persistence.dart:99-110` (delete write path; keep `readOrders`)
- Modify: `lib/features/admin/domain/repositories/admin_repository.dart:83`, `lib/features/admin/data/supabase_admin_repository.dart:231-240`, `lib/features/admin/data/admin_mappers.dart:148-155` (delete flash duplication)
- Test: `test/orders_cubit_test.dart`, `test/features/storefront/data/supabase_orders_repository_test.dart`, `test/admin_catalog_repository_test.dart` (delete retired cases)

**Interfaces:**
- Consumes: grep proof of zero callers
- Produces: `OrdersRepository { Future<Result<List<Order>>> readOrders(); }` only; no `AdminRepository.getActiveFlashSales`

- [ ] **Step 1: Grep-guard (do not delete if a caller exists)**

Run: `grep -rn "\.place(\|\.reconcile(\|getActiveFlashSales" lib/`
Expected: only definitions + the `payment_method_page.dart:20` "does NOT call place" comment + catalog typed impl. If a real admin-page caller of `getActiveFlashSales` appears, stop and keep + type it instead.

- [ ] **Step 2: Delete + run affected tests to see red**

Run: `flutter analyze`
Expected: errors listing every stale reference (fakes, tests) — fix them all in this task (fakes live in `test/`).

- [ ] **Step 3: Minimal fix — delete bodies, shrink interfaces, update fakes**

Delete `place()`/`reconcile()` and all `writeOrders` overrides; delete admin flash method + mapper. Update test fakes to the read-only interface; delete retired test cases (do not disable).

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/orders_cubit_test.dart test/features/storefront/data/supabase_orders_repository_test.dart test/admin_catalog_repository_test.dart test/catalog_flash_sale_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/storefront/ lib/features/admin/ test/orders_cubit_test.dart test/features/storefront/data/supabase_orders_repository_test.dart test/admin_catalog_repository_test.dart
git commit -m "refactor(storefront,admin): drop dead order writes and admin flash duplication"
```

---

### Task 6: Router extra + config injection — DROPPED per controller ruling (2026-09-08, no code change)

Implementer NEEDS_CONTEXT (no code changed, tree untouched) verified against source: (a) the
`extra`-passed cubit on `/instapay-instructions` is load-bearing single-watch design (PR #38),
and `/payment-method` already DI-builds — the change is a no-op at best, duplicate watchers at
worst; (b) no existing service exposes session email (`AuthState`/`Profile` carry none), so
"inject via existing service" needs new auth plumbing the plan forbids. Both audit items
REJECTED (see spec §4 note). No files, no tests, no commit for this task.

**Files:** (none — dropped)
- Modify: `lib/features/storefront/presentation/pages/checkout_page.dart:8` (remove `supabase_config.dart` import, inject via existing service), `lib/shared/routing/app_router.dart:139` (construct `PaymentCubit` in destination via GetIt instead of `extra`)
- Test: `test/checkout_page_test.dart`

**Interfaces:**
- Consumes: `GetIt<PaymentService>`, existing `PaymentCubit` ctor from Task 4
- Produces: no `state.extra` cubit passing; checkout page takes only serializable args

- [ ] **Step 1: Failing test — destination builds cubit from DI**

```dart
testWidgets('payment route builds without extra cubit', (t) async {
  // Push payment route with orderId only; expect PaymentMethodPage finds PaymentCubit.
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/checkout_page_test.dart`
Expected: FAIL (route still expects `extra`)

- [ ] **Step 3: Minimal change; mark router hunk `HUMAN-REVIEW` in PR description**

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/checkout_page_test.dart test/payment_navigation_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/storefront/presentation/pages/checkout_page.dart lib/shared/routing/app_router.dart test/checkout_page_test.dart
git commit -m "refactor(routing): DI-owned PaymentCubit, no config import in page"
```

---

### Task 7: AddressCodec + call-site delegation

**Files:**
- Create: `lib/core/data/address_codec.dart`
- Modify: `lib/features/addresses/data/local_address_repository.dart:21-47`, `lib/features/storefront/data/storefront_persistence.dart:129-179`, `lib/features/storefront/presentation/cubit/checkout_cubit.dart:196-204`
- Test: `test/core/data/address_codec_test.dart` (new)

**Interfaces:**
- Consumes: addresses-feature `Address` (`id`, `recipient`, `line`, `city`, `country`, `isDefault`)
- Produces: `abstract final class AddressCodec { static Map<String, dynamic> toJson(Address a); static Address fromJson(Map<String, dynamic> j); }` — output byte-identical to the current hand-built JSON (`id/recipient/line/city/country/isDefault`); worker verifies the other two call-sites use the same keys and unifies them in-task without changing stored bytes

- [ ] **Step 1: Write round-trip test from the real persisted shape**

```dart
test('codec round-trips the legacy persisted shape', () {
  const legacy = {'id': 'a1', 'recipient': 'Layla', 'line': '1 Nile St', 'city': 'Cairo', 'country': 'EG', 'isDefault': true};
  final addr = AddressCodec.fromJson(legacy);
  expect(AddressCodec.toJson(addr), legacy);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/core/data/address_codec_test.dart`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement codec by copying one legacy builder verbatim, delegate all three sites**

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/core/data/address_codec_test.dart test/address_form_test.dart test/checkout_address_test.dart test/checkout_cubit_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/address_codec.dart lib/features/addresses/data/local_address_repository.dart lib/features/storefront/data/storefront_persistence.dart lib/features/storefront/presentation/cubit/checkout_cubit.dart test/core/data/address_codec_test.dart
git commit -m "refactor(core): single AddressCodec for snapshots"
```

---

### Task 8: Catalog const + checkout split + home poll/label + l10n + dartdoc

**Files:**
- Modify: `lib/features/storefront/data/supabase_catalog_repository.dart:85-91,154-160` (one `static const _productSelect`), `lib/features/storefront/presentation/pages/checkout_page.dart:44-269` (extract `_TotalsCard`, `_AddressCard`), `lib/features/storefront/presentation/pages/home_page.dart:53-56,125-133`, `lib/features/storefront/presentation/cubit/catalog_cubit.dart` (own 60s poll + memoized `discountLabel`), `l10n/app_en.arb`, `l10n/app_ar.arb`, 2 bare domain repository files (dartdoc only)

**Interfaces:**
- Consumes: `CatalogState.flashSales`, `MembershipTier`, `intl DateFormat`
- Produces: `String CatalogState.discountLabel` (memoized, `'-15%'` fallback); `CatalogCubit.loadFlashSales()` self-polling; checkout sub-widgets with identical pixels

- [ ] **Step 1: Failing test — discount label lives in state, not build**

```dart
test('discount label derives from first flash sale', () {
  final s = CatalogState(flashSales: [FlashSale(productId: 'p', discountPct: 20)]);
  expect(s.discountLabel, '-20%');
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/catalog_cubit_test.dart`
Expected: FAIL (no `discountLabel`)

- [ ] **Step 3: Implement const + memo + split + poll move + row-popup keys**

Move `Timer.periodic(60s)` from `HomePage.initState` into `CatalogCubit` (cancel in `close`); `HomePage` calls `loadFlashSales()` once. Re-apply `setAsDefault/edit/delete` EN/AR keys (from unmerged branch) to the addresses popup; map `checkout_page` errors via Task 2 pattern; replace admin `'standard'/'premium'/'Unknown'` with `MembershipTier` + l10n.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/catalog_cubit_test.dart test/checkout_page_test.dart test/catalog_perf_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/storefront/ l10n/ lib/generated/ test/
git commit -m "refactor(storefront): memoize discount label, cubit-owned poll, checkout split, l10n"
```

---

### Task 9: Security — password rule, PII clear, log scrub

**Files:**
- Modify: `lib/features/auth/presentation/pages/sign_up_page.dart:92-93` (8-char minimum), `lib/features/auth/presentation/cubit/auth_cubit.dart:172-178` (clear address/order snapshots on sign-out + delete success), `lib/features/storefront/data/supabase_orders_repository.dart:35,56` (drop `userId` log / `kDebugMode` gate)
- Test: `test/auth_cubit_test.dart`, `test/auth_test.dart`

**Interfaces:**
- Consumes: existing `signOut()`, `deleteAccount()` success paths, `storefront_persistence.clearOrders()`, address repo `clear()`
- Produces: signed-out/deleted device holds no address/order snapshots; validator rejects <8 chars

- [ ] **Step 1: Failing tests**

```dart
test('signOut clears cached addresses and orders', () async {
  await cubit.signOut();
  verify(() => addressRepo.clear()).called(1);
  verify(() => ordersCache.clear()).called(1);
});
test('password validator rejects 6 chars', () {
  expect(passwordValidator('123456'), isNotNull);
  expect(passwordValidator('12345678'), isNull);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/auth_cubit_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement validator + clears + log gate**

```dart
if (!kDebugMode) {} else Log.w('readOrders: got ${rows.length} rows');
```

Delete the `userId=$userId` line entirely. Record "enable Supabase leaked-password protection" as a deploy checklist line in the PR body (human step, no code).

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/auth_cubit_test.dart test/auth_test.dart test/features/storefront/data/supabase_orders_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/ lib/features/storefront/data/supabase_orders_repository.dart test/auth_cubit_test.dart test/auth_test.dart
git commit -m "fix(security): stronger password rule, PII cleared on sign-out, no userId logs"
```

---

### Task 10: Storage policy proposal (docs-only, no apply)

**Files:**
- Modify: none in `supabase/`. PR body only.

**Interfaces:**
- Consumes: `instapay-submit-proof` size+ext allowlist (`png/jpg/jpeg/webp`)
- Produces: PR-body SQL proposal tightening the `instapay-proofs` policy to owner-path + matching ext/size, marked `HUMAN-REVIEW — DO NOT APPLY HERE`

- [ ] **Step 1: Draft proposal text in PR body, zero repo edits**

- [ ] **Step 2: Verify clean tree**

Run: `git status --short`
Expected: no `supabase/` entries

- [ ] **Step 3: No commit (body-only item; note it in the Task 12 PR)**

---

### Task 11: Performance — buildWhen, selector, ticker gating, bounded query

**Files:**
- Modify: `lib/features/storefront/presentation/pages/home_page.dart:108` (`buildWhen`), flash card countdown (`BlocSelector`), `lib/features/storefront/presentation/cubit/catalog_cubit.dart:214,362-367`, `lib/features/storefront/presentation/cubit/flash_sale_ticker.dart`, `lib/features/storefront/data/supabase_catalog_repository.dart` (`.limit(100)` + `.order()`)
- Test: `test/catalog_perf_test.dart`, `test/features/storefront/data/supabase_catalog_repository_test.dart`

**Interfaces:**
- Consumes: `CatalogStatus`, `flashSales`, `flashRemaining`, `filters`
- Produces: outer builder skips `flashRemaining`-only emits; ticker emits only when sales non-empty; repo `fetchProducts({int limit = 100})`

- [ ] **Step 1: Failing tests**

```dart
test('ticker emits nothing when flash sales empty', () async {
  final cubit = CatalogCubit(repoWithNoSales);
  await cubit.loadFlashSales();
  expect(cubit.state.flashRemaining, isNull);
  await cubit.close();
});
test('bounded query requests a limit', () async {
  await repo.fetchProducts();
  verify(() => query.limit(100)).called(1);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/catalog_perf_test.dart test/features/storefront/data/supabase_catalog_repository_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `buildWhen`, selector, gating, limit**

```dart
BlocBuilder<CatalogCubit, CatalogState>(
  buildWhen: (p, c) =>
      p.status != c.status ||
      p.visible != c.visible ||
      p.flashSales != c.flashSales ||
      p.filters != c.filters ||
      p.featuredProducts != c.featuredProducts,
  builder: (context, state) { ... },
)
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/catalog_perf_test.dart test/catalog_cubit_test.dart test/features/storefront/data/supabase_catalog_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/storefront/ test/catalog_perf_test.dart test/features/storefront/data/supabase_catalog_repository_test.dart
git commit -m "perf(storefront): gate 1Hz ticks, bound catalog load"
```

---

### Task 12: Batch gates + draft PR + verifier + STATE.md

**Files:**
- Modify: `STATE.md` (append run log with test evidence)

**Interfaces:**
- Consumes: all Task 1–11 commits
- Produces: green CI draft PR, verifier verdict, updated STATE.md

- [ ] **Step 1: Full static + test + format + sweep**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test`
Expected: all pass (record count)
Run: `dart format --set-exit-if-changed lib test`
Expected: clean (or commit formatting)
Run: `git status --short` + `git diff --check`
Expected: only intended files, no secrets

- [ ] **Step 2: Push branch and open draft PR (only on explicit owner call)**

```bash
git push -u origin fix/audit-batch
gh pr create --draft --base master --head fix/audit-batch --title "fix: audit batch (l10n boundary, dead code, PII, perf)" --body "Slices §1-§5 + §7-§11 (Task 6 dropped per ruling, Task 10 proposal-only). HUMAN-REVIEW: storage policy proposal, migration lineage 041/046. Verifier pending."
```

- [ ] **Step 3: Dispatch verifier sub-agent, record evidence in STATE.md, await CI**

Do not mark ready/merge without explicit owner calls. Offer the INSTRUCTIONS.md learning walkthrough after merge.
