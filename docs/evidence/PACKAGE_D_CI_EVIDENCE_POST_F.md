# PACKAGE D CI EVIDENCE — POST PACKAGE F

Captured: 2026-07-27 (Africa/Cairo)

PR URL: https://github.com/mostafasayed118/albatal-store-app/pull/4
PR state: draft (manual conversion required — see note)
Previous failed candidate SHA: c2a2ef72dbfd6a087a7b5035e6a60ff8d76a6461
New candidate SHA: 8c6eac70f59b14e3c25034039679ba9e6ec39c86
Short SHA: 8c6eac7
Base branch: master

CI run URL: https://github.com/mostafasayed118/albatal-store-app/actions/runs/30246144500
CI run status: completed
CI run conclusion: failure

Checks:
- Setup & Cache: GREEN (fixed by Package F — flutter 3.44.x)
- analyze (Format & Analyze): FAILED — step 6 "Check formatting" (dart format --set-exit-if-changed)
- test (Flutter Tests): FAILED — step 7 "Enforce coverage threshold" (coverage below 70%)
- deno-test (Edge Function Tests): GREEN (fixed by Package F — --no-check --allow-read)
- secret-scan: FAILED — step 3 "Gitleaks scan (full history)"
- deploy-check (Deployment Readiness): SKIPPED (depends on failed jobs)
- android-release (Android Release Build): SKIPPED (depends on failed jobs)

Failed jobs:
- Format & Analyze (formatting)
- Flutter Tests (coverage threshold)
- Secret Scan (gitleaks)

Failure reason if any:
- Format & Analyze: `dart format --set-exit-if-changed .` finds 50 files not formatted
  to dartfmt style. Verified locally: "Formatted 179 files (50 changed)".
- Flutter Tests: Coverage enforcement requires >=70% line coverage.
  Verified locally: LINES_HIT=1925 / LINES_FOUND=4687 = 41.07% (below 70%).
  All 198 tests PASS; only the coverage gate fails.
- Secret Scan: Gitleaks still fails. The Package F fix (GITLEAKS_CONFIG env var +
  config/env.staging.json path allowlist) applies to the working-tree scan, but
  the job checks out with fetch-depth: 0 and scans FULL GIT HISTORY. Historical
  commits likely still contain the flagged content (e.g., anon key or prior blobs)
  that the path allowlist does not retroactively suppress across all historical
  paths. Requires deeper triage in Package G.

Android release job status:
skipped — did NOT run because upstream code-quality jobs failed. Not evaluated.

Additional notes:
- Package F successfully fixed 2 of the 3 originally-failing jobs
  (Setup & Cache and Edge Function Tests are now GREEN).
- Three code-quality checks fail. Per CI Decision Rules, this is a NO-GO.
- No freeze tag created. Candidate branch not modified beyond Package F commit.

PACKAGE D RESULT: NO-GO
CI VERDICT: FAIL
NEXT: PACKAGE G — CI FAILURE REMEDIATION
