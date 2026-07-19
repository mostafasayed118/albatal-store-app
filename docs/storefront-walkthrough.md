# Storefront Walkthrough

## What problem does the storefront solve?

The storefront is the core commerce feature — it handles product discovery, cart management, checkout, and order tracking. It was built incrementally:

1. **Phase 1**: Local mock data with hardcoded products, in-memory cart/wishlist/orders
2. **Phase 2**: Search, filters (category, color, price), sort (featured, price, name, newest)
3. **Phase 3**: Product details with image gallery, size guide, stock, related products
4. **Phase 4**: Supabase integration — remote catalog, auth, cloud cart/wishlist/orders
5. **Phase 5**: Server-side checkout with stock validation

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
                    │ LocalRepository   │ │ SupabaseRepo    │ │ CheckoutService   │
                    │ (SharedPreferences│ │ (Supabase API)  │ │ (Edge Function)   │
                    └───────────────────┘ └─────────────────┘ └───────────────────┘
```

## Key files

| File | Owns |
|------|------|
| `catalog_cubit.dart` | Search, filter, sort state; product list |
| `cart_cubit.dart` | Cart items, add/remove/update, totals |
| `checkout_cubit.dart` | Address selection, payment, order placement |
| `orders_cubit.dart` | Order history, status advancement |
| `wishlist_cubit.dart` | Saved product IDs, product resolution |
| `product_details_cubit.dart` | Product lookup, variant selection, related products |

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
