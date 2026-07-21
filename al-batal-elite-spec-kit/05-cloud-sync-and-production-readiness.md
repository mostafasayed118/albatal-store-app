# P1 — Durable Data and Remaining Production Gaps

## Goal
Prevent unacceptable data loss and make launch scope explicit.

## Requirements
- Define canonical ownership for orders: server-backed history with idempotent local cache, or a documented synchronization design. Do not create duplicate records.
- Prioritize server synchronization for orders before launch; evaluate cart and wishlist sync according to scope.
- Add retry, conflict, offline, sign-out, and account-deletion behavior.
- Integrate crash reporting and define privacy-safe analytics events if launch requires them.
- Decide explicitly whether email/SMS/push notifications, carrier tracking, remote catalog, and web branding are launch requirements.
- Define Supabase backup, retention, recovery, and restore-test procedures.
- Analyze the 70.8 MB APK and optimize only after correctness and signing are complete.

## Acceptance criteria
- Reinstall/account re-login behavior is documented and tested for server-owned data.
- No launch-blocking feature is marked complete without live or controlled staging evidence.
- Open risks have an owner, severity, mitigation, and target date.
