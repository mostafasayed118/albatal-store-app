# Supabase Integration Walkthrough

## Overview

The app uses Supabase for cloud backend services. The integration follows a phased approach:

| Phase | What | Status |
|-------|------|--------|
| 0 | Project setup, env config | ✅ |
| 1 | Database schema (10 tables) | ✅ |
| 2 | Row Level Security policies | ✅ |
| 3 | Flutter connection, env loading | ✅ |
| 4 | Remote catalog (products, categories) | ✅ |
| 5 | Auth (sign up/in, profiles, session restore) | ✅ |
| 6 | Personal data (addresses, wishlist, cart, orders) | ✅ |
| 7 | Product images (Storage buckets) | ✅ |
| 8 | Server-side checkout (Edge Function) | ✅ |
| 9 | Admin operations | ✅ |

## Architecture decision: Local ↔ Supabase switching

The app supports both local (guest) and cloud (authenticated) modes:

```
AuthCubit state
  ├── unauthenticated → Local repositories (SharedPreferences)
  └── authenticated   → Supabase repositories (API calls)
```

Catalog is always remote (public data). Personal data switches based on auth state.

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

Repositories map rows directly to the [`Money`](../lib/core/entities/money.dart)
value object with no `/ 100` conversion:

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

| Supabase Table | Flutter Entity | Repository |
|----------------|---------------|------------|
| `profiles` | `Profile` | `SupabaseProfileRepository` |
| `products` | `Product` | `SupabaseCatalogRepository` |
| `categories` | `String` | `SupabaseCatalogRepository` |
| `product_variants` | `Product.stock`, `sizes`, `colors` | `SupabaseCatalogRepository` |
| `addresses` | `Address` | `SupabaseAddressRepository` |
| `wishlists` | `WishlistState.ids` | `SupabaseWishlistRepository` |
| `cart_items` | `CartState.items` | `SupabaseCartRepository` |
| `orders` | `Order` | `SupabaseOrdersRepository` |
| `order_items` | `Order.items` | `SupabaseOrdersRepository` |

## SQL migrations

Run in order:
1. `001_initial_schema.sql` — tables, indexes, triggers
2. `002_rls_policies.sql` — access control
3. `003_auth_profiles_and_hardening.sql` — profile trigger, admin role
4. `004_stock_function.sql` — server-side stock decrement
5. `005_storage_buckets.sql` — image storage

## Edge Functions

| Function | Purpose |
|----------|---------|
| `checkout` | Validates prices, stock, creates order, decrements stock, clears cart |

## Environment variables

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Stored in `.env` (gitignored). Loaded via `flutter_dotenv`.
