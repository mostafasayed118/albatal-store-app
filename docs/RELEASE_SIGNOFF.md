# RELEASE_SIGNOFF.md — Four-Party Release Sign-Off

**Project:** Al Batal Elite  
**Review date:** 2026-07-26  
**Current verdict:** **GO** — 2026-08-24
**Phase 0 planning status:** **APPROVED FOR PLANNING AND CONTROLLED EXECUTION**  
**Phase 0 approval reference:** `PHASE0-ALBATAL-2026-07-26-001`  
**Release sign-off status:** **SIGNED — GO APPROVED (2026-08-24, solo-owner four-capacity, ref `RELEASE-AC69C54-2026-08-24`)**

## Phase 0 authorization record

| Field | Value |
|---|---|
| Approved by | Mustafa Sayed |
| Role | Solo Owner — Product Owner, Engineering Lead, QA Lead, and Security Owner |
| Date | 2026-07-26 |
| Approval reference | `PHASE0-ALBATAL-2026-07-26-001` |
| Authorization | Controlled remediation planning and verification only |

This authorization does not approve production deployment, public launch,
Paymob production-key cutover, beta release, or production migration promotion.

## Release candidate identity

| Field | Value |
|---|---|
| Release candidate SHA | `ac69c54c91ca9409f5ec30fabcf6a35c2001956f` — master tip; shipped code content-identical to frozen `fc0b2a2` (delta docs/config only) |
| Branch / tag | `master` @ `ac69c54` |
| Staging project reference | `zvpjngdgbpnkkqrorkul` (eu-west-1) — authorization `STAGING-E2E-ZVPJ-AC69C54-2026-08-23` |
| App version / build number | 0.1.0 / versionCode 1 (`com.albatal.elite`) |
| Android artifact filename | `app-release.apk` (79,311,899 bytes, CI artifact `release-apk`) |
| Android artifact SHA-256 | `970469542a77822a11372cacf70741d35ff59067b9f4647013d0df5495f404a0` (double-computed) |
| CI workflow run | run `32646592228` @ head `ac69c54`, success, 2026-08-23T14:49:03Z (7/7 incl. signed Android build) |
| Play Internal Testing release | N/A WITH REASON — not yet uploaded; artifact ready for manual upload at owner's discretion |

## Staging acceptance evidence links

- Migration ledger and parity: 29/29 applied on `zvpjng…`; `docs/evidence/isolation-2026-08-23/README.md`
- RPC definitions and grants: `docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md` (matrix); live behavior re-proven via suites below
- RLS flags and policy catalog: adversarial **44/44 PASS** on new staging — `docs/evidence/e2e-2026-08-23/db-suite-results.md`
- Edge Function deployment and JWT settings: 5/5 deployed; `paymob-callback` verify_jwt OFF (live-proven); CORS secret repaired — same file
- Secret names-only inventory: 14 names on staging incl. ratified 7 (`supabase secrets list`, values hashed; never recorded)
- Explicit CORS probes: forged-callback reaches function HMAC layer (401 Invalid signature) with and without bearer
- COD E2E with SQL before/after state: contract suite **14/14** (`run_cod_payment.mjs`) + T-RC13 COD-vs-expiry — `db-suite-results.md`
- Paymob sandbox E2E: F1–F4 **21/21** + initiate chain **8/8** + REAL transaction closed (provider txn `521025723` → order paid) — §LIVE END-TO-END PAYMENT
- Invalid-HMAC, amount-mismatch, duplicate, and late-callback evidence: probes A/B/C PASS + sandbox F2–F4 — `db-suite-results.md`
- Race-condition and exactly-once stock evidence: T-RC01–T-RC14 **53/53 PASS** (first full execution) — same file

## Android artifact evidence links

- Signed APK/AAB: CI artifact `release-apk` → `app-release.apk` (79,311,899 bytes), run `32646592228`
- `apksigner verify` output: signing proven fail-closed in `ci.yml` job `android-release` (keystore decode + key.properties + `flutter build apk --release`); v2-scheme signature verified in prior proof `docs/evidence/eebcc4d/RELEASE_APK_PROOF.md`, same pipeline
- Package `com.albatal.elite`: aapt badging — versionCode 1, versionName 0.1.0, minSdk 24, targetSdk 36
- `debuggable=false`: release build type (non-debug pipeline; prior RELEASE_APK_PROOF.md)
- Build provenance and checksum: SHA-256 `970469542a77822a11372cacf70741d35ff59067b9f4647013d0df5495f404a0` (two passes agree) — `docs/evidence/e2e-2026-08-23/android-artifact-retie.md`

## Security evidence links

- Full-history secret scan: gitleaks 7/7 green incl. Secret Scan job (CI `32646592228`)
- Client-bundle secret inspection: no `.env` in APK; anon-key-only config (prior RELEASE_APK_PROOF.md + tonight's artifact same pipeline)
- RLS adversarial results: **44/44 PASS** on `zvpjng…` — `docs/evidence/e2e-2026-08-23/db-suite-results.md`
- RPC authorization results: COD contract 14/14 incl. not_owner/authentication_required rejections; checkout pricing enforced (RLS 4.3)
- Paymob HMAC and CORS results: forged→401; valid-signed real txn processed; CORS secret repaired + probed — `db-suite-results.md`

## Observability evidence links

- Sentry controlled test event: event `1ef12b03…` (emulator probe) + store check `6e8f50ef…`; **owner dashboard CONFIRMED 2026-08-24**, project `4511772249292800` — `sentry-live-event.md`
- PII-scrubbing verification: 14 scrub unit tests green in 247-test suite (token/secret/card/cvv/auth/address/email/phone/password redaction)
- Alert thresholds and incident ownership: N/A WITH REASON — alerting rules not yet defined; tracked as post-GO operational task for the solo owner

## Final evidence-dependent release signatures

Under the approved solo-owner model, Mustafa Sayed occupies all four governance roles. These release signatures remain pending until the evidence above exists and is reviewed against an immutable candidate SHA; Phase 0 approval does not pre-sign unavailable evidence.

| Approval area | Required role | Name | Decision | Signature / approval reference | Date |
|---|---|---|---|---|---|
| Product scope and business readiness | Product Owner | Mustafa Sayed | **APPROVED** | `RELEASE-AC69C54-2026-08-24` (chat "sign", 2026-08-24) | 2026-08-24 |
| Engineering and implementation readiness | Engineering Lead | Mustafa Sayed | **APPROVED** | `RELEASE-AC69C54-2026-08-24` (chat "sign", 2026-08-24) | 2026-08-24 |
| Staging and regression acceptance | QA Lead | Mustafa Sayed | **APPROVED** | `RELEASE-AC69C54-2026-08-24` (chat "sign", 2026-08-24) | 2026-08-24 |
| Security and operational risk acceptance | Security Owner | Mustafa Sayed | **APPROVED** | `RELEASE-AC69C54-2026-08-24` (chat "sign", 2026-08-24) | 2026-08-24 |

## Final GO/NO-GO decision

| Field | Value |
|---|---|
| Final decision | **GO** |
| Decision date | 2026-08-24 |
| Decision authority / reference | Mustafa Sayed — Solo Owner (all four capacities) — `RELEASE-AC69C54-2026-08-24` (chat "sign") — candidate SHA `ac69c54` on staging `zvpjngdgbpnkkqrorkul` — `STAGING-E2E-ZVPJ-AC69C54-2026-08-23` |
| Exceptions accepted | `NONE` — migration 027 historical item resolved (see §final paragraph) |
| Follow-up actions | Post-GO: Play Internal Testing upload (when owner decides) · alerting rules definition · removal of diagnostic paid artifacts on staging when no longer needed · future sandbox transaction #6+ re-verification is automatic (latest #5 proved hands-off) — tracked in `STATE.md` |

The decision may change to `GO` only when all required evidence is tied to an
immutable candidate SHA, all mandatory gates pass with no unresolved P0/P1
exception, and Product Owner, Engineering Lead, QA Lead, and Security Owner
have all signed.

The migration 027 payment-insert contradiction (historical) was resolved by
the `payments_insert_own` policy removal (migration 014-era repair; verified in
`docs/ACCEPTANCE_EVIDENCE.md`) and re-proven live on staging: authenticated
direct payment INSERT denied (RLS adversarial 4.1), callback/initiate paths are
the only writers (F1–F4 + real transaction).

