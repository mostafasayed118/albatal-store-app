---
kind: external_dependency
name: Paymob — Egyptian card payment gateway
slug: paymob
category: external_dependency
category_hints:
    - vendor_identity
    - auth_protocol
    - framework_behavior
scope:
    - '**'
---

### Paymob
- **Role in this repo**: Card payment provider for EGP-denominated transactions. The Flutter app opens Paymob's hosted iframe via `webview_flutter`; all sensitive operations (API key, auth token, order registration, payment key generation) run server-side through the `paymob-initiate` Edge Function.
- **Integration points**:
  - Initiation: `paymob-initiate` calls `https://accept.paymob.com/api/auth/tokens`, then `/api/ecommerce/orders`, then `/api/acceptance/payment_keys`, returning only a safe `checkout_url`.
  - Callback: `paymob-callback` receives form-urlencoded POSTs, verifies an HMAC built from documented fields in constant time, then delegates state mutation to the `process_paymob_callback` RPC.
  - Client-side: `PaymobPaymentService.initiatePayment` invokes the Edge Function and opens the returned URL in a WebView; `watchPaymentStatus` subscribes to the `payments` table via Supabase Realtime.
- **Durable usage model / correction**:
  - Never expose Paymob auth tokens, API keys, or raw upstream payloads to the client — the active `paymob-initiate` function returns only `checkout_url`.
  - The callback must fail CLOSED (HTTP 503) when `PAYMOB_HMAC_SECRET` is missing; it must never insert orphan/fallback payments.
  - Amount and currency in the callback are validated against the server-computed order total before any state change.
- **Verify exact API/params against official docs**: Paymob provider order/key endpoints, HMAC field list and ordering.