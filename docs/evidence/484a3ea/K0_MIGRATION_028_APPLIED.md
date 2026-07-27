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

## K0 Authorization (GRANTED)

```
I approve applying migration 028_reclose_payments_insert_policy.sql to staging.
Source tag: release-candidate/484a3ea
Project: alxwvyflasewslinufqe
Owner name: Mustaf Sayed Saeed
Role: Project Owner / Database Owner
Date: 2026-07-27
Approval reference: PACKAGE-K0-APPLY-028
```

Link status (checked automatically): worktree C:/flutter_projects/albatal-484a3ea
is NOT yet linked (no supabase/.temp/project-ref). `supabase link` must be run by
the owner and requires the interactive staging DB password. The agent does not
enter, print, or store that password.


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

## K0 Execution Summary (results)

Executed by: Mustaf Sayed Saeed
Date: 2026-07-27
Method: supabase db push
Staging project: alxwvyflasewslinufqe
Source tag: release-candidate/484a3ea
Source SHA: 484a3ea39462277dd9ab0830b26d4fd724ab0c1a

### Dry run

```bash
supabase db push --dry-run
```

Result:

```text
Only migration 028 pending.
Migration 029 was NOT listed.
```

Confirmed only 028 pending: YES
Confirmed 029 absent: YES

### Migration ledger

```sql
SELECT version FROM supabase_migrations.schema_migrations WHERE version = '028';
```

Result: `028 present`

### Payments policies

```sql
SELECT policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND policyname IN ('payments_insert_own', 'payments_insert_authenticated_own');
```

Result: `0 rows`

payments_insert_own present: NO
payments_insert_authenticated_own present: NO
Payments INSERT policies query row count: 0

### K0 verdict

**PASS** — migration 028 applied to staging; the Package J
`payments_insert_authenticated_own` FAIL is resolved. No migration 029 applied.
No Edge Function deployment. No secret changes. Release verdict remains NO-GO.


---

This changes the Package J "Payments INSERT policy" check from FAIL -> PASS.
The remaining DB-catalog failures (anon write grants; stock/expiry + set_payment
RPC grants) are fixed by migration 029, applied in Phase K3 from the NEW frozen
candidate after PR #5 CI is green. Release verdict remains NO-GO.
