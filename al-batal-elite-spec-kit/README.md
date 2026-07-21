# Al Batal Elite — Production Remediation Spec Kit

**Project:** Flutter bilingual fabric-commerce app with Supabase/PostgreSQL and Paymob
**Baseline:** 145 Dart files, 153/153 tests passing, `flutter analyze` clean
**Primary objective:** Remove the Paymob credential leak and close the highest-risk production gaps without breaking COD, checkout, localization, or existing tests.

## Governing rule
No provider secret, access token, payment authentication token, or internal error detail may be returned to a mobile client. Payment initiation must remain server-side and must return only the minimum client-safe checkout data.

## Execution order
1. `01-paymob-token-leak.md` — emergency security remediation
2. `02-payment-flow-hardening.md` — verify the active card-payment path end to end
3. `03-database-and-edge-security.md` — RPC authorization, function exposure, RLS review
4. `04-ci-release-and-deployment.md` — CI/CD, Android identity/signing, deployment reconciliation
5. `05-cloud-sync-and-production-readiness.md` — durable data ownership and release blockers
6. `06-verification-plan.md` — independent review and staging evidence

## Model allocation
- **MiMo v2.5 :** implementation of architecture-sensitive changes; preserve uncommitted work.
- **MiMo v2.5:** independent security review of Edge Functions, SQL, RLS, secrets, and deployment.
- **MiMo v2.5:** independent Flutter regression review covering navigation, payment states, disposal, routing, RTL/localization, COD, and tests.

## Definition of done
A remediation is not complete because local tests pass. It is complete only when source, migrations, deployment scripts, documentation, automated tests, and staging verification agree, and the evidence is recorded in the final report.
