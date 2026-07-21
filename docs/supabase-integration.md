# Supabase Integration Walkthrough

## Overview

The app uses Supabase for cloud backend services. The integration follows a phased approach:

| Phase | What | Status |
|-------|------|--------|
| 0 | Project setup, env config | ✅ |
| 1 | Database schema (10 tables) | ✅ |
| 2 | Row Level Security policies | ✅ |
| 3 | Flutter connection, env loading | ✅ |
| 4 | Auth (sign up/in, profiles, session restore) | ✅ |
| 5 | Admin operations (Supabase-backed) | ✅ |
| 6 | Product images (Storage buckets) | ✅ |
| 7 | Server-side checkout (Edge Function + RPC) | ✅ |
| 8 | Payments (Paymob Edge Functions) | ✅ |

> **Note on scope.** Catalog browsing and all client-side personal data
> (cart, wishlist, addresses, order history) are stored **locally** via
> `SharedPreferences` through `LocalStorefrontPersistence`. The Supabase
> repository implementations for those tables were removed; only
> **auth, profiles, admin, and checkout** remain server-backed. The
> server-side checkout RPC (`create_checkout_order`, migration 013) is
> still used to create orders so prices, stock, and totals stay
> server-authoritative — see `lib/features/storefront/data/checkout_service.dart`.

## Architecture decision: local-first storefront, server-backed checkout

```
Feature           Storage
─────────────────────────────────────────────────────
Auth / profiles   Supabase (SupabaseAuthRepository, SupabaseProfileRepository)
Admin             Supabase (SupabaseAdminRepository)
Catalog           Local (LocalCatalogRepository, mock seed data)
Cart              Local (LocalCartRepository via SharedPreferences)
Wishlist          Local (LocalWishlistRepository via SharedPreferences)
Addresses         Local (LocalAddressRepository via SharedPreferences)
Orders history    Local (LocalOrdersRepository via SharedPreferences)
Checkout          Server (CheckoutService → create_checkout_order RPC)
Payments          Server (Paymob Edge Functions)
```

Catalog and personal storefront data do **not** switch on auth state.
They are local for both guests and authenticated users. Only checkout,
payment, auth, profiles, and admin touch Supabase.

## Security model

| Layer | Protection |
|-------|-----------|
| Database | RLS policies on every table |
| Auth | Supabase Auth with email/password |
| Orders | Created via Edge Function only (client cannot insert) |
| Prices | Stored as `INTEGER` minor units (cents); validated server-side in checkout function |
| Stock | Decremented atomically in checkout function |
| Keys | Only anon key in Flutter app; service-role stays server-side |

## Money representation

The database and the Flutter app share a single money representation: **integer
minor units (cents)**. All money columns — `base_price`, `old_price`,
`unit_price`, `subtotal`, `shipping`, `total` — are `INTEGER` storing cents.

The server-side checkout RPC computes every total from stored `INTEGER` cents
and returns them in the same shape, so the client never sends or overrides a
price. Repositories that map server responses to the
[`Money`](../lib/core/entities/money.dart) value object do so with no `/ 100`
conversion:

```dart
price: Money(row['base_price'] as int),
subtotal: Money(row['subtotal'] as int),
```

`Money` carries the same integer-cents representation through the domain and
presentation layers. The only place a `double` appears is `Money.majorUnits`,
which is intended for **display only** — never for arithmetic. Paymob's API
expects cents too, so `PaymobPaymentService` passes `amount.minorUnits` with no
conversion.

## File mapping

Only auth, profiles, admin, and checkout have Supabase-backed repositories in
the Flutter app. Catalog, cart, wishlist, addresses, and orders history are
local-only.

| Supabase surface | Flutter Entity | Repository |
|------------------|----------------|------------|
| `profiles` | `Profile` | `SupabaseProfileRepository` |
| Auth (Supabase Auth) | `AuthUser` / session | `SupabaseAuthRepository` |
| `products`, `categories`, `order_items` (read via admin) | `Order` aggregates | `SupabaseAdminRepository` |
| `create_checkout_order` RPC | `PendingOrder` | `CheckoutService` |

The `products` / `categories` / `product_variants` / `addresses` / `wishlists`
/ `cart_items` / `orders` / `order_items` tables still exist in the database
(created by the migrations below and protected by RLS), but the Flutter client
no longer has repository implementations reading them directly. Catalog data
shown in the app comes from `LocalCatalogRepository` mock seed data; cart,
wishlist, addresses, and order history live in `SharedPreferences`.

## SQL migrations

Fourteen numbered migrations, run in order:

1. `001_initial_schema.sql` — tables, indexes, triggers
2. `002_rls_policies.sql` — access control
3. `003_auth_profiles_and_hardening.sql` — profile trigger, admin role
4. `004_stock_function.sql` — server-side stock decrement
5. `005_storage_buckets.sql` — image storage
6. `006_payments_table.sql` — payments tracking
7. `007_stock_increment_function.sql` — stock recovery on payment failure
8. `008_order_fulfillment.sql` — order status validation, low-stock function
9. `009_shipping_zones.sql` — 7 Egyptian zones, delivery fee calculation
10. `010_notifications_analytics.sql` — notifications, analytics, error logging
11. `011_orders_idempotency_and_expiry.sql` — idempotency key, order expiry
12. `012_add_order_statuses.sql` — order status enum values used by edge functions
13. `013_atomic_checkout_rpc.sql` — `create_checkout_order` SECURITY DEFINER RPC
14. `014_paymob_security_repair.sql` — Paymob callback hardening

Helper scripts live in `scripts/` (`run_all_migrations.sql`,
`run_new_migrations_only.sql`, `combine_migrations.ps1`,
`run_migrations.ps1`, `verify_schema.sql`, `drop_everything.sql`) and the
`supabase/migrations/` folder also contains `verify_rls.sql` plus two test SQL
files (`test_create_checkout_order.sql`, `test_paymob_callback.sql`).

## Edge Functions

| Function | Purpose |
|----------|---------|
| `checkout` | Legacy server-side order creation (pre-RPC; superseded by the 013 RPC for new flows) |
| `paymob-initiate` | Single-call Paymob payment initiation (server-side only) |
| `paymob-callback` | Webhook with HMAC verification, idempotent |
| `cancel-expired-orders` | Cancels orders past their `expires_at` |
| `send-order-notification` | Email notifications |

> **Removed (security):** `paymob-auth`, `paymob-order`, `paymob-payment-key` —
> these deprecated functions leaked Paymob auth tokens to clients and have been
> permanently deleted. Undeploy them with `supabase functions delete <name>`.

## Environment variables

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Stored in `.env` (gitignored). Loaded via `flutter_dotenv`.
