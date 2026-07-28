# Package H — Gitleaks Findings

CI run: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30251635376
Local gitleaks version: 8.24.3 (matches gitleaks/gitleaks-action@v2 in CI)
Config used: .github/gitleaks.toml
Evidence source: authenticated `gh run view 30251635376 --log-failed` + local
full-history `gitleaks detect --redact` (77 commits scanned).

Note: CI (PR event) scanned only the PR commit range and reported 2 findings
(lines 84, 98). The local full-history scan surfaced all 5 historical matches
of the same class. All are the same two non-secret patterns.

## Findings

| Rule ID | File path | Commit SHA | Redacted match summary | Classification | Action |
|---|---|---|---|---|---|
| generic-api-key | supabase/tests/test_026_forward_repair.sql:84 | f2fc1049 | `...WHERE idempotency_key = 'REDACTED'` (literal `test-idempotency-001`) | False positive (test fixture) | fingerprint ignore |
| generic-api-key | supabase/tests/test_026_forward_repair.sql:98 | f2fc1049 | same literal test key | False positive (test fixture) | fingerprint ignore |
| generic-api-key | supabase/tests/test_026_forward_repair.sql:106 | f2fc1049 | same literal test key | False positive (test fixture) | fingerprint ignore |
| generic-api-key | supabase/tests/test_026_forward_repair.sql:143 | f2fc1049 | same literal test key | False positive (test fixture) | fingerprint ignore |
| generic-api-key | test/product_detail_test.dart:85 | 4cd9b3ef | hex color literal `imageColor: 0xFF000000` | False positive (color constant) | fingerprint ignore |

## Classification

- Public/non-secret: none (Supabase anon key already covered by gitleaks.toml path allowlist)
- False positive: ALL 5 findings (4 SQL test-fixture idempotency keys + 1 Dart hex color)
- Real secret requiring rotation: NONE
- Needs narrow allowlist: no (fingerprint ignore chosen — more surgical)
- Needs .gitleaksignore fingerprint: YES (5 fingerprints)
- Needs incident response: NO

## Decision

- [x] Fingerprint ignore approved (`.gitleaksignore`, 5 fingerprints)
- [ ] Narrow allowlist approved (not used; fingerprints preferred)
- [ ] Redaction required (no secret to redact)
- [ ] Rotation required (no real secret)
- [ ] Stop and escalate (not triggered)

## Why fingerprints (not path allowlist)

The two files (`supabase/tests/test_026_forward_repair.sql`,
`test/product_detail_test.dart`) are real source/test files that SHOULD keep
being scanned for future changes. A path allowlist would blind gitleaks to any
future real secret added to those paths. Fingerprints suppress ONLY these exact
historical false-positive matches while keeping full scanning and all default
rules enabled.
