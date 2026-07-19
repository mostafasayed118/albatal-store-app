# Al Batal Elite

A premium fabric-commerce Flutter application with a tactile, textile-inspired design language. Built on a [`DESIGN.md`](https://stitch.withgoogle.com/docs/design-md/overview/) system — the convention from [Awesome DESIGN.md](https://github.com/VoltAgent/awesome-design-md) — so AI coding agents and human collaborators share a single source of truth for how every screen should look and feel.

---

## Features

### Customer App
- **Product catalog** — 9 fabric swatches across Silk, Cotton, Velvet, Linen, and Wool categories
- **Product search** — real-time search with debounce, category/color/price filters, 5 sort options
- **Product details** — image gallery with zoom, size guide, stock per variant, related products, delivery/returns info, star ratings
- **Cart** — add/remove/update items, quantity stepper, subtotal/shipping/total
- **Checkout** — address picker from saved addresses, payment method selection, order review, confirmation
- **Wishlist** — save products, move to cart
- **Orders** — order history with status tracking (placed → shipped → delivered)
- **Authentication** — email/password sign up, sign in, password reset, email verification
- **Profiles** — display name, phone, order history
- **Guest shopping** — browse and add to cart without sign-in; sign-in required for wishlist, addresses, checkout
- **English & Arabic** — full RTL support with 200+ localized strings
- **Two themes** — Emerald/Gold light mode and Charcoal/Slate dark mode

### Cloud Backend (Supabase)
- **Remote catalog** — products, categories, variants, images stored in Supabase
- **Authentication** — Supabase Auth with email/password, session restore
- **User profiles** — profile data (name, phone, avatar) synced per customer
- **Row Level Security** — users can only access their own data
- **Server-side checkout** — Edge Function validates prices, stock, creates orders atomically (used for card payments; cash-on-delivery places orders locally)
- **Storage** — product images (public) and avatars (private)
- **Admin support** — admin role for catalog/order management

> **Note on local persistence:** Cart, wishlist, addresses, and orders are
> currently persisted locally on-device via SharedPreferences (offline-first).
> Cloud sync for these collections is planned but not yet wired — the
> Supabase repository implementations were removed in favor of shipping a
> reliable local-first experience first.

---

## Architecture

```
lib/
├── core/
│   ├── entities/          # Product, Order, Address, Profile, Money
│   ├── error/             # Result<T>, AppError
│   ├── utils/             # Currency formatting (`money()` helper)
├── features/
│   ├── auth/              # Authentication & profile
│   │   ├── data/          # SupabaseProfileRepository
│   │   ├── domain/        # ProfileRepository interface
│   │   └── presentation/  # AuthCubit, sign-in/up pages
│   ├── addresses/         # Shipping addresses (local persistence)
│   │   ├── data/          # LocalAddressRepository
│   │   ├── domain/        # AddressRepository interface
│   │   └── presentation/  # AddressesCubit, addresses page
│   ├── settings/          # Theme & language preferences
│   └── storefront/        # Commerce feature (local persistence)
│       ├── data/          # Repositories, persistence
│       ├── domain/        # Repository interfaces
│       └── presentation/
│           ├── cubit/     # Cart, Catalog, Checkout, Orders, Wishlist, Details
│           ├── pages/     # Home, Categories, Catalog, Cart, Details, Checkout, Orders
│           └── widgets/   # 30+ focused widget files (one public widget per file)
├── generated/l10n/        # Generated localizations
└── shared/
    ├── components/        # AppButton, AppShell, FeedbackView
    ├── extensions/        # BuildContextX
    ├── providers/         # Repository providers
    ├── routing/           # GoRouter config
    ├── services/          # SupabaseConfig, StorageService, AdminService
    ├── widgets/           # EnvironmentBanner
    └── theme/             # AppTheme (Material 3)
```

### Data Flow

```
UI (Widget)
  → observes state via BlocBuilder/BlocListener
    → Cubit (owns screen state, emits via StateStream)
      → Repository interface (domain layer)
        → Supabase or Local implementation (data layer)
          → Supabase API or SharedPreferences
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| One public widget per file | Discoverability, single responsibility, easier code review |
| Domain repository interfaces | Local-first implementations; cloud sync planned (interfaces keep Cubits unchanged when Supabase repos are wired) |
| `Money` value object (integer minor units) | Avoids decimal rounding errors; matches the `INTEGER` cents columns in Postgres so no `* 100` / `/ 100` leaks across layers |
| Order items snapshot product details | Past orders remain accurate after catalog changes |
| Server-side checkout | Client never trusted for price/stock validation |
| Guest-first browsing | Reduces friction; sign-in only when persistence needed |

---

## Local Setup

```bash
# 1. Install dependencies
flutter pub get
flutter gen-l10n

# 2. Configure Supabase
cp .env.example .env
# Edit .env with your Supabase URL and anon key

# 3. Run SQL migrations in Supabase dashboard
# supabase/migrations/001_initial_schema.sql
# supabase/migrations/002_rls_policies.sql
# supabase/migrations/003_auth_profiles_and_hardening.sql
# supabase/migrations/004_stock_function.sql
# supabase/migrations/005_storage_buckets.sql

# 4. Deploy Edge Function
supabase functions deploy checkout

# 5. Verify
flutter analyze
flutter test

# 6. Run
flutter run
```

---

## Supabase Setup

### Required Steps
1. Create a project at [supabase.com](https://supabase.com)
2. Copy Project URL and anon key to `.env`
3. Run the 5 SQL migrations in order via SQL Editor
4. Enable Email provider in Authentication → Providers
5. Deploy the `checkout` Edge Function

### Environment Variables

```bash
# .env (never commit this file)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Dependencies

| Package | Role |
|---------|------|
| `flutter_bloc` / `bloc` | Cubit state management |
| `equatable` | Value-based immutable state equality |
| `get_it` | Service locator for DI |
| `go_router` | Declarative routing |
| `shared_preferences` | Local persistence |
| `supabase_flutter` | Cloud backend (auth, database, storage) |
| `flutter_dotenv` | Environment variable loading |
| `intl` + `flutter gen-l10n` | Localization and RTL |
| `bloc_test` / `mocktail` | Testing |

---

## Documentation

| Doc | Purpose |
|-----|---------|
| `DESIGN.md` | Design system tokens and component spec |
| `INSTRUCTIONS.md` | Engineering contract for AI agents and contributors |
| `docs/foundation-walkthrough.md` | Settings/theme/locale foundation walkthrough |
| `docs/storefront-walkthrough.md` | Commerce feature architecture and cubit ownership |
| `docs/money-walkthrough.md` | `Money` value object (integer minor units) walkthrough |
| `docs/supabase-integration.md` | Supabase setup and table-to-entity mapping |
| `docs/staging-verification.md` | Pre/post-deploy verification checklist |
| `docs/release-readiness.md` | Release readiness checklist |
| `docs/acceptance-checklist.md` | Manual acceptance test cases |

---

## Testing

```bash
flutter test
```

Tests cover:
- Cubit state transitions (Cart, Catalog, Orders, Auth)
- Product entity logic (stock, discount, inStock)
- Cross-cubit interactions (wishlist ↔ cart)
- Auth state properties and Profile entity

---

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `supabase/migrations/001_initial_schema.sql` | ~120 | Database tables and indexes |
| `supabase/migrations/002_rls_policies.sql` | ~100 | Row Level Security policies |
| `supabase/migrations/003_auth_profiles_and_hardening.sql` | ~80 | Auth triggers, admin role, order protection |
| `supabase/functions/checkout/index.ts` | ~130 | Server-side checkout Edge Function |
| `lib/shared/services/supabase_config.dart` | ~45 | Supabase initialization |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | ~230 | Auth state machine |

---

## License

Private — Al Batal Elite. Not for redistribution.
