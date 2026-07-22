# P1 — Verification Expansion

## Requirements
- Add Deno/TypeScript tests for all active Edge Functions, prioritizing payment initiation, callback HMAC, URL validation, authorization, sanitization, and cancellation idempotency.
- Add database/RPC tests for owner/admin authorization, RLS denial, stock invariants, checkout idempotency, and payment state transitions.
- Add admin-page tests for authorization and destructive actions.
- Add coverage reporting to CI with a documented threshold that grows over time.
- Run Android release build and signing verification in CI or a controlled release environment.
- If web is in scope, replace wildcard CORS with environment-specific allowlists and run authorized/unauthorized browser-origin tests.

## Acceptance criteria
- Security-critical backend paths have executable tests, not only static inspection.
- CI reports test and coverage results on pull requests.
- Release evidence includes analyzer, Flutter tests, backend tests, migration/RLS checks, signed artifact verification, and staging smoke tests.
