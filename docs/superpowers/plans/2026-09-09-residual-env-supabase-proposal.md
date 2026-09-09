# Residual Env + Supabase Hardening — PROPOSAL ONLY (DO NOT APPLY WITHOUT HUMAN REVIEW)

Date: 2026-09-09 · Slice: P2+R4+R5 follow-up · Branch: `fix/audit-residual`
Status: **PROPOSAL — no step below has been executed.** Every command/SQL block
requires explicit owner approval. No `supabase/` migration, no env untracking,
and no secret rotation was performed in this slice (lib/+docs+test only).

## Context

- `git ls-files config/` shows `config/env.staging.json` (and
  `config/env.production.json`) are **tracked**.
- `.gitleaks.toml` allowlists both paths (anon-key-by-design rationale).
- `ci.yml` `secret-scan` excludes `config/env*.json` from the JWT-like-token
  check for the same reason.
- `config/README.md` states the committed files contain only placeholders and
  real values live in gitignored `config/env.*.local.json`.
- Worst-case assumption of this proposal: a **live anon key was committed at
  some point in history** (placeholders today do not erase history). Git
  history is public to anyone with repo access, so rotation + untracking is
  the only complete remediation.

## Step 1 — Untrack the staging env file (human runs)

```bash
git rm --cached config/env.staging.json
```

Then append to `.gitignore` (currently only `config/env.*.local.json` and
`config/env.*.secret.json` are ignored):

```gitignore
# Staging build config holds a live key — never track (see proposal
# docs/superpowers/plans/2026-09-09-residual-env-supabase-proposal.md)
config/env.staging.json
```

Keep the local workflow: `cp config/env.staging.json
config/env.staging.local.json` once (before deleting the tracked copy, or
re-create from the dashboard), fill real values into the `.local.json` only,
build with `--dart-define-from-file=config/env.staging.local.json`.
`config/env.production.json` stays tracked in this step (out of scope —
follow-up proposal if the same treatment is wanted).

## Step 2 — Remove the gitleaks allowlist entry (human runs)

In `.gitleaks.toml`, delete the staging line (keep the production line until
the follow-up):

```toml
# DELETE this line:
'''^config/env\.staging\.json$''',
```

After Step 1+2, `gitleaks protect` / the CI scan will flag any re-introduced
staging env file instead of silently passing.

## Step 3 — CI assert: staging env must stay untracked (human runs)

Extend the `High-risk secret patterns` step in `.github/workflows/ci.yml`
(right after the "Tracked .env files" block):

```yaml
      - name: High-risk secret patterns
        run: |
          set -uo pipefail
          EXIT=0

          echo "==> Tracked staging env file (must stay untracked)"
          if git ls-files | grep -x 'config/env.staging.json'; then
            echo "::error::config/env.staging.json is tracked — untrack it (see residual env proposal)"
            EXIT=1
          fi
          # ... rest of the existing checks unchanged ...
```

Also narrow the JWT-like-token exclusion from `--glob '!config/env*.json'`
to `--glob '!config/env.production.json'` so only the still-tracked
production placeholder keeps the exemption.

## Step 4 — Rotate the staging anon key (human runs, Supabase dashboard)

A key that lived in git history must be treated as exposed even if the
current file holds a placeholder:

1. Supabase Dashboard → staging project → Project Settings → API → rotate /
   regenerate the `anon` key (note: this rotates the JWT signing secret, so
   the `service_role` key changes too — re-issue Edge Function secrets after).
2. Write the new anon key into the LOCAL file only:
   `config/env.staging.local.json` (gitignored — verify with `git status`).
3. `supabase functions secrets set` for any rotated server secrets; redeploy
   edge functions (`paymob-initiate`, `instapay-*`, `delete-account`,
   `cancel-expired-orders`).
4. Re-run the RLS adversarial suite + `flutter test` against staging; confirm
   the old key returns 401.
5. Purge history only if the repo is private AND all collaborators agree
   (rewriting public history breaks clones — default: rotate, do not rewrite).

## Step 5 — Storage-policy SQL — HUMAN-REVIEW DO NOT APPLY

The client assumes: `product-images` public-read (via `getPublicUrl`),
`avatars` public-read, `instapay-proofs` private (migration 041). The
following **proposed** least-privilege policy set has NOT been applied, NOT
placed under `supabase/migrations/`, and MUST pass human + staging review
first (it changes write paths — the avatar `upsert:false` client change in
this slice assumes insert-only semantics).

```sql
-- ===== HUMAN-REVIEW DO NOT APPLY — proposal only =====
-- Least-privilege storage RLS for residual hardening.
-- Apply order (human-gated): staging db push → storage E2E → production.

-- product-images: public read; authenticated inserts only under any path
-- (writes are admin flows; tighten prefix to product ids when known).
create policy "product-images public read"
on storage.objects for select
using (bucket_id = 'product-images');

create policy "product-images authenticated insert"
on storage.objects for insert
with check (bucket_id = 'product-images' and auth.role() = 'authenticated');

-- No update/delete policies: objects are immutable-once-written
-- (matches client upsert:false). Add admin-only update/delete via an
-- assert_admin() gate if curation tooling needs it.

-- avatars: public read; owner-only insert confined to the uid prefix.
create policy "avatars public read"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "avatars owner insert"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- instapay-proofs: NO public access; owner insert, admin select.
create policy "instapay-proofs owner insert"
on storage.objects for insert
with check (
  bucket_id = 'instapay-proofs'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "instapay-proofs admin select"
on storage.objects for select
using (
  bucket_id = 'instapay-proofs'
  and exists (select 1 from public.profiles p
              where p.id = auth.uid() and p.is_admin = true)
);
-- ===== END PROPOSAL =====
```

## Acceptance checklist (owner)

- [ ] `git ls-files config/` no longer lists `env.staging.json`
- [ ] `.gitleaks.toml` staging allowlist line removed
- [ ] CI fails on a re-tracked staging env file (Step 3 assert red-tested)
- [ ] Staging anon key rotated; old key 401s; edge functions redeployed
- [ ] Storage SQL reviewed, applied to staging first, E2E green before prod
