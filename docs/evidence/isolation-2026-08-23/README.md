# Environment Isolation — Provisioning Evidence (2026-08-23)

Owner approved Option A via best-recommendation delegation (`docs/ENVIRONMENT_ISOLATION_PLAN.md` §Decisions).

## Result

| Environment | Project ref | Region | Org |
|---|---|---|---|
| **Staging** (new) | `zvpjngdgbpnkkqrorkul` | eu-west-1 | `al-batal` (`hmpakdyoltlrmzkojdfh`) |
| **Production** (unchanged) | `alxwvyflasewslinufqe` | eu-west-1 | mostafasayed118's Org |

## What was done

1. **Org**: created `al-batal` after confirming the free-tier limit is
   2 active projects **per user across orgs** (new org did not bypass it).
2. **Slot freed**: `Portfolio_builder` (`txnuvpxhghxiwynhtbvo`) PAUSED via
   Management API `POST /v1/projects/{ref}/pause` → HTTP 200. Restore:
   dashboard → Restore, or `supabase projects` has no CLI pause; use
   dashboard. Data intact.
3. **Project created**: CLI `projects create` (free tier), ACTIVE_HEALTHY.
4. **Migrations**: 29/29 applied (`supabase db push`, linked to staging).
   - One-time bootstrap required: Supavisor **transaction pooler forces an
     empty search_path**, so unqualified `uuid_generate_v4()` failed
     (SQLSTATE 42883). Fix: `CREATE FUNCTION public.uuid_generate_v4()`
     delegating to `extensions.uuid_generate_v4()` (via Management API
     `/database/query`). Production does NOT have this shim (was provisioned
     via dashboard sessions); apply the identical shim before future CLI
     pushes to production.
5. **Edge Functions**: all 5 deployed by CLI.
6. **Function secrets set (6)**: PAYMOB_API_KEY, PAYMOB_INTEGRATION_ID,
   PAYMOB_HMAC_SECRET (sandbox values from local `.env.staging`),
   CANCEL_EXPIRED_ORDERS_SECRET + NOTIFICATIONS_INTERNAL_KEY (from
   `secrets-staging.env`), SCHEDULER_SECRET (freshly generated).
7. **Auth config synced from production**: `mailer_autoconfirm=true`,
   signup enabled (PATCH `/config/auth` → 200).
8. **Env files**: committed `config/env.staging.json` now points at
   `https://zvpjngdgbpnkkqrorkul.supabase.co` with new anon key;
   `.env.staging` + `config/env.staging.local.json` updated for local dev.
   `config/env.production.json` untouched.
9. **REST verification**: `GET /rest/v1/products?limit=3` with new anon key
   returns seeded catalog (Royal Emerald Silk, Golden Charmeuse Silk,
   Egyptian Cotton) — RLS active on fresh project.
10. **Banner**: debug banner now shows `DEV·<project-ref>`.

## Owner actions outstanding (Paymob dashboard)

1. Create a second integration entry `al-batal-staging` using Paymob
   **TEST/sandbox credentials**.
2. Copy its `iframe_id` into staging function secrets:
   ```
   supabase secrets set PAYMOB_IFRAME_ID=<value> --project-ref zvpjngdgbpnkkqrorkul
   ```
3. Set transaction callback/redirect URL to
   `https://zvpjngdgbpnkkqrorkul.supabase.co/functions/v1/paymob-callback`.
4. In staging dashboard → Edge Functions → paymob-callback → verify_jwt
   must be **OFF** (function verifies HMAC itself; matches ratified prod
   configuration).

## Security notes

- No secret values were printed or persisted outside their origin files;
  Management API token stayed inside PowerShell process memory.
- Staging DB password: generated during creation, not retained in repo.
  Reset via dashboard when direct SQL access is needed.
- `secrets list` CLI output displays SHA-256 digests, not raw values.
