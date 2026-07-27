# Environment Isolation Plan — Al Batal Elite

**Date:** 2026-07-25
**Status:** DRAFT — requires human approval before implementation
**Scope:** Supabase project isolation across staging / production

---

## Current State (Confirmed)

| Artifact | Value |
|---|---|
| Supabase project ref | `alxwvyflasewslinufqe` |
| `config/env.staging.json` | Points to `alxwvyflasewslinufqe.supabase.co` |
| `config/env.production.json` | Points to `alxwvyflasewslinufqe.supabase.co` |
| Anon key (both files) | Identical JWT |
| Edge Function secrets | Set via `supabase functions secrets set` (per-project) |
| Paymob webhook URL | Hardcoded to project ref in Paymob dashboard |
| Build injection | `--dart-define-from-file=config/env.<env>.json` |

**Problem confirmed:** Staging and production share the exact same Supabase project, anon key, and data. A staging migration or data mutation directly affects production.

---

## Option Comparison

### Option A — Separate Supabase Projects

| Dimension | Assessment |
|---|---|
| **Risk** | **Low.** Complete infrastructure separation. A staging disaster cannot touch production data. |
| **Effort** | **Medium-High.** Requires creating a second project, re-running all 21 migrations, re-deploying all 5 Edge Functions, configuring separate Paymob webhooks, and maintaining dual migration paths. |
| **Data isolation** | **Complete.** Different Postgres instances, different connection pools, different storage buckets. Zero shared state. |
| **RLS impact** | **None.** RLS policies are per-database. Identical policies are applied to both projects via the same migration files. |
| **Edge Function impact** | **Moderate.** Each project gets its own Edge Function deployment. Secrets (`PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, etc.) must be set independently per project. The `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are different per project — Edge Functions read them from the project's environment automatically. |
| **Paymob webhook impact** | **High.** Paymob dashboard must be configured with two separate callback URLs — one pointing to the staging project's Edge Function endpoint, one to production. Requires either two Paymob merchant accounts or two integration IDs on the same account. |
| **Recommendation** | **RECOMMENDED for payment-sensitive apps.** This is the only option that provides true blast-radius isolation. The extra effort is justified because Al Batal Elite processes real payments via Paymob. |

### Option B — Same Project, Separate Schemas

| Dimension | Assessment |
|---|---|
| **Risk** | **Medium.** Data is logically separated by schema, but lives in the same Postgres instance. A misconfigured RLS policy or a `SECURITY DEFINER` RPC with a bug can cross schema boundaries. Resource exhaustion (CPU/RAM) in staging impacts production. |
| **Effort** | **Medium.** Requires rewriting all 21 migrations to use `staging.*` / `production.*` schemas, updating `search_path` on every RPC, modifying Supabase client configuration to target a non-default schema, and ensuring PostgREST/PostgREST schema routing is correct. |
| **Data isolation** | **Partial.** Postgres schemas provide namespace isolation but share the same instance, connection pool, and resources. The `service_role` key can access all schemas. RLS is per-table and must be applied to both schemas. |
| **RLS impact** | **Severe.** Every RLS policy (002, 015, 017, 019) must be duplicated for each schema. `search_path` on every RPC must be explicitly set. A single misconfigured `SET search_path` can leak staging data to production. |
| **Edge Function impact** | **Moderate.** Edge Functions must be modified to select the correct schema at runtime (via `search_path` or client configuration). This adds conditional logic that must be tested per-environment. |
| **Paymob webhook impact** | **Low.** Single webhook URL. The callback Edge Function routes to the correct schema based on a header or claim. However, this adds complexity to the HMAC verification flow. |
| **Recommendation** | **NOT RECOMMENDED.** The migration complexity and RLS duplication make this error-prone. Supabase is not designed for multi-schema hosting; PostgREST schema routing has edge cases. The risk of cross-schema leakage outweighs the cost savings. |

### Option C — Same Project, Separate API Keys / Roles

| Dimension | Assessment |
|---|---|
| **Risk** | **High.** Staging and production share the same database, same tables, same data. Separate API keys provide no data isolation — they are all backed by the same RLS policies on the same rows. |
| **Effort** | **Low.** Create a second `anon` role or use Postgres roles with different permissions. Set different keys in config files. |
| **Data isolation** | **None.** Both keys read/write the same rows. A staging test that creates orders, modifies stock, or triggers payments affects production data. |
| **RLS impact** | **None** (policies are shared). But this is the problem — there is no way to prevent staging operations from touching production rows. |
| **Edge Function impact** | **None.** Edge Functions run in the same environment. The `SUPABASE_URL` and service-role key are the same. |
| **Paymob webhook impact** | **None.** Single webhook URL. But staging payment tests hit the live Paymob integration, potentially creating real charges. |
| **Recommendation** | **NOT RECOMMENDED.** This is effectively the current state (shared project) with cosmetic separation. It provides zero blast-radius protection. |

---

## Summary Matrix

| Factor | A: Separate Projects | B: Separate Schemas | C: Separate Keys |
|---|---|---|---|
| Data isolation | Complete | Partial | None |
| Blast-radius | Zero cross-env | Low-Medium | Full cross-env |
| Migration effort | Medium-High | Medium | Low |
| Ongoing maintenance | Medium | High (dual schemas) | Low |
| Paymob isolation | Requires 2 webhooks | Shared webhook | Shared webhook |
| RLS safety | Per-project (safe) | Per-schema (fragile) | Shared (unsafe) |
| Resource isolation | Complete | Shared instance | Shared instance |
| **Verdict** | **RECOMMEND** | Avoid | Avoid |

---

## Recommended Strategy: Option A — Separate Supabase Projects

### 1. Required Supabase Projects

| Environment | Project Name (suggested) | Purpose |
|---|---|---|
| **Staging** | `al-batal-staging` | Development, QA, integration testing |
| **Production** | `al-batal-production` (rename current) | Live customer traffic, real payments |

The current project `alxwvyflasewslinufqe` should be renamed/repurposed as **production**. A new project is created for staging.

### 2. Required Secret Names

#### Flutter Client (build-time — `config/env.*.json`)

| Variable | Staging | Production | Notes |
|---|---|---|---|
| `SUPABASE_URL` | `https://<STAGING_REF>.supabase.co` | `https://<PRODUCTION_REF>.supabase.co` | Different project refs |
| `SUPABASE_ANON_KEY` | Staging anon JWT | Production anon JWT | Different keys per project |
| `SENTRY_DSN` | Staging DSN (or shared) | Production DSN | Can share if same Sentry project |

#### Edge Function Secrets (per-project via `supabase functions secrets set`)

| Secret | Staging Value | Production Value | Notes |
|---|---|---|---|
| `PAYMOB_API_KEY` | Test/sandbox key | Live/production key | Different Paymob environment |
| `PAYMOB_INTEGRATION_ID` | Staging integration ID | Production integration ID | Per Paymob dashboard |
| `PAYMOB_HMAC_SECRET` | Staging HMAC secret | Production HMAC secret | Per Paymob dashboard |
| `PAYMOB_IFRAME_ID` | Staging iframe ID | Production iframe ID | Per Paymob dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-set by project | Auto-set by project | Different per project |
| `SCHEDULER_SECRET` | Staging value | Production value | Can be different |

**Paymob Dashboard Configuration:**
- Create two integration entries: `al-batal-staging` and `al-batal-production`
- Each integration gets its own: API key, integration ID, iframe ID, HMAC secret
- Staging callback URL: `https://<STAGING_REF>.supabase.co/functions/v1/paymob-callback`
- Production callback URL: `https://<PRODUCTION_REF>.supabase.co/functions/v1/paymob-callback`

### 3. Required Flutter Environment Wiring

#### File Structure

```
config/
  env.staging.json          # Committed with placeholders
  env.production.json       # Committed with placeholders
  env.staging.local.json    # Gitignored — real staging values
  env.production.local.json # Gitignored — real production values
```

#### `config/env.staging.json` (template — committed)

```json
{
  "SUPABASE_URL": "https://<STAGING_REF>.supabase.co",
  "SUPABASE_ANON_KEY": "<STAGING_ANON_KEY>",
  "SENTRY_DSN": ""
}
```

#### `config/env.production.json` (template — committed)

```json
{
  "SUPABASE_URL": "https://<PRODUCTION_REF>.supabase.co",
  "SUPABASE_ANON_KEY": "<PRODUCTION_ANON_KEY>",
  "SENTRY_DSN": "<PRODUCTION_DSN>"
}
```

#### Build Commands

```bash
# Local development (staging)
flutter run --dart-define-from-file=config/env.staging.local.json

# Staging APK
flutter build apk --release --dart-define-from-file=config/env.staging.local.json

# Production APK
flutter build apk --release --dart-define-from-file=config/env.production.local.json
```

#### Environment Banner Enhancement

Update `lib/shared/widgets/environment_banner.dart` to display the project ref so the developer always knows which Supabase project they are connected to:

```dart
// Add to EnvironmentBanner:
// In DEV mode, show the project ref in the banner
// to prevent confusion between staging and production.
```

### 4. Required CI/CD Secret Handling

Since there is no `.github/workflows/` yet, this is a forward-looking spec for when CI/CD is added.

#### GitHub Actions Secrets

| Secret Name | Scope | Value |
|---|---|---|
| `STAGING_SUPABASE_URL` | Staging builds | `https://<STAGING_REF>.supabase.co` |
| `STAGING_SUPABASE_ANON_KEY` | Staging builds | Staging anon key |
| `PRODUCTION_SUPABASE_URL` | Production builds | `https://<PRODUCTION_REF>.supabase.co` |
| `PRODUCTION_SUPABASE_ANON_KEY` | Production builds | Production anon key |
| `SUPABASE_ACCESS_TOKEN` | Migration/deploy | Supabase CLI access token |

#### CI/CD Workflow Pattern

```yaml
# Staging build
- run: |
    echo '{"SUPABASE_URL":"${{ secrets.STAGING_SUPABASE_URL }}","SUPABASE_ANON_KEY":"${{ secrets.STAGING_SUPABASE_ANON_KEY }}"}' > /tmp/env.json
    flutter build apk --dart-define-from-file=/tmp/env.json
    rm /tmp/env.json

# Production build (manual approval gate required)
- run: |
    echo '{"SUPABASE_URL":"${{ secrets.PRODUCTION_SUPABASE_URL }}","SUPABASE_ANON_KEY":"${{ secrets.PRODUCTION_SUPABASE_ANON_KEY }}"}' > /tmp/env.json
    flutter build apk --dart-define-from-file=/tmp/env.json
    rm /tmp/env.json
```

**Key rules:**
- Staging secrets are injected automatically on every push to `develop`
- Production secrets require manual approval (GitHub Environments)
- `config/env.*.json` committed to git contains ONLY placeholders, never real keys
- `config/env.*.local.json` is gitignored for local development

### 5. Migration Promotion Process

#### Workflow

```
develop branch
    │
    ├── Write migration in supabase/migrations/XXX_description.sql
    ├── Test locally: supabase db reset
    ├── Push to staging: supabase db push --project-ref <STAGING_REF>
    ├── Verify staging (run tests, manual QA)
    │
    └── Promote to production:
        ├── supabase db push --project-ref <PRODUCTION_REF>
        ├── Verify production (smoke test)
        └── Tag release: git tag v1.x.x
```

#### Migration Commands

```bash
# 1. Apply to local (supabase db reset)
supabase db reset

# 2. Apply to staging
supabase db push --project-ref <STAGING_REF>

# 3. Verify staging
# Run SQL tests from supabase/tests/
# Manual QA of checkout flow

# 4. Apply to production (requires confirmation prompt)
supabase db push --project-ref <PRODUCTION_REF>

# 5. Verify production
# Smoke test: create order, verify Paymob callback
```

#### Safety Rules

1. **Never apply a migration directly to production** — always go through staging first
2. **Migrations are forward-only in production** — no rollback on the production project
3. **Schema changes that affect Edge Functions must be tested on staging with staging Paymob keys**
4. **Seed data (016) must NOT run on production** — staging only
5. **Each migration file is immutable once applied to production** — create new migration files for fixes

### 6. Backup / Restore Considerations

#### Staging Project

| Aspect | Approach |
|---|---|
| Backups | Supabase Free tier: 7-day point-in-time recovery (if on Pro) |
| Restore | Dashboard → Database → Backups → Restore |
| Frequency | Automatic (Supabase-managed) |
| Risk tolerance | Low — staging can be rebuilt from migrations |

#### Production Project

| Aspect | Approach |
|---|---|
| Backups | Supabase Pro: daily backups + point-in-time recovery |
| Restore | Dashboard → Database → Backups → Restore |
| Frequency | Daily automatic + manual before major migrations |
| Risk tolerance | Zero data loss tolerance |

#### Pre-Migration Backup Checklist

```bash
# Before applying any migration to production:

# 1. Export current schema
supabase db dump --project-ref <PRODUCTION_REF> --schema-only > backup/schema_pre_migration_$(date +%Y%m%d).sql

# 2. Export full data (if needed)
supabase db dump --project-ref <PRODUCTION_REF> > backup/full_pre_migration_$(date +%Y%m%d).sql

# 3. Store backups outside Supabase (S3, local, etc.)
```

#### Cross-Environment Restore Rules

- **NEVER restore a staging backup to production**
- **NEVER restore a production backup to staging** (production contains real PII/payments)
- If staging needs production-like data, create a **sanitized export** (strip PII, anonymize emails, zero out payment details)

---

## Implementation Checklist

| # | Task | Status |
|---|---|---|
| 1 | Create new Supabase project `al-batal-staging` | Pending |
| 2 | Rename/verify current project as production | Pending |
| 3 | Run all 21 migrations on staging project | Pending |
| 4 | Deploy all 5 Edge Functions to staging | Pending |
| 5 | Set Edge Function secrets on staging project | Pending |
| 6 | Create Paymob staging integration (test keys) | Pending |
| 7 | Configure Paymob staging callback URL | Pending |
| 8 | Update `config/env.staging.json` with staging project ref | Pending |
| 9 | Update `config/env.production.json` with production project ref | Pending |
| 10 | Update `.gitignore` to cover `config/env.*.local.json` | Pending |
| 11 | Enhance `EnvironmentBanner` to show project ref | Pending |
| 12 | Test staging checkout flow end-to-end | Pending |
| 13 | Test production checkout flow end-to-end | Pending |
| 14 | Document migration promotion process in `AGENTS.md` | Pending |

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| Accidental production migration | Require manual `--project-ref` flag; never use defaults |
| Staging Paymob keys leak to production | Separate Paymob dashboard entries; CI/CD secret scopes |
| Migration drift between staging and production | Same migration files applied in same order; verify with `supabase migration list` |
| Edge Function deployment to wrong project | Always specify `--project-ref` in deploy commands |
| Config file committed with real keys | `.gitignore` covers `*.local.json`; CI validates placeholder-only committed files |

---

## Decision Required

Before implementation, confirm:

1. **Approve Option A** (separate projects)? Or discuss alternatives?
2. **Which project becomes production** — the current `alxwvyflasewslinufqe` or a new one?
3. **Paymob account** — does the current Paymob account support multiple integrations, or do we need a second merchant account?
4. **Supabase plan** — Free tier limits to 2 projects; Pro tier allows more. Which plan?
