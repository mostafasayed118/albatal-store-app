# Implementation Checklist

- [ ] Inspect `git status` and preserve uncommitted work
- [ ] Remove/disable deprecated `paymob-order`
- [ ] Search for token/secret leakage and stale function references
- [ ] Harden `paymob-initiate` response and logging
- [ ] Repair payment navigation and real order ID propagation
- [ ] Reconcile server-confirmed orders idempotently
- [ ] Authorize order-detail and low-stock RPCs
- [ ] Guard stock mutations and expired-order cancellation
- [ ] Update deployment scripts and docs
- [ ] Add CI checks
- [ ] Fix Android application ID and protected signing
- [ ] Add regression/security tests
- [ ] Run analyzer, formatter, tests, build, and static searches
- [ ] Obtain independent security and Flutter reviews
- [ ] Capture staging evidence and release decision
