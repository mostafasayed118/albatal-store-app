# Revised Execution Roadmap

## Track A — Release unblock (P0)
1. Reconcile deprecated `paymob-order` status and confirm no token exposure.
2. Select branded Android/iOS identities.
3. Configure protected release signing.
4. Build and verify a signed Android release artifact.
5. Configure staging secrets and verify all five active Edge Functions.

## Track B — Production safety (P0/P1)
6. Integrate crash reporting with sensitive-data scrubbing.
7. Add backend and database security tests.
8. Verify callback, cancellation, scheduler, RLS, and rollback behavior in staging.
9. Decide and implement CORS policy based on Android-only versus web scope.

## Track C — Commerce readiness (P1)
10. Decide whether nine products are acceptable for staged launch.
11. If not, wire remote catalog and seed staging data.
12. Decide admin catalog CRUD, cloud cart/wishlist sync, push notifications, and support channels.

## Release gate
Block production release on: debug-signed artifact, placeholder identity, unverified secrets/callbacks, any payment secret exposure, failed RLS/security test, untested migration, absent rollback, or missing crash-reporting decision.
