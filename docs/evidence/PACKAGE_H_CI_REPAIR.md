# PACKAGE H — CI GATE REPAIR

Authorization: PACKAGE H AUTHORIZATION — CI GATE REPAIR (L2 bounded)
Candidate branch: fix/package-b-freeze-hardening
Failed CI run repaired: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30251635376
Pre-repair HEAD: 0b59c8d
Release verdict: NO-GO (unchanged)

## Goals

1. Make the secret-scan gate pass WITHOUT weakening secret scanning.
2. Make the coverage gate pass by installing lcov in CI while keeping the
   interim 40% threshold.

## Blocker 1 — Secret Scan / Gitleaks

Root cause: gitleaks `generic-api-key` rule produced FALSE POSITIVES on
non-secret test fixtures. The Package G change (path allowlist for the public
anon key) did not cover these files, so the scan still failed.

Exact finding (authenticated CI log + local reproduction with gitleaks 8.24.3):
- generic-api-key x4 in supabase/tests/test_026_forward_repair.sql
  (literal `idempotency_key = 'test-idempotency-001'`)
- generic-api-key x1 in test/product_detail_test.dart (hex color `0xFF000000`)

Classification: ALL false positives. No real secret. No rotation needed.
Full detail: docs/evidence/PACKAGE_H_GITLEAKS_FINDINGS.md

Remediation: added `.gitleaksignore` with the 5 exact fingerprints. This is
surgical — full-history scanning and the default rule set remain ENABLED; only
these specific historical non-secret matches are suppressed. No path allowlist
broadening. No secret values committed (fingerprints contain none).

Local verification (gitleaks 8.24.3, committed config + .gitleaksignore):
- Before: 5 leaks found
- After:  0 leaks found  (see verification section)

## Blocker 2 — Coverage Gate / lcov

Root cause: the "Enforce coverage threshold" step parses `coverage/lcov.info`
using `lcov --summary`, but `lcov` is NOT preinstalled on ubuntu-latest runners.
The command failed (empty COVERAGE), so the step exited non-zero regardless of
the numeric threshold. Package G lowering 70->40 was necessary but insufficient.

Remediation: added an "Install lcov" step to the `test` job (Ubuntu-only,
`apt-get install -y lcov`) BEFORE the coverage steps. Interim threshold kept at
40% exactly (target 70% deferred to Package H Coverage Uplift before beta/prod).
Coverage gate is NOT disabled and threshold is NOT removed/raised.

## Files changed

- .github/workflows/ci.yml          (add Install lcov step; threshold unchanged at 40)
- .gitleaksignore                    (new; 5 confirmed-FP fingerprints)
- docs/evidence/PACKAGE_H_GITLEAKS_FINDINGS.md (new; triage record)
- docs/evidence/PACKAGE_H_CI_REPAIR.md         (this file)

No changes to lib/, android/, supabase/ logic, config/, payment, migration, or
Edge Function code. No secrets set. No force push. No tag. No merge.

## Verification

- gitleaks detect (local, 8.24.3, with .gitleaksignore): 0 leaks (was 5)
- flutter analyze: No issues found (unchanged since Package G; no lib/ edits)
- flutter test: 198/198 passing (unchanged since Package G; no lib/test logic edits)
- YAML: .github/workflows/ci.yml parses successfully

## Result

Local gates green. Pushed for a fresh CI run. New CI evidence recorded in
docs/evidence/PACKAGE_D_CI_EVIDENCE_POST_H.md once the run completes.
