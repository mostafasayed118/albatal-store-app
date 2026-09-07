# Demo seed (staging)

1. Backup: `supabase db dump -f outputs/db-backups/staging-pre052-<ts>.sql`
2. Apply catalog locally first: `supabase migration up`, verify with `scripts/verify_demo_seed.sql`.
3. Dry run: `DRY_RUN=1 node scripts/seed_demo_staging.mjs --dry-run`
4. Live: `SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... SUPABASE_ANON_KEY=... node scripts/seed_demo_staging.mjs`
5. `db push` is human-gated. Never run against prod without `ALLOW_PROD=1` + owner approval.
