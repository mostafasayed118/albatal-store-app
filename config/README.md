# Build-time configuration

This directory holds **build-time** environment JSON files consumed by
`flutter run` / `flutter build` via `--dart-define-from-file`.

## Why this exists

Before the P0 security remediation the app packaged `.env` as a Flutter
asset, which baked Supabase + Paymob secrets into the APK. That was a
client trust-boundary break.

The Flutter client now receives only these values, injected at compile
time:

| Variable            | Safe for client? | Source                  |
|---------------------|------------------|-------------------------|
| `SUPABASE_URL`      | yes (public)     | `config/env.*.json`     |
| `SUPABASE_ANON_KEY` | yes (RLS-backed) | `config/env.*.json`     |
| `SENTRY_DSN`        | yes (public id)  | `config/env.*.json`     |

The following are **never** present in the Flutter build and must only
live in Supabase Edge Function secrets (`supabase functions secrets set`):

- `PAYMOB_API_KEY`
- `PAYMOB_INTEGRATION_ID`
- `PAYMOB_HMAC_SECRET`
- `PAYMOB_IFRAME_ID`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SCHEDULER_SECRET`

## Files

| File                    | Purpose                              |
|-------------------------|--------------------------------------|
| `env.staging.json`      | Staging build config (committed, placeholders) |
| `env.production.json`   | Production build config (committed, placeholders) |

## How to use

1. Copy a template and fill in real values **locally** (do not commit
   real values):

   ```bash
   cp config/env.staging.json config/env.staging.local.json
   # edit config/env.staging.local.json with real values
   ```

2. Build with the filled-in file:

   ```bash
   # Staging
   flutter run --dart-define-from-file=config/env.staging.local.json
   flutter build apk --release --dart-define-from-file=config/env.staging.local.json

   # Production
   flutter build apk --release --dart-define-from-file=config/env.production.local.json
   ```

## Gitignore

`config/env.*.local.json` is gitignored so you can drop real values in
without risking a commit. See `.gitignore`.

The committed `env.staging.json` / `env.production.json` contain only
placeholders.
