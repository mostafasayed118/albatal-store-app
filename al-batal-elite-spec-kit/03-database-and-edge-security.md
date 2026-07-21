# P0.3 — Database and Edge-Function Security

## Requirements
- Add owner/admin authorization checks to `get_order_details()`.
- Add admin authorization to `get_low_stock_products()`.
- Add the minimum required UPDATE policy for payment reconciliation; restrict updates to trusted server paths where possible.
- Replace publicly callable stock mutation functions with guarded, transactional operations. Enforce authenticated/admin or server-only authorization and validate quantity bounds.
- Make expired-order cancellation atomic and idempotent: lock the order, verify state, restore stock once through a ledger or guarded mutation, then transition state.
- Review every function under `supabase/functions/` for authentication, authorization, CORS, input validation, rate limiting, secret handling, and sanitized errors.
- Remove all three deprecated deployed functions and obsolete Vodafone Cash references.
- Add migrations and deployment instructions together; never rely on dashboard-only changes.

## Acceptance criteria
- Anonymous callers cannot read another user’s order, low-stock data, or mutate stock.
- A normal user cannot alter payment/order/stock records outside their ownership and allowed transitions.
- Repeated callbacks and cancellation jobs are safe and produce one effective state transition.
- SQL tests or staging evidence demonstrate both allowed and denied paths.
