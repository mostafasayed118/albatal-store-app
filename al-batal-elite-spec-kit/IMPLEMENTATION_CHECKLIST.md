# Implementation Checklist

- [x] Inspect `git status` and preserve uncommitted work
- [x] Remove/disable deprecated `paymob-order`, `paymob-auth`, `paymob-payment-key`
- [x] Search for token/secret leakage and stale function references
- [x] Harden `paymob-initiate` response and logging
- [x] Sanitize error logging across all Edge Functions (no raw error objects)
- [x] Replace CORS wildcard with configurable shared helper
- [x] Update deployment scripts (ps1, sh, bat) to exclude deprecated functions
- [x] Update documentation (README, supabase-integration, staging-verification)
- [ ] Repair payment navigation and real order ID propagation
- [ ] Reconcile server-confirmed orders idempotently
- [ ] Authorize order-detail and low-stock RPCs
- [ ] Guard stock mutations and expired-order cancellation
- [ ] Add CI checks
- [ ] Fix Android application ID and protected signing
- [ ] Add regression/security tests
- [ ] Run analyzer, formatter, tests, build, and static searches
- [ ] Obtain independent security and Flutter reviews
- [ ] Capture staging evidence and release decision
