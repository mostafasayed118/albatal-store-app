# Verification and Review Plan

## Implementation pass — MiMo v2.5
- Inspect the current working tree first; preserve unrelated uncommitted work.
- Implement P0.1–P0.4 in small, reviewable commits or clearly separated diffs.
- Run formatter only on touched files initially.
- Run analyzer, all tests, SQL validation, and deployment dry-run.
- Report changed files, assumptions, commands, results, and unresolved risks.

## Security pass — MiMo v2.5
Review the implementation independently. Search for credential leakage, authorization bypasses, public SQL functions, unsafe RLS, replay/double-spend behavior, secret logging, CORS abuse, missing rate limits, and stale deployment references. Do not modify code. Return findings by severity with file/line evidence and exact corrective actions.

## Flutter regression pass — MiMo v2.5
Review navigation and payment states, duplicate taps, Cubit disposal, router parameters, order ID propagation, COD regressions, localization/RTL, persistence failure handling, and test gaps. Do not modify code. Return findings by severity with file/line evidence.

## Staging evidence
Record:
- migration application result;
- deployed function list and versions;
- anonymous and unauthorized SQL/RPC denial tests;
- successful and failed card sandbox flows;
- COD checkout;
- callback retry/idempotency;
- stock restoration/cancellation;
- Android signed artifact identity;
- CI run URL/result.

## Release gate
Release is blocked by any critical/high security finding, exposed secret, failed payment reconciliation, unauthorized RPC access, duplicate stock mutation, unsigned/wrong-identity artifact, or missing rollback procedure.
