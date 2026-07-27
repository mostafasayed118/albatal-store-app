# Secret Hygiene Runbook — Al Batal Elite

> **Owner:** Security Operations  
> **Last updated:** 2026-07-25  
> **Applies to:** All developers, CI/CD pipelines, and deployment workflows

---

## Table of Contents

1. [Developer Machine Rules](#1-developer-machine-rules)
2. [Where Secrets Should Live](#2-where-secrets-should-live)
3. [Rotation Procedures](#3-rotation-procedures)
4. [Incident Response — Accidental Commit](#4-incident-response--accidental-commit)
5. [Staging vs. Production Separation](#5-staging-vs-production-separation)

---

## 1. Developer Machine Rules

These rules are **non-negotiable**. Violations must be treated as security incidents.

### 1.1 Never Force-Add Secrets

```bash
# FORBIDDEN — bypasses .gitignore
git add -f .env
git add -f release-keystore.jks
git add -f key.properties
```

If a file is gitignored and you need it tracked, that means the file should not
exist in the repo. Talk to the team lead instead.

### 1.2 Never Commit `.env` Files

The following files must **never** appear in `git log`:

| File | Contains |
|------|----------|
| `.env` | Local dev secrets |
| `.env.staging` | Staging overrides |
| `.env.production` | Production overrides |
| `secrets-*.env` | Any ad-hoc secret files |

The `.gitignore` already excludes `.env` and `.env.*` (except `.env.example`).
Verify before every push:

```bash
git status --porcelain | grep -i '\.env'
# Must return empty
```

### 1.3 Never Commit Keystores or Key Properties

| File | Contains |
|------|----------|
| `release-keystore.jks` | Android signing key |
| `*.keystore` | Any keystore |
| `android/key.properties` | Keystore path + passwords |

The `.gitignore` excludes `*.jks`, `*.keystore`, and `android/key.properties`.
If you see these in `git status`, **stop immediately**.

### 1.4 Never Share Secrets via Chat or Email

- Do not paste keys in Slack, Teams, WhatsApp, or email.
- Do not screenshot secrets.
- Do not share `.env` files via file-sharing services.
- Use your team's approved secrets manager (see Section 2).

**Approved sharing method:** Extract from the password manager or Supabase
dashboard directly on the recipient's machine. If remote, use a one-time
sharing mechanism approved by the team lead.

---

## 2. Where Secrets Should Live

### 2.1 GitHub Actions Secrets

Used for CI/CD pipelines. Set in **Settings → Secrets and variables → Actions**.

| Secret name | Purpose | Environment |
|-------------|---------|-------------|
| `SUPABASE_ACCESS_TOKEN` | CLI auth for migrations/deploy | All |
| `SUPABASE_PROJECT_ID` | Target project ref | All |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Function deploys | All |

### 2.2 Supabase Edge Function Secrets

Server-side secrets set via the Supabase CLI. These are **never** visible in
client code or Flutter builds.

```bash
supabase functions secrets set PAYMOB_API_KEY=<value>
supabase functions secrets set PAYMOB_INTEGRATION_ID=<value>
supabase functions secrets set PAYMOB_HMAC_SECRET=<value>
supabase functions secrets set PAYMOB_IFRAME_ID=<value>
supabase functions secrets set SUPABASE_SERVICE_ROLE_KEY=<value>
supabase functions secrets set SCHEDULER_SECRET=<value>
```

Verify with:

```bash
supabase functions secrets list
```

### 2.3 Password Manager

Store the following in your team password manager (1Password, Bitwarden, etc.):

| Item | Notes |
|------|-------|
| Paymob sandbox API key | Per-developer access |
| Paymob production API key | Lead-only access |
| Paymob HMAC secret | Lead-only access |
| Supabase dashboard password | Per-developer |
| Android keystore password | Lead-only access |
| Android keystore backup | Encrypted vault, lead-only |

### 2.4 OS Keychain

For local development, store credentials in the OS keychain when possible:

- **macOS:** `security add-generic-password -a $USER -s "albatal-supabase" -w`
- **Windows:** Use Credential Manager or `cmdkey /generic:albatal-supabase /user:<user> /pass:<pass>`
- **Linux:** `secret-tool store --label="Al Batal Supabase" service albatal-supabase`

The Flutter app does **not** read from the OS keychain at runtime. This is
for developer convenience only (e.g., scripting deployments).

---

## 3. Rotation Procedures

### 3.1 Supabase Anon Key

The anon key is public by design (RLS enforces access). Rotation is rare
and low-urgency.

1. Go to **Supabase Dashboard → Settings → API**.
2. Click **Regulate anon key** (or use the CLI).
3. Update `config/env.staging.json` and `config/env.production.json`.
4. Rebuild and redeploy the Flutter app.
5. Old key stops working immediately.

### 3.2 Supabase Service Role Key

This key bypasses RLS. Compromise = full database access.

1. Go to **Supabase Dashboard → Settings → API → service_role key**.
2. Click **Rotate** (or generate a new key).
3. Update all Edge Function secrets:
   ```bash
   supabase functions secrets set SUPABASE_SERVICE_ROLE_KEY=<new-key>
   ```
4. Update GitHub Actions secrets if used for deploys.
5. Notify the team immediately.
6. Audit Supabase logs for unauthorized usage in the last 24h.

### 3.3 Paymob Sandbox Keys

1. Log in to [Paymob Dashboard](https://dashboard.paymob.com).
2. Navigate to **Developers → API Keys**.
3. Regenerate the sandbox API key.
4. Update Edge Function secrets:
   ```bash
   supabase functions secrets set PAYMOB_API_KEY=<new-sandbox-key>
   ```
5. Test checkout flow in staging.
6. Old key deactivates immediately.

### 3.4 Paymob Production Keys

**Requires team lead approval before rotation.**

1. Log in to Paymob Dashboard (production account).
2. Navigate to **Developers → API Keys**.
3. Regenerate the production API key.
4. Update Edge Function secrets on the **production** Supabase project:
   ```bash
   supabase functions secrets set PAYMOB_API_KEY=<new-prod-key> --project-ref <prod-project-id>
   ```
5. Test a real transaction (minimum amount).
6. Update the password manager entry.
7. Notify stakeholders (see Section 4.4).

### 3.5 HMAC Secret

Used to verify Paymob webhook signatures. Compromise = fake payment confirmations.

1. Generate a new 32-byte random hex string:
   ```bash
   openssl rand -hex 32
   ```
2. Update Edge Function secrets:
   ```bash
   supabase functions secrets set PAYMOB_HMAC_SECRET=<new-hex>
   ```
3. Update the HMAC secret in the Paymob dashboard (if Paymob requires it
   on their side — check their docs).
4. Test the webhook callback endpoint.

### 3.6 Keystore Password

1. Generate a new strong password (20+ chars).
2. Re-export the keystore with the new password:
   ```bash
   keytool -storepasswd -keystore release-keystore.jks
   ```
3. Update `android/key.properties` on every developer machine.
4. Update CI/CD secrets if the keystore is used in GitHub Actions.
5. Back up the new keystore + password in the encrypted vault.

---

## 4. Incident Response — Accidental Commit

If a secret is committed to git (even on a branch), follow this procedure
**immediately**. Do not wait.

### 4.1 Rotate Immediately

Rotate **every** secret that was exposed. Do not assess "how much was
exposed" — just rotate. This takes minutes and prevents hours of analysis.

| Secret | How to rotate |
|--------|---------------|
| Supabase anon key | Dashboard → Settings → API → Regenerate |
| Supabase service role key | Dashboard → Settings → API → Rotate |
| Paymob API key | Paymob Dashboard → Developers → API Keys |
| Paymob HMAC secret | `openssl rand -hex 32` → update Edge Functions |
| Keystore password | `keytool -storepasswd` → redistribute |

### 4.2 Remove from Git History

If the secret made it to a shared branch (main, develop, or any PR):

```bash
# Option A: BFG Repo-Cleaner (recommended — fast, simple)
bfg --delete-files .env
bfg --delete-files *.jks
bfg --delete-files key.properties
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Option B: git-filter-repo (if BFG is unavailable)
git filter-repo --path .env --invert-paths
git filter-repo --path *.jks --invert-paths
git filter-repo --path key.properties --invert-paths
```

**Force-push** after cleaning (coordinate with the team first):

```bash
git push origin --force --all
git push origin --force --tags
```

Notify all developers to re-clone or run:

```bash
git fetch origin
git reset --hard origin/main
```

### 4.3 Audit Access

After rotation:

1. Check **Supabase Dashboard → Logs** for any queries using the old keys.
2. Check **Paymob Dashboard → Transactions** for unauthorized charges.
3. Check **GitHub → Settings → Security log** for any suspicious activity.
4. Check **git log** for who committed the secret and when.
5. Check if the branch was pushed to any remote (fork, PR, etc.).

### 4.4 Notify Stakeholders

Send a message to the team channel:

```
SECURITY INCIDENT — Secret Exposed

What:   [secret type] was committed to [branch/PR]
When:   [timestamp]
Impact: [brief assessment]
Actions taken:
  1. All affected secrets rotated
  2. Git history cleaned
  3. Access audit completed
  4. [any other actions]

No further action required from team members unless you noticed
unusual activity.
```

---

## 5. Staging vs. Production Separation

### 5.1 Current State

The project currently uses a **single Supabase project** for both staging
and production. This means staging and production share:

- Same database
- Same anon key
- Same service role key
- Same Edge Function secrets

This is acceptable for early development but **must change before launch**.

### 5.2 Target Architecture

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│         STAGING             │     │        PRODUCTION           │
├─────────────────────────────┤     ├─────────────────────────────┤
│ Supabase project: albatal-staging │ Supabase project: albatal-prod   │
│ Anon key: staging-anon      │     │ Anon key: prod-anon         │
│ Service role: staging-svc   │     │ Service role: prod-svc      │
│ Paymob: sandbox keys        │     │ Paymob: production keys     │
│ DB: test data only          │     │ DB: real customer data      │
│ Edge Functions: sandbox     │     │ Edge Functions: production  │
└─────────────────────────────┘     └─────────────────────────────┘
```

### 5.3 Environment Separation Rules

| Rule | Staging | Production |
|------|---------|------------|
| Supabase project | Separate project | Separate project |
| Anon key | Unique to staging | Unique to production |
| Service role key | Unique to staging | Unique to production |
| Paymob keys | **Sandbox** | **Production** |
| HMAC secret | Unique to staging | Unique to production |
| Database data | Faker/test data only | Real customer data |
| Edge Function secrets | Set on staging project | Set on production project |
| Access | All developers | Lead + CI/CD only |
| Flutter build | `--dart-define-from-file=config/env.staging.json` | `--dart-define-from-file=config/env.production.json` |

### 5.4 Migration Checklist

When splitting to separate Supabase projects:

- [ ] Create `albatal-staging` Supabase project
- [ ] Create `albatal-prod` Supabase project
- [ ] Run migrations on both: `supabase db push --project-ref <staging-ref>`
- [ ] Set Edge Function secrets on each project independently
- [ ] Generate unique anon + service role keys for each
- [ ] Update `config/env.staging.json` with staging keys
- [ ] Update `config/env.production.json` with production keys
- [ ] Set up separate GitHub Actions environments (staging / production)
- [ ] Set Paymob to **sandbox** on staging, **production** on prod
- [ ] Test full checkout flow on both environments
- [ ] Update this runbook with new project refs

---

## Appendix A: Quick Reference — What Goes Where

| Secret | Client (Flutter) | Edge Functions | GitHub Actions | Password Manager |
|--------|:-:|:-:|:-:|:-:|
| Supabase URL | ✅ | ✅ | ✅ | — |
| Supabase anon key | ✅ | ✅ | — | — |
| Supabase service role key | ❌ | ✅ | ✅ | ✅ |
| Paymob API key | ❌ | ✅ | — | ✅ |
| Paymob integration ID | ❌ | ✅ | — | ✅ |
| Paymob HMAC secret | ❌ | ✅ | — | ✅ |
| Paymob iframe ID | ❌ | ✅ | — | ✅ |
| SCHEDULER_SECRET | ❌ | ✅ | — | ✅ |
| Sentry DSN | ✅ | — | — | — |
| Keystore password | ❌ | — | ✅ | ✅ |
| Keystore file (`.jks`) | ❌ | — | ✅ (encrypted) | ✅ (encrypted) |

## Appendix B: Verification Commands

Run these before every push to ensure no secrets leak:

```bash
# Check for .env files in git
git ls-files | grep -i '\.env'
# Expected: only .env.example

# Check for keystores
git ls-files | grep -iE '\.(jks|keystore)$'
# Expected: empty

# Check for key.properties
git ls-files | grep -i 'key\.properties'
# Expected: empty

# Grep for common secret patterns in tracked files
git grep -iE '(api_key|secret|password|token)\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{20,}' -- '*.dart' '*.ts' '*.json'
# Expected: only placeholder/template values (e.g. "your-key-here")
```

## Appendix C: Emergency Contacts

| Role | Who | When to contact |
|------|-----|-----------------|
| Security lead | [Team lead name] | Any secret exposure |
| Supabase admin | [Name] | Supabase key rotation |
| Paymob admin | [Name] | Paymob key rotation |
| CI/CD admin | [Name] | GitHub Actions secret updates |
