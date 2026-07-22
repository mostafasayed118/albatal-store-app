---
kind: external_dependency
name: Supabase — Auth, Postgres, Edge Functions, Storage
slug: supabase
category: external_dependency
category_hints:
    - vendor_identity
    - auth_protocol
scope:
    - '**'
---

### Supabase
- **Role in this repo**: Cloud backend providing PostgreSQL (14 tables + RLS), Auth (email/password with session restore), Storage buckets (public product images, private avatars), and server-side Edge Functions for checkout and payments.
- **Integration points**:
  - Payments are orchestrated by two Edge Functions (`paymob-initiate`, `paymob-callback`) plus helper functions (`cancel-expired-orders`, `send-order-notification`).
  - Realtime subscriptions on the `payments` table drive payment-status streaming in `PaymobPaymentService.watchPaymentStatus`.
- **Durable usage model / correction**:
  - Client must NEVER send price/total/shipping to the server; only identifiers and address snapshot. All money is computed inside the RPC.
  - Payment success is decided exclusively by the HMAC-verified `/paymob-callback` webhook; the client observes status via Realtime and must never parse a callback URL to decide payment success.
  - The service-role key is used ONLY inside Edge Functions (callback path); the anon key is the only secret in the Flutter app.
- **Verify exact API/params against official docs**: checkout RPC signature, Edge Function secrets, and Paymob provider endpoints.