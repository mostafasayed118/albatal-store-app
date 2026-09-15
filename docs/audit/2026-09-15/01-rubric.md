# Al Batal Elite — Audit Rubric, Weights, and Scoring Rules (v1.0, frozen 2026-09-15)

This rubric is published **before** scoring. The re-audit after fixes uses the identical document.

## Dimensions and weights

| # | Dimension | Weight | Rationale |
|---|---|---|---|
| 1 | Maintainability | 20% | 29.4k-line app still in active feature development; future-change cost dominates lifecycle cost |
| 2 | Clean architecture | 20% | The codebase *claims* feature-first Clean Architecture; adherence is cheap to verify and expensive to lose |
| 3 | Code quality | 20% | Smells/duplication/dead code are the daily friction; equal weight to the two above |
| 4 | Security | 25% | Commerce app: payments (Paymob/InstaPay), PII, auth. Highest stakes, therefore highest weight |
| 5 | Performance | 15% | Real but the app is CRUD/browsing; no measured hotspots at baseline, so slightly lower weight |

Sum = 100%. Overall = Σ(scoreᵢ × weightᵢ), rounded to one decimal.

## Score anchors (0–10)

| Score | Meaning |
|---|---|
| 10 | No verified findings in this dimension that a reasonable senior reviewer would act on; harness green; evidence complete |
| 9 | Findings exist but all are minor/nit-level, explicitly waived with justification, or outside first-party code |
| 7–8 | A handful of non-critical findings with clear remediation paths; no user-facing or data risk |
| 4–6 | Systemic issues (recurring anti-pattern, weak boundary) or several high-severity findings |
| 1–3 | Critical findings present (exploitable, data-loss, build/test broken) or dimension largely unmanaged |
| 0 | Dimension unmanaged and actively harmful |

Rules:
- Every deduction must cite file:line evidence verified by the auditor (no hearsay).
- Generated code (`lib/generated/**`) and vendored/platform boilerplate are excluded except where first-party code calls them unsafely.
- The verifier re-opens every cited location before accepting the score.

## Verification harness (definition of "green")

1. `flutter analyze --no-pub` → `No issues found!`
2. `flutter test` → all tests pass (baseline: 875 pass / 9 fail on `master` WIP tree)
3. `dart format --set-exit-if-changed --output=none lib test` → exit 0
4. `flutter build apk --debug` → build succeeds (run once per verification phase)
5. `flutter pub outdated` recorded; no known-vulnerable pinned versions (informational)
6. Secret sweep: `git diff --check` + tracked-file grep for `.env` values, `eyJ…` tokens, keystore paths → clean

## Baseline freeze (2026-09-15, commit `5ef935c` + owner-WIP snapshot `5fd16e9`)

- analyze: 4 warnings (unused imports, truncated test file)
- test: **875 passed / 9 failed** (1 load failure + 8 harness failures)
- format: 7 files would be reformatted (4 in `lib/`)
- Raw logs: `.openclaw/tmp/audit/baseline/{analyze,test_full,format}.txt`
