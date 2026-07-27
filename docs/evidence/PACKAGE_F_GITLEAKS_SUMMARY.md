# Package F — Gitleaks / Secret Scan Summary

Captured: 2026-07-27 (Africa/Cairo)
Candidate SHA: c2a2ef72dbfd6a087a7b5035e6a60ff8d76a6461

## Local scan method

gitleaks is not installed locally. The repo's own CI high-risk secret patterns
(from `.github/workflows/ci.yml` "High-risk secret patterns" step) were reproduced
locally using `rg` (ripgrep), which is available.

## Results

### Tracked .env files (excluding .env.example)
NONE — clean.

### Tracked keystore artifacts (.jks, .keystore, release-keystore)
NONE — clean.

### Private keys / base64 keystore blobs in source
NONE — rg exit 1 (no matches) — clean.

### PAYMOB_ and SUPABASE_SERVICE_ROLE_KEY secrets
NONE — rg exit 1 (no matches) — clean.

### JWT-like tokens in source
ONE MATCH — rg exit 0:

  File: config/env.staging.json
  Key:  SUPABASE_ANON_KEY
  Type: Supabase anon (public) JWT — role: "anon"

## Triage assessment

The Supabase anon key is the **public client-side key** for the staging project.
It is intentionally publishable: it is protected by Row Level Security (RLS) and
is not a service-role or admin credential. It is equivalent to a public API key.

The repo's own CI "High-risk secret patterns" step would flag this as a JWT-like
token (the pattern matches any `eyJ...` JWT regardless of role). This is a
**false positive** for the purposes of the high-risk secret check.

The gitleaks scan (step 3 of Secret Scan job) failed before the "High-risk secret
patterns" step ran (step 4 was skipped). The gitleaks failure is the primary
blocker.

## gitleaks CI failure root cause

The CI workflow passes `config-path: .github/gitleaks.toml` as a `with:` input
to `gitleaks/gitleaks-action@v2`. However, `gitleaks-action@v2` does NOT accept
`config-path` as a `with:` input — it uses the `GITLEAKS_CONFIG` environment
variable instead. The annotation confirms:

  "Unexpected input(s) 'config-path', valid inputs are ['']"

This means the `.github/gitleaks.toml` allowlist (which allowlists `docs/` and
`.md` files) was NOT applied during the CI scan. Gitleaks ran with its default
ruleset and no allowlist, causing it to flag content that the allowlist would
have suppressed.

## Real secret determination

NO real secret was found in source files by the repo's own high-risk patterns.
The only JWT match is the Supabase anon key in `config/env.staging.json`, which
is a public client credential, not a service-role or admin secret.

## Rotation required

NO — the Supabase anon key is a public credential by design. No rotation is
required for this finding.

## Recommended fix

Replace the invalid `with: config-path:` input with the correct
`env: GITLEAKS_CONFIG:` environment variable in the Secret Scan job.
This will cause gitleaks to apply the existing `.github/gitleaks.toml`
allowlist, which already covers `docs/` and `.md` files.

The `config/env.staging.json` anon key match should be added to the allowlist
as a narrow path entry, since it is a known public credential.

## Status

Real secret: NO
Rotation required: NO
Allowlist fix required: YES (gitleaks-action config-path → GITLEAKS_CONFIG env var)
Narrow allowlist addition required: YES (config/env.staging.json anon key)
