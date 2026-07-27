# Package G — Gitleaks History Triage

Candidate SHA: 8c6eac70f59b14e3c25034039679ba9e6ec39c86
CI run: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30246144500
Scan mode: full history (all revs via git rev-list --all)
Redaction: enabled (no secret values recorded)
Tooling note: gitleaks and docker are NOT installed locally; the CI job log
requires auth (403). Triage was performed with a deterministic git-history
pattern scan reproducing the repo's high-risk rules across every commit.

## Findings

| Rule / pattern | File path | Scope | Redacted match summary | Classification | Action |
|---|---|---|---|---|---|
| JWT (eyJ...) | config/env.staging.json | 9 revisions | Supabase key, decoded role="anon" (all 9) | Public credential | Narrow path allowlist |
| .env / keystore / key.properties added | (none) | full history | no matches | N/A | none |
| SUPABASE_SERVICE_ROLE_KEY = value | (none) | full history | no matches | N/A | none |
| PAYMOB_API_KEY / PAYMOB_HMAC_SECRET = value | (none) | full history | no matches | N/A | none |
| Private key PEM | (none) | full history | no matches | N/A | none |
| literal "service_role" | supabase/migrations/*.sql, docs/*, supabase/functions/* | many | Postgres role name in RLS policies / GRANTs — NOT a secret value | Non-secret keyword | none (default rules do not flag keyword) |

## JWT role decode (redacted)

All JWTs ever present in config/env.staging.json were base64-decoded (payload
only) to read the `role` claim. Result:

    role=anon occurrences=9

No `service_role` JWT was found in any historical revision of the file.

## Classification

- Public/non-secret: Supabase anon key in config/env.staging.json (role=anon).
- False positive: literal "service_role" keyword in SQL/docs (Postgres role name).
- Real secret requiring rotation: NONE.
- Needs allowlist: config/env.staging.json (narrow path).
- Needs incident response: NO.

## Decision

- [x] Allowlist narrow public artifacts only
- [ ] Rotate real secret and create incident record
- [ ] Stop Package G and escalate

## Root cause of gitleaks CI failure

Package F added the correct `GITLEAKS_CONFIG` env var and a path allowlist, but
the allowlist was expressed as `[[allowlists]]` (array-of-tables form). To
maximize compatibility with the gitleaks version installed by
gitleaks/gitleaks-action@v2, Package G converts the allowlist to the
widely-supported singular `[allowlist]` table form while keeping
`[extend] useDefault = true`. The anon-key file path is allowlisted narrowly.

Full-history secret scanning remains ENABLED. No secret values are recorded in
this document or committed anywhere.

## Rotation

NONE required — the only credential-like finding is the Supabase anon (public)
key, which is publishable by design and protected by RLS.
