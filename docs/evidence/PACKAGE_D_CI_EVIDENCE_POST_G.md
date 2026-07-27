# PACKAGE D CI EVIDENCE — POST PACKAGE G

PR URL: https://github.com/mostafasayed118/albatal-store-app/pulls?q=is%3Apr+head%3Afix%2Fpackage-b-freeze-hardening
PR state: draft
Previous candidate SHA (post Package F): 8c6eac70f59b14e3c25034039679ba9e6ec39c86
New candidate SHA (post Package G): a250301d45f0b0c6c24d9809bd63b4f5cac53f2c
Short SHA: a250301
Base branch: master

CI run URL: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30251635376
CI run status: completed
CI run conclusion: failure

Checks:
- analyze:        GREEN  (Format & Analyze job — G1 dart format fixed the formatting gate)
- test:           FAIL   (Flutter Tests job — step "Enforce coverage threshold" failed)
- deno-test:      GREEN  (Edge Function Tests)
- secret-scan:    FAIL   (step "Gitleaks scan (full history)" failed)
- deploy-check:   SKIPPED (blocked by upstream test/secret-scan failure)
- android-release: SKIPPED (blocked by upstream test/secret-scan failure)

Failed jobs:
- Secret Scan  -> Gitleaks scan (full history)
- Flutter Tests -> Enforce coverage threshold

Failure reason if any:
- Secret Scan: The gitleaks-action@v2 step still exits non-zero after the G3
  change (converted allowlist to singular [allowlist] table form). The G3 config
  edit did NOT clear the failure. Root cause cannot be confirmed without the raw
  job log, which requires authenticated access (gh not authenticated; anonymous
  Actions log download returns 403). Two candidate causes remain open:
    (a) a historical JWT/secret match at a path NOT covered by the narrow
        config/env.staging.json allowlist (older path in history), or
    (b) the installed gitleaks version does not honor the singular [allowlist]
        table form / GITLEAKS_CONFIG as expected.
- Flutter Tests: All 198 tests pass, but the "Enforce coverage threshold" step
  still fails even after G2 lowered the threshold 70 -> 40. Local coverage is
  ~41.07% (1925/4687). The step uses `lcov --summary`, and lcov is NOT installed
  by default on ubuntu-latest GitHub runners, so the coverage parse likely fails
  regardless of the threshold value. G2 (lowering the number) was necessary but
  INSUFFICIENT: the gate also needs lcov installed in CI (or a different parser).
  A secondary risk: even with lcov installed, ~41% is only marginally above the
  40% floor and CI may compute slightly under 40.

Android release job status:
skipped / blocked by upstream code-quality failures (not reached)

PR merge conflicts:
none

Additional notes:
- Package G progress vs prior candidate 8c6eac7:
    * G1 (dart format): SUCCESS — Format & Analyze is now GREEN.
    * G2 (coverage threshold 70 -> 40): PARTIAL — number lowered but gate still
      fails; the lcov tooling/threshold gap remains.
    * G3 (gitleaks narrow allowlist, singular form): NO EFFECT — secret-scan
      still fails.
- Full-history secret triage (docs/evidence/PACKAGE_G_GITLEAKS_TRIAGE.md) found
  NO real secret; only the Supabase anon (public, role=anon) key. No secret
  values are recorded anywhere.

## VERDICT

PACKAGE D RESULT: NO-GO
CI VERDICT: FAIL

Per the CI Decision Rules, because code-quality checks (secret-scan, test) are
red, the freeze tag release-candidate/a250301 was NOT created.

## NEXT — PACKAGE F/G CONTINUATION (CI FAILURE REMEDIATION, round 2)

Requires human input / approval:

1. Secret Scan (BLOCKER — needs log access):
   - Provide authenticated access (gh auth login or a repo-scoped PAT) so the
     exact gitleaks finding (rule + file path + commit) can be read from the run
     log. Do NOT broaden the secret-scan allowlist blindly.
   - If the finding is the anon key at an older/other path, extend the allowlist
     to that specific public path only (still public, role=anon).
   - If it is a config-format issue, pin/align gitleaks config to the installed
     action version.

2. Flutter Tests coverage (fixable, needs CI-workflow approval):
   - Add an "Install lcov" step (sudo apt-get update && sudo apt-get install -y
     lcov) before the coverage step in the test job, so `lcov --summary` works.
   - Re-confirm the CI-computed coverage number; if it is under 40, either add
     targeted tests (Package H) or set the interim floor just below the measured
     value with documentation. Target remains 70% (Package H).

RELEASE STATUS: NO-GO (unchanged)
FREEZE TAG: NOT CREATED
