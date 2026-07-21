# P0.2 — Card Payment Flow Hardening

## Goal
Make the current Paymob card flow correct, secure, observable, and recoverable from initiation through order history.

## Scope
- `payment_method_page.dart`
- `PaymentCubit` and payment states
- `app_router.dart`
- `order_success_page.dart`
- `paymob-initiate/index.ts`
- order repository/Cubit and local persistence
- payment and order migrations

## Requirements
1. When initiation emits a pending checkout URL, navigate exactly once to the hosted checkout.
2. Preserve a real order identifier through router state; remove fallback/demo order IDs.
3. Handle loading, success, cancellation, timeout, malformed URL, duplicate tap, and provider failure states.
4. Treat server order/payment state as authoritative; never mark an order paid from client navigation alone.
5. Reconcile callback/webhook-confirmed orders into local order history idempotently.
6. Await persistence operations and surface failures instead of silently ignoring them.
7. Prevent double initiation and stale Cubit callbacks after disposal.
8. Keep COD flow unchanged and cover EN/AR plus RTL layout.
9. Validate billing data from an order-address snapshot; do not use placeholders or expose sensitive data.

## Acceptance criteria
- A successful sandbox card payment produces one server order, one payment record, and one local history entry.
- Cancellation/failure leaves the order in a safe unpaid state and does not reduce stock twice.
- Relaunching the app does not duplicate reconciled orders.
- Success screen displays the actual order ID.
- Tests cover every payment state and route transition.
