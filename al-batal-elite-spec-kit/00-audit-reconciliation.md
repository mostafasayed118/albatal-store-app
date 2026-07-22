# Audit Reconciliation and Scope Baseline

## Authority and evidence status
The latest implementation session reports commit `37118b1` on `feat/remediation-spec-kit`, with 163/163 Flutter tests passing, clean analysis, and no secret leaks. This materially supersedes the earlier 153-test audit for repository status, but live deployment and staging claims remain release evidence gates until independently reproduced.

## Reported completed remediation
- Deprecated Paymob token exposure is locked by a contract test returning only `{checkout_url}`; deploy scripts no longer reference deprecated functions and fixtures were renamed. Confirm source, deployment inventory, and client references before release.
- Paymob initiation uses real order-address billing snapshots, timeout/response-size guards, and callback HMAC/security tests.
- `OrdersCubit.reconcile()` performs idempotent order upserts and persistence failures surface; payment re-entry is guarded.
- RPC authorization assertions, low-stock indexing, cancellation security tests, and parallel expiry processing are present.
- Android identity is reported as `com.albatal.elite`; release signing uses protected key-properties fallback. Still verify a real release artifact and certificate.
- Sentry crash reporting is wired with PII scrubbing and platform error handlers. Still verify a controlled event in the target dashboard.
- Supabase-backed orders are feature-flagged for production, with local debug behavior; catalog uses Supabase with persistent caching.
- CI reportedly includes parallel analysis/tests, Deno tests, coverage reporting, secret scanning, deprecated-function detection, and an Android-release job.

## Verified versus reported
### Verified in the implementation session
- Flutter analyzer: 0 issues.
- Flutter tests: 163/163 passed.
- The listed source, test, migration, CI, and configuration changes were reported implemented at commit `37118b1`.

### Must still be verified for release
- `paymob-order` and every deprecated function are absent or disabled in the actual Supabase deployment.
- No deployed endpoint exposes provider tokens or other secrets.
- Production/staging secrets, callback URLs, HMAC configuration, scheduler execution, and applied migrations are correct.
- Release APK is signed with the production certificate and has the intended identity.
- Sentry receives a sanitized staging crash event.
- RLS/RPC tests run against the deployed schema, not only local SQL fixtures.
- Android startup, payment E2E, cancellation race behavior, and rollback are tested in staging.

## Deferred scope and risks
- Rate limiting relies on Supabase platform controls; document limits and monitoring.
- Admin catalog CRUD is post-MVP unless product requirements change.
- APK size optimization follows signing verification.
- Cloud cart/wishlist sync, push notifications, web CORS tightening, real imagery, provider notifications, analytics, backups/recovery, and support actions require explicit launch-scope decisions.

## Release rule
Do not reopen completed payment work solely because an older audit said it was defective. Reopen it only when current source, deployed behavior, or controlled tests fail the security contract. Block production on any secret exposure, debug-signed artifact, failed authorization/RLS test, unverified migration/configuration, absent rollback, or missing observability evidence.
