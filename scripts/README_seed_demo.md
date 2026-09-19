# Demo seed (staging)

1. Backup: `supabase db dump -f outputs/db-backups/staging-pre052-<ts>.sql`
2. Apply catalog locally first: `supabase migration up`, verify with `scripts/verify_demo_seed.sql`.
   Checks 1/2/3/5 are expected to fail here and pass only after step 4 — they exist to
detect the unseeded state, not to gate the migration.
3. Dry run: `DRY_RUN=1 node scripts/seed_demo_staging.mjs --dry-run`
4. Live: `SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... SUPABASE_ANON_KEY=... node scripts/seed_demo_staging.mjs`
   This also generates and uploads the three showcase hero images. Checks 7/8 (the
image objects exist, with a renderable content type) pass only after it has run.
5. `db push` is human-gated. Never run against prod without `ALLOW_PROD=1` + owner approval.
