# P0.1 — Remove Paymob Authentication Token Exposure

## Problem
`supabase/functions/paymob-order/index.ts` reportedly returns the Paymob authentication token around line 96. The function is deprecated but may still be deployed and callable. This is a critical credential-disclosure vulnerability.

## Requirements
- Remove the deprecated `paymob-order` function from source, deployment, and documentation, or make it permanently unavailable before any normal deployment.
- Search the complete repository for `paymob-order`, `auth_token`, `token`, Paymob authentication responses, and unsafe response serialization.
- The active `paymob-initiate` function must never return Paymob auth tokens, API keys, request headers, raw upstream payloads, or secrets.
- Return only a client-safe response such as a checkout URL or opaque checkout reference, using the project’s existing contract.
- Do not log tokens, authorization headers, payment card data, CVV, or raw Paymob payloads.
- Preserve server-side secret access through environment variables only.
- Use generic client-facing errors while logging only sanitized correlation data server-side.

## Acceptance criteria
- No deployable source or script references the deprecated function.
- No client-visible response path contains a provider token or secret.
- `paymob-initiate` still supports the intended authenticated order/payment flow.
- COD behavior is unchanged.
- Existing tests remain green and new regression tests fail if a secret is serialized.
- Deployment scripts list only current functions.

## Required tests
- Static repository search with zero unsafe matches, excluding intentional documentation/test assertions.
- Unit/contract test for successful initiation: permitted fields only.
- Test for upstream failure: sanitized error only.
- Test proving logs and exceptions do not contain token values.
- Auth/authorization tests for unauthenticated, wrong-user, replayed, and already-paid orders.

## Rollback
Do not restore the vulnerable function. If payment initiation fails, disable the affected route and retain COD while correcting the safe implementation.
