# P0/P1 — Production Configuration and Observability

## Objective
Make staging and production deployments reproducible and observable without exposing secrets.

## Requirements
- Inventory the five active Edge Functions and compare source, migration dependencies, deployment scripts, and deployed versions.
- Configure required Supabase and Paymob secrets only in the approved secret manager/dashboard.
- Verify callback URLs, HMAC secret, environment separation, scheduler configuration, and rollback steps.
- Integrate an approved crash-reporting provider in Flutter. Capture fatal errors, uncaught asynchronous errors, and useful release metadata while excluding tokens, card data, addresses, and other sensitive fields.
- Add a test/staging crash event and verify receipt in the provider dashboard.
- Define privacy retention and opt-out behavior where applicable.

## Acceptance criteria
- A new operator can deploy staging from documented steps.
- Missing required secrets fail safely with actionable operator logs and generic client errors.
- Every production crash has a release/environment identifier.
- No payment token, authorization header, CVV, or raw provider payload reaches telemetry.
- Rollback is documented and tested for the Edge Functions and mobile artifact.
