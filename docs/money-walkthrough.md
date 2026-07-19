# Money Value Object — Learning Walkthrough

## Problem and approach

Commerce code that stores prices as `double` accumulates floating-point
rounding errors: `0.1 + 0.2 == 0.30000000000000004`, totals drift a few cents
per order, and filter ranges behave unpredictably near boundaries. Egyptian
pound decimals (or any currency with 100 minor units) make the error visible
on every calculation.

The fix is a single domain type — `Money` — that stores the value as integer
**minor units (cents)**, the same representation the database already uses
(`base_price INTEGER`, `subtotal INTEGER`, etc.). This creates one source of
truth across Postgres, the Supabase client, the domain layer, and the UI. No
`* 100` / `/ 100` leaks across layer boundaries.

`Money` is a small `Equatable` value object (not a full包 like `currency` or
`money2`) so we avoid adding a dependency for behavior we can model in ~50
lines. It exposes only what the storefront actually uses: addition, subtraction,
scalar multiplication, comparisons, `zero`, `format()`, and a `Money.egp()`
factory for readable mock data.

## Files and ownership

- `lib/core/entities/money.dart` — the `Money` type. Owns the integer-cents
  invariant (`assert(minorUnits >= 0)`), arithmetic operators, comparisons, and
  `format()`.
- `lib/core/entities/product.dart` — `Product.price` and `Product.oldPrice`
  are now `Money`. `CartItem.lineTotal` returns `Money`.
- `lib/core/entities/order.dart` — `Order.subtotal`, `shipping`, `total` are
  `Money`.
- `lib/core/utils/currency.dart` — the `money(Money n)` helper delegates to
  `n.format()` for ergonomic call sites in widget trees.
- `lib/features/storefront/data/products_data.dart` — mock seed data uses
  `Money.egp(1290)` instead of `1290`.
- `lib/features/storefront/data/supabase_catalog_repository.dart`,
  `supabase_orders_repository.dart`, `supabase_cart_repository.dart`,
  `checkout_service.dart`, `storefront_persistence.dart` — repositories map
  rows and JSON to `Money` with no `/ 100`.
- `lib/features/storefront/presentation/cubit/cart_cubit.dart` —
  `CartState.subtotal` / `shipping` / `total` are `Money`. Fold starts at
  `Money.zero` and uses `item.lineTotal`.
- `lib/features/storefront/presentation/cubit/catalog_cubit.dart` —
  `CatalogState.priceMin` / `priceMax` are `Money`; `_unboundedMax` is the
  `Money.egp(999999)` sentinel for "no max filter".
- `lib/features/payments/domain/entities/payment.dart`,
  `domain/repositories/payment_service.dart`,
  `data/paymob_payment_service.dart`,
  `presentation/cubit/payment_cubit.dart` — `PaymentState.amount` is `Money`;
  `PaymobPaymentService` passes `amount.minorUnits` to Paymob (already cents,
  no `* 100` needed).

## Data flow

```
┌────────────┐   INTEGER cents   ┌──────────────┐   INTEGER cents   ┌────────────┐
│ Postgres   │ ────────────────▶│ Repository   │ ────────────────▶│ Money      │
│ base_price │                   │ (mapper)     │                   │ (domain)   │
└────────────┘                   └──────────────┘                   └─────┬──────┘
                                                                          │
                                                              Money operators │
                                                              (no conversion) │
                                                                          ▼
                                                                  ┌──────────────┐
                                                  format()       │   Widget     │
                                                  ─────────────▶ │ (display)    │
                                                                 └──────────────┘
```

The `/ 100` denominator appears in exactly one place — `Money.format()` and
`Money.majorUnits` — and only for display. Every calculation works in cents.

## Why not `double`?

The previous code stored `price: 1290` (a `double`) in mock data, divided by
100 in every repository, and multiplied by 100 again before calling Paymob.
Each conversion is a chance for rounding error and a place where future code
must remember the convention. `Money` makes the representation explicit and
removes the conversions:

| Before | After |
|--------|-------|
| `price: 1290` (double EGP) | `price: Money.egp(1290)` |
| `(row['base_price'] as int) / 100` | `Money(row['base_price'] as int)` |
| `items.fold(0, (v, i) => v + i.product.price * i.quantity)` | `items.fold(Money.zero, (v, i) => v + i.lineTotal)` |
| `final amountCents = (amount * 100).round();` | `final amountCents = amount.minorUnits;` |
| `price: 0.0` (sentinel) | `price: Money.zero` |

## Conventions

- **Constructors**: `Money(int cents)` for canonical / DB-loaded values;
  `Money.egp(int major)` for readable mock / seed values. Both are `const`.
- **Sentinels**: `Money.zero` for empty carts, free shipping, and "no
  minimum"; `Money.egp(999999)` for "no maximum" — not silence, a real bound.
- **Arithmetic**: `+`, `-`, `*` (scalar `int`) only. No `/` — division of
  cents would lose precision. If you need half of a value, decide where the
  rounding goes explicitly.
- **Display**: `money(state.total)` or `state.total.format()` in widgets.
  Returns e.g. `"1290 EGY"`.
- **Never** read `majorUnits` for computation — it is a `double` and exists
  only to feed formatters.

## Tests

The refactor keeps the existing cart, payment, and product-detail tests
working with `Money`-typed assertions. New tests should:

- Construct `Money` from cents (DB shape) and from `Money.egp(...)` (mock
  shape) and assert equality — the two constructors must agree.
- Assert `Money.zero`-based folds and `Money.egp(75)` shipping fee rather
  than the bare `0` / `75` literals.
- Test the price-range filter at `Money` boundaries.

## Limitations

- `Money` is single-currency (assumes 100 minor units; no JPY/BHD-style
  3-decimal or 0-decimal support). Acceptable for an EGP-only store; revisit
  if multi-currency arrives.
- No currency code field — the `EGY` symbol is a `format()` parameter.
- No `abs()` or `-` negation: subtraction assumes the left operand is larger
  (the `assert(minorUnits >= 0)` will fire otherwise). Refunds orPartial
  credits would need an extension.

## Self-check

1. Why does `Money` store cents instead of a `double` EGP value?
2. Where is the only `/ 100` allowed in the codebase, and why?
3. Why does `PaymobPaymentService` no longer multiply by 100 before calling
   the Paymob API?
4. Construct `Money(129000)` and `Money.egp(1290)` — are they equal? Why
   does that matter for repository mapping?
5. The cart subtotal starts at `Money.zero`, not `0`. What mistake does
   that prevent that the old `double` version could not catch?
