# PACKAGE G — CI FAILURE REMEDIATION

Captured: 2026-07-27 (Africa/Cairo)
Status: PROPOSED — awaiting human authorization
Candidate branch: fix/package-b-freeze-hardening
Candidate SHA (failing): 8c6eac70f59b14e3c25034039679ba9e6ec39c86 (8c6eac7)
CI run: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30246144500 (failure)

## Context

Package F fixed the first wave of CI failures. On candidate SHA 8c6eac7:
- Setup & Cache: GREEN (was failing)
- Edge Function Tests: GREEN (was failing)

Three code-quality jobs still fail. Per the CI Decision Rules this is a NO-GO
and no freeze tag was created. This document scopes Package G.

DO NOT modify the candidate branch until Package G is explicitly authorized.

---

## Failure G1 — Format & Analyze: formatting (BLOCKER)

Job: Format & Analyze
Failing step: step 6 "Check formatting" — `dart format --set-exit-if-changed .`

Root cause: 50 source/test files are not formatted to dartfmt style.
Local verification: `dart format --output=none --set-exit-if-changed .`
→ "Formatted 179 files (50 changed)".

The `analyze` step itself (flutter analyze) passes — only the format check fails.

Proposed fix (needs authorization — touches lib/ and test/):
Run `dart format .` across the repo and commit the whitespace-only changes.
This is a pure formatting change, no logic change.

Alternative (CI-only, needs approval): relax the format gate to a warning.
NOT recommended — formatting is a legitimate quality gate.

Estimated scope: ~50 files, whitespace/line-wrap only.

---

## Failure G2 — Flutter Tests: coverage threshold (BLOCKER)

Job: Flutter Tests
Failing step: step 7 "Enforce coverage threshold" — requires >=70% line coverage.

Root cause: Actual line coverage is 41.07%.
Local verification: LINES_HIT=1925 / LINES_FOUND=4687 = 41.07%.
All 198 tests PASS — the test SUITE is healthy; only the coverage GATE fails.

This is a genuine gap, not a CI misconfiguration: the 70% threshold is a real
project standard and current coverage is well below it.

Two authorization paths (human decision required):

Option G2-A — Raise coverage to >=70%
Write additional tests for uncovered lib/ code. Large effort. Touches test/.
This is a real engineering task, not a mechanical CI fix.

Option G2-B — Adjust the threshold to reflect current reality (needs approval)
Lower the enforced threshold (e.g., to 40%) as an explicit, documented interim
standard, with a tracked plan to raise it. CI-only change to ci.yml.
This weakens a quality gate and must be a conscious human decision.

RECOMMENDATION: This is a governance decision. Do not silently lower the gate.
Escalate to the human owner to choose G2-A (write tests) or G2-B (documented
interim threshold). Neither should be applied without explicit approval.

---

## Failure G3 — Secret Scan: gitleaks full history (BLOCKER)

Job: Secret Scan
Failing step: step 3 "Gitleaks scan (full history)"

Root cause: The job checks out with `fetch-depth: 0` and gitleaks scans the
FULL GIT HISTORY. The Package F allowlist fix (GITLEAKS_CONFIG env var +
`config/env.staging.json` path allowlist) is correct for the current tree, but
gitleaks reports findings from HISTORICAL commits. A path-based allowlist does
not necessarily suppress a finding that appears at a different path or commit in
history, and gitleaks default rules flag high-entropy strings/JWTs across all
historical blobs.

Local high-risk probe on the CURRENT tree (Package F) found only the Supabase
anon key in config/env.staging.json (a public credential). No service-role key,
no private key, no keystore. See PACKAGE_F_GITLEAKS_SUMMARY.md.

Package G triage required:
1. Obtain the actual gitleaks findings list from the CI job log / job summary
   (not available via the public REST API; requires the run's log download or
   the job summary in the GitHub UI).
2. For each finding, classify: real secret (rotate + history-scrub) vs.
   false positive (add a commit/fingerprint allowlist entry in gitleaks.toml).
3. If all findings are the known public anon key or docs, extend the gitleaks
   allowlist using `[[allowlists]] regexes` / `commits` / `stopwords` or a
   fingerprint allowlist rather than only paths.
4. If any real secret is found in history → SECRET INCIDENT: rotate the
   credential and plan a history rewrite. This is a stop condition requiring
   explicit human authorization.

Do NOT disable or remove the secret-scan job.

---

## Proposed Package G scope (all require authorization)

| ID | Fix | Files | Type |
|----|-----|-------|------|
| G1 | `dart format .` | lib/, test/ (~50 files) | mechanical, whitespace only |
| G2 | Coverage: write tests OR document interim threshold | test/ or ci.yml | governance decision |
| G3 | Gitleaks history triage + allowlist (or incident) | .github/gitleaks.toml | security triage |

## Stop conditions to check during G3

- If gitleaks history reveals a REAL service-role key, PAYMOB key, private key,
  or keystore in any historical commit → SECRET INCIDENT → rotate + escalate.
  Do not proceed with freeze.

## Authorization needed

Package G is NOT authorized yet. Requesting human decision on:
1. G1 — approve running `dart format .` and committing whitespace changes.
2. G2 — choose: write tests to reach 70% (G2-A) OR set a documented interim
   threshold (G2-B, specify value).
3. G3 — authorize pulling the gitleaks CI log for triage, and confirm handling
   (allowlist extension vs. secret-incident path).

## Status

PACKAGE D RESULT: NO-GO
CI VERDICT: FAIL
FREEZE TAG: NOT CREATED
RELEASE STATUS: NO-GO
PACKAGE G: PROPOSED — awaiting authorization
CANDIDATE BRANCH: unchanged since 8c6eac7 (Package F)
