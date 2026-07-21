# P0.4 — CI, Android Release Identity, and Deployment Reconciliation

## Requirements
- Add CI for pushes and pull requests: dependency installation, formatting check, `flutter analyze`, unit/widget tests, and release build validation where feasible.
- Fail CI on analyzer errors, test failures, unsafe formatting, or leaked secret patterns.
- Replace `com.example.albatal_store` with the real production application ID.
- Configure release signing from protected CI secrets; never commit keystores or passwords.
- Update `scripts/deploy-staging.ps1` and `.sh` with the current function list, including `paymob-initiate` and `cancel-expired-orders`, and excluding removed functions.
- Reconcile README, release-readiness, staging verification, migration, secrets, and rollback documentation.
- Document required Supabase secrets, Paymob environment, webhook/callback configuration, and safe deployment order.

## Acceptance criteria
- A clean pull request runs all required checks automatically.
- A signed release artifact uses the intended package identity.
- Staging deployment is reproducible from the documented command sequence.
- No secret or signing material is present in Git history or build logs.
