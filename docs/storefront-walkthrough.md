# Storefront Walkthrough

## What problem does the storefront solve?

The storefront is the core commerce feature — it handles product discovery, cart management, checkout, and order tracking. It was built incrementally:

1. **Phase 1**: Local mock data with hardcoded products, in-memory cart/wishlist/orders
2. **Phase 2**: Search, filters (category, color, price), sort (featured, price, name, newest)
3. **Phase 3**: Product details with image gallery, size guide, stock, related products
4. **Phase 4**: Server-authoritative checkout via the `create_checkout_order` RPC (migration 013) — prices, stock, and totals computed server-side
5. **Phase 5**: Paymob payments via server-side Edge Functions

> **Scope note.** Catalog browsing, cart, wishlist, addresses, and order
> history are stored **locally** (`SharedPreferences` via
> `LocalStorefrontPersistence`). The Supabase repository implementations for
> those surfaces were removed; only checkout and payment remain server-backed.
> See `docs/supabase-integration.md` for the full split.

## Data flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Widget     │────▶│    Cubit     │────▶│   Repository    │
│ (observes)   │     │ (owns state) │     │  (interface)    │
└─────────────┘     └──────────────┘     └────────┬────────┘
                                                   │
                               ┌─────────────────────┼─────────────────────┐
                               │                     │                     │
                     ┌─────────▼─────────┐ ┌────────▼────────┐ ┌─────────▼─────────┐
                     │ LocalRepository   │ │ CheckoutService │ │ PaymobPaymentSvc  │
                     │ (SharedPreferences│ │ (RPC: 013)      │ │ (Edge Functions)  │
                     └───────────────────┘ └─────────────────┘ └───────────────────┘
```

The `LocalRepository` branch covers catalog, cart, wishlist, addresses, and
orders history. `CheckoutService` calls the `create_checkout_order` PostgreSQL
RPC (server-authoritative) and `PaymobPaymentService` drives the Paymob Edge
Functions. There is no per-auth Supabase repository swap for storefront data.

## Key files

| File | Owns |
|------|------|
| `core/entities/money.dart` | `Money` value object — integer minor units (cents), arithmetic, comparison, `format()` |
| `catalog_cubit.dart` | Search, filter, sort state; product list; price-range filter is `Money`-typed |
| `cart_cubit.dart` | Cart items, add/remove/update, totals computed as `Money` |
| `checkout_cubit.dart` | Address selection, payment, order placement |
| `orders_cubit.dart` | Order history, status advancement |
| `wishlist_cubit.dart` | Saved product IDs, product resolution |
| `product_details_cubit.dart` | Product lookup, variant selection, related products |

## Money model

All prices, subtotals, shipping fees, and order totals are `Money` — an immutable
value object storing integer **minor units** (cents). `Money.egp(1290)` and
`Money(129000)` are equal. The database already stores money as `INTEGER` cents
(`base_price`, `old_price`, `subtotal`, `shipping`, `total`, `unit_price`), so
repositories map rows to `Money` with no `/ 100` conversion, and widgets call
`state.total.format()` (or the `money(...)` helper) for display only.

Arithmetic uses the `+`, `-`, `*` operators (no `/` — division would lose
precision). Comparisons use `<`, `<=`, `>`, `>=`. `Money.zero` is the neutral
element for empty carts and free shipping. Never convert `Money` to `double` for
computation; `majorUnits` (a `double`) exists for display only.

## State transitions

### CatalogCubit
```
initial → loading → ready
                    → error (retry → loading)
```

### CartCubit
```
initial → loading → ready (add/update/remove/clear)
                    → error
```

### AuthCubit
```
initial → checkingSession → authenticated
                          → unauthenticated
         authenticating → authenticated
                        → failure (retry)
         passwordRecovery → authenticated
```

## Testing approach

- **Unit tests**: Cubit state transitions with stub repositories
- **Widget tests**: Key screens with BlocProvider mocks
- **Integration tests**: Cross-cubit interactions (wishlist ↔ cart)

Tests use `MemoryStorefrontPersistence` and stub repositories to avoid real I/O.
