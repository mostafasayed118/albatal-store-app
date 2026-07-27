# Package K — Phase K0: Apply Migration 028 to Staging

Source tag: release-candidate/484a3ea (PRE-SECURITY-REPAIR candidate)
Worktree: C:/flutter_projects/albatal-484a3ea (detached HEAD 484a3ea, verified)
Staging project: alxwvyflasewslinufqe
Migration: 028_reclose_payments_insert_policy.sql
Approval reference: PACKAGE-K0-APPLY-028

> Prep status (automated, non-mutating): worktree created at the frozen tag;
> HEAD = 484a3ea39462277dd9ab0830b26d4fd724ab0c1a; on-disk migrations end at
> `028_reclose_payments_insert_policy.sql`; `029` is ABSENT in this worktree
> (correct — 029 lives only on branch fix/package-k-security-grants). Supabase
> CLI 2.109.1.
>
> The `supabase link` + `supabase db push` steps are interactive (staging DB
> password) and MUTATING. They are HUMAN-EXECUTED and require the K0 owner name
> to be filled below. Do NOT paste the DB password anywhere. If `supabase link`
> fails on config.toml schema drift (historical B3: CLI 2.109.1 rejected
> `db.pooler.extra_pool_size`, `db.shadow_project_id`,
> `auth.refresh_token_rotation_enabled`), apply 028 via the Dashboard SQL Editor
> using the migration body, or temporarily reconcile config.toml (do NOT commit
> that change to the frozen tag).

## K0 Authorization (fill before execution)

```
I approve applying migration 028_reclose_payments_insert_policy.sql to staging.
Source tag: release-candidate/484a3ea
Project: alxwvyflasewslinufqe
Owner name: [FILL]
Date: [FILL]
Approval reference: PACKAGE-K0-APPLY-028
```

## Commands (run in the frozen-tag worktree)

```bash
cd C:/flutter_projects/albatal-484a3ea
git rev-parse HEAD            # expect 484a3ea39462277dd9ab0830b26d4fd724ab0c1a
supabase link --project-ref alxwvyflasewslinufqe   # enter staging DB password (do NOT paste it)
supabase db push --dry-run   # expect: only 028 pending; 029 NOT listed
supabase db push             # apply 028 only
```

If `029` appears in the dry-run, STOP — you are in the wrong worktree.

## Verification SQL (read-only)

```sql
-- Ledger
SELECT count(*) AS migration_count, max(version) AS high_water
FROM supabase_migrations.schema_migrations;

SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;

-- Payments INSERT policies (expect 0 rows)
SELECT policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND policyname IN ('payments_insert_own', 'payments_insert_authenticated_own');
```

## Results (paste after execution)

Dry-run output (only 028 pending?): [FILL]

Migration ledger high-water after push: [FILL]  (expect 028 present; 029 NOT present yet)

payments_insert_own present: [FILL]  (expect NO)
payments_insert_authenticated_own present: [FILL]  (expect NO)
Payments INSERT policies query row count: [FILL]  (expect 0)

K0 verdict: [PASS / FAIL]

Notes: [FILL]

---

This changes the Package J "Payments INSERT policy" check from FAIL -> PASS.
The remaining DB-catalog failures (anon write grants; stock/expiry + set_payment
RPC grants) are fixed by migration 029, applied in Phase K3 from the NEW frozen
candidate after PR #5 CI is green. Release verdict remains NO-GO.
