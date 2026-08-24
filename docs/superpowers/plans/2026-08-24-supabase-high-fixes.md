# Supabase HIGH-Findings Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the two HIGH findings from the 2026-08-24 Supabase deep audit: (1) unsecured `state_transitions` audit table + PUBLIC-executable `audit_transition()`, (2) two admin pages querying Supabase directly from the presentation layer.

**Architecture:** One additive SQL migration locks the audit trail server-side (RLS + grant revocation, following the established 032 policy pattern since no `is_admin()` helper function exists). One Dart refactor routes the two pages through `AdminRepository`, matching the interface style already used by every other method (plain futures throwing naturally; pages keep their existing `catch` handling).

**Tech Stack:** PostgreSQL (Supabase migrations), Dart/Flutter, GetIt, flutter_test.

**Spec:** Audit findings HIGH-1 / HIGH-2 from the in-session deep audit dated 2026-08-24 (report delivered in chat; summarized inline in each task below).

## Global Constraints

- **L1 gate:** No source edits until the human enables L2. This plan is the review artifact; execution requires explicit approval (AGENTS.md Loop Mode).
- **Migration review:** `supabase/` changes require human sign-off — Task 1's SQL below IS the artifact for that review.
- **Worktree:** All code-changing work happens in a git worktree (AGENTS.md Safety).
- **Max 3 fix attempts per item**, then escalate (loop-constraints.md).
- **No `pubspec.yaml` changes.** No new dependencies.
- **Verification:** `flutter analyze` and `flutter test` must pass before any task is called done.
- **Style:** Conventional commits, matching repo history (`fix(supabase): …`, `refactor(admin): …`). No code comments beyond what mirrors existing file conventions.
- Migration numbering: next free number is **034** (023 does not exist; last is 033).

---

### Task 1: Migration 034 — Lock audit trail

**Files:**
- Create: `supabase/migrations/034_lock_audit_trail.sql`
- Create: `supabase/tests/test_034_lock_audit_trail.sql`

**Interfaces:**
- Consumes: `public.state_transitions` table (defined `025_race_safe_state_machine.sql:63-73`) and `public.audit_transition(p_entity_type TEXT, p_entity_id UUID, p_old_status TEXT, p_new_status TEXT, p_caller TEXT, p_reason TEXT, p_metadata JSONB DEFAULT '{}'::jsonb)` (`025_race_safe_state_machine.sql:89-112`). Both exist in the deployed schema.
- Produces: locked audit surface — clients can neither read nor write `state_transitions`; authenticated admins gain SELECT-only access; `audit_transition()` executable by nobody over PostgREST (internal SECURITY DEFINER callers run as the function owner and are unaffected by EXECUTE revokes).

**Why (from audit HIGH-1):** `state_transitions` shipped with no RLS and no policy; under Supabase default grants any client can read the forensic trail (Paymob txn IDs in `metadata`) and insert/update/delete rows. `audit_transition()` is SECURITY DEFINER with default PUBLIC execute, so forged audit rows were possible even ignoring the table. Fix: enable RLS + admin-only SELECT policy + tighten grants, and revoke EXECUTE from PUBLIC/anon/authenticated.

- [ ] **Step 1: Create the migration**

Create `supabase/migrations/034_lock_audit_trail.sql` with exactly:

```sql
-- ═══════════════════════════════════════════════════════════
-- Migration 034: lock state transitions audit trail
-- ═══════════════════════════════════════════════════════════
-- AUDIT-2026-08-24 HIGH-1:
--   * state_transitions had no RLS and no policies. Under Supabase
--     default grants, any client could read the full forensic trail
--     (incl. Paymob txn ids in metadata) and insert/update/delete rows.
--   * audit_transition() was SECURITY DEFINER with default PUBLIC
--     execute, allowing forged audit rows via PostgREST.
--
-- Fix:
--   1. Enable RLS; single admin-only SELECT policy (pattern from 032).
--   2. Grant-tighten the table: authenticated gets SELECT (filtered by
--      the policy); anon gets nothing. Writes stay service_role-only.
--   3. Revoke EXECUTE on audit_transition from PUBLIC/anon/authenticated.
--      Internal callers are SECURITY DEFINER functions running as the
--      owner, so they are unaffected by EXECUTE revokes.
-- Idempotent: safe to re-run.

-- ── 1. Table hardening ─────────────────────────────────────

ALTER TABLE public.state_transitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS state_transitions_select_admin
  ON public.state_transitions;

CREATE POLICY state_transitions_select_admin
  ON public.state_transitions
  FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);

REVOKE ALL ON public.state_transitions FROM anon;
REVOKE ALL ON public.state_transitions FROM authenticated;
GRANT SELECT ON public.state_transitions TO authenticated;
-- service_role bypasses RLS and retains its default grants: untouched.

-- ── 2. Helper function hardening ───────────────────────────

REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM anon;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM authenticated;
```

- [ ] **Step 2: Create the test**

Create `supabase/tests/test_034_lock_audit_trail.sql` with exactly (run against a fresh local stack):

```sql
-- ═══════════════════════════════════════════════════════════
-- Test: migration 034 — audit trail locked
-- Run AFTER `supabase db reset` against the local database.
-- Every check RAISEs 'FAIL: …' on violation; silence = pass.
-- ═══════════════════════════════════════════════════════════

-- 1. RLS is enabled on state_transitions.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class
           WHERE oid = 'public.state_transitions'::regclass) THEN
    RAISE EXCEPTION 'FAIL: state_transitions RLS not enabled';
  END IF;
END $$;

-- 2. Exactly one policy exists and it is the admin SELECT policy.
DO $$
DECLARE p_count INT; p_cmd TEXT; p_roles TEXT;
BEGIN
  SELECT COUNT(*), MIN(cmd), MIN(roles::text) INTO p_count, p_cmd, p_roles
    FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'state_transitions';
  IF p_count <> 1 OR p_cmd <> 'SELECT' OR p_roles <> '{authenticated}' THEN
    RAISE EXCEPTION 'FAIL: unexpected policies on state_transitions (% rows, cmd=%, roles=%)',
      p_count, p_cmd, p_roles;
  END IF;
END $$;

-- 3. Seed one row as owner, then verify anon sees ZERO rows (RLS deny).
INSERT INTO public.state_transitions (entity_type, entity_id, new_status)
VALUES ('order', '00000000-0000-0000-0000-000000000001', 'seeded');

BEGIN;
SET LOCAL ROLE anon;
DO $$
DECLARE n INT;
BEGIN
  SELECT COUNT(*) INTO n FROM public.state_transitions;
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL: anon read % rows from state_transitions', n;
  END IF;
END $$;
ROLLBACK;

-- 4. Anon INSERT is rejected (no grant + no policy => 42501).
BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.state_transitions (entity_type, entity_id, new_status)
    VALUES ('order', '00000000-0000-0000-0000-000000000002', 'forged');
    RAISE EXCEPTION 'FAIL: anon inserted into state_transitions';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;  -- SQLSTATE 42501: expected
  END;
END $$;
ROLLBACK;

-- 5. service_role can still insert (bypasses RLS; default grant intact).
BEGIN;
SET LOCAL ROLE service_role;
INSERT INTO public.state_transitions (entity_type, entity_id, new_status)
VALUES ('order', '00000000-0000-0000-0000-000000000003', 'service-ok');
ROLLBACK;

-- 6. audit_transition is not executable by anon or authenticated.
DO $$
BEGIN
  IF has_function_privilege('anon',
       'public.audit_transition(text,uuid,text,text,text,text,jsonb)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: anon can execute audit_transition';
  END IF;
  IF has_function_privilege('authenticated',
       'public.audit_transition(text,uuid,text,text,text,text,jsonb)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: authenticated can execute audit_transition';
  END IF;
END $$;
```

- [ ] **Step 3: Apply locally and run the test**

Run:
```bash
supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -f supabase/tests/test_034_lock_audit_trail.sql
```
(If your local port differs, substitute the URL shown by `supabase status`.)
Expected: reset applies all migrations incl. 034 without errors; psql prints no `FAIL:` lines and exits 0.

- [ ] **Step 4: Regression-check the existing RPC suite**

The audit-writing RPCs (`process_paymob_callback`, `expire_pending_order`, `update_order_status`, COD confirm) call `audit_transition()` internally as definer-owner, so they must be unaffected. Re-run one existing transition test to confirm:
```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -f supabase/tests/test_031_realtime_and_cron.sql
```
Expected: no FAIL lines.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/034_lock_audit_trail.sql supabase/tests/test_034_lock_audit_trail.sql
git commit -m "fix(supabase): lock state_transitions audit trail behind RLS and revoke audit_transition"
```

---

### Task 2: Add fetch methods to AdminRepository (interface + Supabase impl + fake)

**Files:**
- Modify: `lib/features/admin/domain/repositories/admin_repository.dart` (append after `getActiveFlashSales`, line 73)
- Modify: `lib/features/admin/data/supabase_admin_repository.dart` (append after `getActiveFlashSales`, line 141)
- Test (modify): `test/admin_catalog_navigation_test.dart` (extend `FakeAdminRepository`, lines 19-75)

**Interfaces:**
- Produces (consumed by Task 3):
  - `Future<List<Map<String, dynamic>>> getVariants(String productId)` — all variants for a product, ordered by `size`.
  - `Future<List<String>> getProductImagePaths(String productId)` — `storage_path` values ordered by `sort_order`.
- Errors: thrown naturally (PostgrestException bubbles), matching every existing method in this interface — the pages already wrap calls in try/catch.

- [ ] **Step 1: Make it red — extend the interface**

In `lib/features/admin/domain/repositories/admin_repository.dart`, append inside the class (after `getActiveFlashSales`):

```dart
  /// Get all variants for [productId], ordered by size.
  Future<List<Map<String, dynamic>>> getVariants(String productId);

  /// Get ordered storage paths for a product's images.
  Future<List<String>> getProductImagePaths(String productId);
```

- [ ] **Step 2: Run analyze to verify it fails**

Run: `flutter analyze`
Expected: errors — `SupabaseAdminRepository` and `FakeAdminRepository` missing overrides (`missing_concrete_…` / `non_abstract_abstract_member` style analyzer errors for `getVariants` / `getProductImagePaths`). Also `flutter test test/admin_catalog_navigation_test.dart` fails to compile. That is the red state.

- [ ] **Step 3: Implement in the Supabase repository**

In `lib/features/admin/data/supabase_admin_repository.dart`, append inside the class (after `getActiveFlashSales`):

```dart
  @override
  Future<List<Map<String, dynamic>>> getVariants(String productId) async {
    final res = await _client
        .from('product_variants')
        .select()
        .eq('product_id', productId)
        .order('size');
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<String>> getProductImagePaths(String productId) async {
    final res = await _client
        .from('product_images')
        .select('storage_path')
        .eq('product_id', productId)
        .order('sort_order');
    return (res as List)
        .map((e) => (e as Map<String, dynamic>)['storage_path'] as String)
        .toList();
  }
```

(The queries are lifted verbatim from the two presentation pages being fixed in Task 3 — `admin_variant_editor_page.dart:38-42` and `admin_image_manager_page.dart:40-44` — so behavior is identical.)

- [ ] **Step 4: Extend the fake**

In `test/admin_catalog_navigation_test.dart`, change the fake to hold data and add the two overrides. Replace the class fields (line 20-21) with:

```dart
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({this.isAdmin = true});
  bool isAdmin;
  List<Map<String, dynamic>> variants = const [];
  List<String> productImagePaths = const [];
```

and append inside the class (after `getActiveFlashSales`, line 74):

```dart
  @override
  Future<List<Map<String, dynamic>>> getVariants(String productId) async =>
      variants;

  @override
  Future<List<String>> getProductImagePaths(String productId) async =>
      productImagePaths;
```

- [ ] **Step 5: Check for other implementers**

Run: `grep -rn "implements AdminRepository" lib test`
Expected: exactly two hits — `SupabaseAdminRepository` and the fake above. If any third implementer appears, add trivial overrides there too (`=> [];` / `const []`), otherwise proceed.

- [ ] **Step 6: Green**

Run: `flutter analyze && flutter test test/admin_catalog_navigation_test.dart`
Expected: analyzer clean; test file compiles and passes (pages still hit their old direct-Supabase path here — that is fine, the fake just satisfies the interface).

- [ ] **Step 7: Commit**

```bash
git add lib/features/admin/domain/repositories/admin_repository.dart lib/features/admin/data/supabase_admin_repository.dart test/admin_catalog_navigation_test.dart
git commit -m "refactor(admin): add variant/image fetch methods to AdminRepository"
```

---

### Task 3: Rewire admin pages through the repository

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_variant_editor_page.dart` (`_loadVariants`, lines 30-61; import line 2)
- Modify: `lib/features/admin/presentation/pages/admin_image_manager_page.dart` (`_loadImages`, lines 33-70; import line 2)
- Test (modify): `test/admin_catalog_navigation_test.dart` (extend the page-pump tests around lines 237-281 to assert loaded content renders)

**Interfaces:**
- Consumes: `getIt<AdminRepository>()` — already registered in production (`service_locator.dart:58`) and in the nav test (`registerSingleton<AdminRepository>(fakeAdmin)`, line 126).

- [ ] **Step 1: Write the failing assertion first**

In `test/admin_catalog_navigation_test.dart`, find the second test (the one starting `final fakeAdmin = FakeAdminRepository();` near line 237). Before pumping each page, seed data and assert it renders. Replace the pump/assert pairs (lines ~266-281) with:

```dart
    fakeAdmin.variants = [
      {'id': 'v1', 'size': 'M', 'color': 'Navy', 'stock': 12},
    ];
    await tester.pumpWidget(
      MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminVariantEditorPage(productId: 'pid')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminVariantEditorPage), findsOneWidget);
    expect(find.text('M / Navy'), findsOneWidget);
    expect(find.text('Stock: 12'), findsOneWidget);

    fakeAdmin.productImagePaths = ['product-images/pid/a.jpg'];
    await tester.pumpWidget(
      MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminImageManagerPage(productId: 'pid')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminImageManagerPage), findsOneWidget);
    expect(find.byType(AppImage), findsOneWidget);
```

Add the needed import at the top of the file if absent:

```dart
import 'package:al_batal_elite/shared/components/app_image.dart';
```

(Mirror whatever localization setup the existing pumps at lines 264-279 already use — copy their exact `MaterialApp` wrapper verbatim and only add the seeding + new expects. If the existing wrapper differs from the snippet above, prefer the file's existing wrapper.)

- [ ] **Step 2: Run to verify red**

Run: `flutter test test/admin_catalog_navigation_test.dart`
Expected: FAIL — `'M / Navy'` and `AppImage` not found, because `_loadVariants`/`_loadImages` still go through the uninitialized `Supabase.instance.client` and swallow into empty lists.

- [ ] **Step 3: Rewire the variant editor**

In `lib/features/admin/presentation/pages/admin_variant_editor_page.dart`:

Delete import line 2 (`import 'package:supabase_flutter/supabase_flutter.dart';`).

Replace `_loadVariants` (lines 30-61) with:

```dart
  Future<void> _loadVariants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final variants =
          await getIt<AdminRepository>().getVariants(widget.productId);
      if (!mounted) return;
      setState(() {
        _variants = variants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
```

(The string-matching fallback disappears: with the fake injected, tests no longer depend on "uninitialized Supabase" detection, so real DB errors now surface instead of being hidden by `contains('Supabase')`.)

- [ ] **Step 4: Rewire the image manager**

In `lib/features/admin/presentation/pages/admin_image_manager_page.dart`:

Delete import line 2 (`import 'package:supabase_flutter/supabase_flutter.dart';`).

Replace `_loadImages` (lines 33-70) with:

```dart
  Future<void> _loadImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paths = await getIt<AdminRepository>()
          .getProductImagePaths(widget.productId);
      if (!mounted) return;
      setState(() {
        _paths = paths;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
```

(`AppError` and `StorageService` imports stay — still used by `_persistPaths` / `_uploadImage`.)

- [ ] **Step 5: Full verification**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; entire suite green (nav test now asserts real rendered data; no other test touches these pages' load path).

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/presentation/pages/admin_variant_editor_page.dart lib/features/admin/presentation/pages/admin_image_manager_page.dart test/admin_catalog_navigation_test.dart
git commit -m "refactor(admin): route image/variant loads through AdminRepository"
```

---

## Out of scope (recorded, not planned here)

MEDIUM findings from the same audit (profiles INSERT `is_admin` guard, `stock_restorations` RLS, `paymob_order_id` squatting, COD pre-collection `paid` semantics, checkout raw-error leak, catalog pagination, realtime channel cleanup, persisted idempotency key, `payment_id` column misuse) — separate plans after these HIGHs land.
