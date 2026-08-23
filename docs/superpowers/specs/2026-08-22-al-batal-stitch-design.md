# Al Batal Elite — Stitch Fabric E-Commerce Design

**Date:** 2026-08-22  
**Stitch Project:** `10846693823016291635` — Al Batal Fabric E-Commerce (TEXT_TO_UI_PRO, MOBILE)  
**Scope:** All 4 flows (Splash/Onboarding/Home, Product Details & Cart, Categories/Profile/Orders, Checkout & Confirmation) — Light + Dark, pixel-perfect to Stitch HTML, rebuild logic where Stitch demands new state  
**Stack:** Flutter 3.x / Dart 3.x / BLoC-Cubit / GetIt / GoRouter / Supabase / Material 3  
**Branch strategy:** Incremental per-flow worktrees (AGENTS.md L2, `lib/` only, max 3 attempts, verifier sub-agent)  
**Author:** Opencode + stitch_get_project + stitch_list_screens + stitch_get_screen evidence

---

## 1. Context & Goals

**Current state (evidence):**
- `lib/app.dart:28` AlBatalApp wires 8 cubits (Settings, Catalog, Cart, Wishlist, Orders, Addresses, Auth, Admin) and `AppTheme.light()/dark()` with `lib/shared/theme/app_theme.dart:5` tokens (emerald #064E3B, gold #D97706, offWhite #FAFAFA) already close to Stitch.
- `lib/shared/routing/app_router.dart:32` has `/home`, `/categories`, `/catalog`, `/product/:id`, `/cart`, `/wishlist`, `/profile`, `/checkout`, `/order-success`, `/profile/orders` — Stitch flows map 1:1 to these routes.
- `lib/shared/theme/app_theme.dart:62` defines `displayLarge` 48/700/-0.96, `headlineLarge` 32/700, `headlineMedium` 24/700, `titleLarge` 20/600, etc., matching `DESIGN.md` alpha version (Montserrat/Inter, radii card 16/control 8/chip 4).
- `lib/features/storefront/presentation/pages/home_page.dart:14` already has PromoBanner/CategoryChips/FlashSale/PopularProducts but with legacy styling (not Stitch circular chips, gold gradient hero, flash timer red badge).
- Stitch `designMd` (stitch_get_project) declares: surface #f9f9f9, primary #003527, primary-container #064e3b, secondary #904d00 / secondary-container #fe932c, tertiary #531e00, radii sm 0.25rem / DEFAULT 0.5rem / md 0.75rem / lg 1rem / xl 1.5rem, typography Montserrat/Inter with slightly different scales (display 48/56/-0.02em, headline-lg-mobile 24/32/700, label-md 14/20/0.01em/500).
- `stitch_list_screens` shows 23 screens; 10 have `htmlCode` downloadUrl with Tailwind config — key ones: `73e4aab0` Splash/Onboarding/Home (780x2102), `7d6fddb5` Product Details & Cart (780x2772), `681d222d` Categories/Profile/Orders (780x3160), `211e0580` / `c6d4e319` / `b8f36a41` Checkout & Confirmation (780x3528), plus dark variants `8340772e`, `98f5eee4`, `4e05cdd4`, `c6d4e319`. Image-only screens (silk/velvet/linen) are assets, not separate routes.

**Goals:**
- Pixel-perfect parity to Stitch screenshots (`downloadUrl` PNG) for light + dark, including gradients (hero `primary/80` → transparent, gold CTA `135deg #B8860B→#FFFA CD→#B8860B`), Micro-interactions (`InkSparkle`), directional RTL mirroring.
- Preserve Clean Architecture `presentation → domain → data`; widgets render, cubits own state, repos return `Result<T>`.
- Rebuild logic where Stitch introduces new behavior (flash-sale countdown timer, hero carousel index) while keeping existing `loading/error/empty/success` contracts.
- Pass `flutter test` (baseline 198 per STATE.md) + `flutter analyze` clean, build artifact has no `.env` (per P0 fix), respect `lib/`-only, no `pubspec.yaml` dep without approval, no `supabase/` migration edits.

**Non-goals:**
- Native Android/iOS code, new `pubspec.yaml` deps (sentry already present), Supabase Edge Function changes, CI/CD workflow edits.

---

## 2. Approaches Considered

| Approach | Description | Pros | Cons | Verdict |
|---|---|---|---|---|
| **A — Incremental per-flow worktree (recommended)** | Phase 0 token sync, then 4 worktrees: `fix/stitch-home` → `fix/stitch-details-cart` → `fix/stitch-categories-orders` → `fix/stitch-checkout` | Low blast radius, `flutter test` gates per phase, respects AGENTS.md L1→L2 + max 3 attempts, parallelizable, tests stay green | 4 PRs vs 1 | **SELECTED** |
| B — Design-system-first + single worktree | Sync tokens + all primitives then reskin all pages in one `fix/stitch-all` | Fastest visual consistency | Large diff (~12 files), hard bisect, violates "smallest change", concentrates test churn | Rejected |
| C — Parallel `/v2/*` routes alongside old | New `stitch_*` pages under `/v2/home` etc., flag via SettingsCubit | Zero regression, A/B compare | Duplicates routing/widgets, doubles maintenance, over-engineers per INSTRUCTIONS.md YAGNI | Rejected |

**Rationale for A:** Human authorized L2 + pixel-perfect + both themes + rebuild-logic; incremental keeps RLS/payment NO-GO gates reviewable and fits LOOP.md verifier-per-phase. Also satisfies INSTRUCTIONS.md teaching contract (explain each phase's problem/plan/alternatives before implementing).

---

## 3. Architecture

```
presentation (pages/widgets/cubit)
   ↓ reads state, dispatches events
domain (entities/useCases/repos interfaces)
   ↓
data (supabase_* repository + mappers)
   ↓
Supabase
```

**Routing** (`lib/shared/routing/app_router.dart:32`): No new paths. Reuse existing `GoRoute`s; only builders' page classes are redesigned. `ShellRoute` with `AppShell` stays, but `NavigationBar` theme matches Stitch (72dp, indicator `primary@12%`, filled home vs outline others, Cart `Badge` secondary `2`).

**Theme sync (Phase 0):**
- `lib/shared/theme/app_theme.dart:5` — add Stitch-exact tokens: `primary #003527`, `primaryContainer #064e3b` (existing emerald), `surface #f9f9f9` (vs offWhite #FAFAFA), `surfaceContainerLow #f3f3f3`, `surfaceContainer #eeeeee`, `surfaceContainerHigh #e8e8e8`, etc., keeping `emerald/gold` as semantic aliases. Update `ColorScheme.light` / `dark` to use `#f9f9f9` scaffold in light, retain `charcoal #121212` + `slate #1E293B` + `dark-primary #95d3ba` for dark (already Stitch-aligned).
- `DESIGN.md` alpha tokens — update `colors` block to add Stitch `surface-*` scale, correct `primary` to `#003527` with `primaryContainer` alias, radii map to `0.5rem` (8dp) control / `1rem` (16dp) card, typography lineHeights to stitch `display 56/48` etc.

**Shared primitives** (`lib/shared/components/stitch/*.dart`):
- `stitch_app_bar.dart`, `stitch_search_bar.dart`, `stitch_hero_carousel.dart`, `stitch_category_chips.dart`, `stitch_flash_sale_card.dart`, `stitch_product_grid_card.dart`, `stitch_bottom_nav.dart` (or theme overlay), `stitch_checkout_summary.dart`, `stitch_shimmer.dart`.
- All use `EdgeInsetsDirectional`, `Material` directional icons, `InkSparkle.splashFactory`, `BorderRadius` tokens only (no hard-coded radii).

**Feature pages:**
- `HomePage` (`lib/features/storefront/presentation/pages/home_page.dart:14`) → Stitch's flex-col Tailwind maps to `ListView(padding:16)` with `SizedBox` gaps `spacing.xl` 24 / `spacing.lg` 16 per DESIGN.md. Sections: search-bar rounded-full, hero 180dp `Stack` with gradient, categories `SingleChildScrollView horizontal`, flash-sale `Card` 120dp row, popular `GridView.builder` 2-col.
- `DetailsPage` (`lib/features/storefront/presentation/pages/details_page.dart:20`) + `CartPage` — Stitch's 2772px details merges gallery, `NameAndPrice` (EGY suffix `label-md` bold), `RatingStars`, `VariantSelector`, `DeliveryInfo`, description, `RelatedCard` horizontal 200dp. Sticky `AddToCartButton` at `bottomNavigationBar` with gold gradient.
- `CategoriesPage`/`CatalogPage:14`/`OrdersPage` — Stitch's 3160px categories/Profile/Orders uses circular category chips + order cards. Reuse existing `CatalogCubit` filters but surface as pill chips + bottom-sheet `FilterSheet`.
- `CheckoutPage` + `OrderSuccessPage` — Stitch's 3528px checkout: address card `surface-container-low`, payment method list, summary `outline-variant` border 1dp, primary CTA `FilledButton` gold. Dark variants use `AppTheme.dark()` automatically.

---

## 4. Components — Tailwind → Flutter token map (pixel-perfect)

| Stitch (HTML) | Flutter token | Notes |
|---|---|---|
| `bg-background #f9f9f9` | `AppTheme.light().scaffoldBackgroundColor` | Sync from `#FAFAFA` → `#f9f9f9` |
| `text-primary #003527` / `bg-primary-container #064e3b` | `ColorScheme.light.primary` / `primaryContainer` | Existing emerald becomes alias |
| `secondary #904d00` / `secondary-container #fe932c` / gold gradient `B8860B→FFFACD` | `ColorScheme.secondary` / `secondaryContainer` + `LinearGradient(135deg)` for CTAs | |
| `rounded-xl` `0.75rem=12dp`? In Stitch xl=0.75rem=12dp, but cards use `xl` for 16dp in Flutter → map Tailwind `xl`→16, `lg`→8 | `AppTheme.cardRadius 16`, `controlRadius 8`, chip `4` | Verify via Tailwind config `lg 0.5rem=8`, `xl 0.75rem=12`, `full 9999` |
| `font-headline-lg-mobile 24/700` / `headline-md 20/600` / `label-md 14/500` | `textTheme.headlineLarge/mobile` `titleLarge` `labelLarge` | Stitch has `-0.02em` display tracking → map to `-0.96` |
| `Material Symbols fill 0/1` | `Icons.texture/apparel/curtains/styler/dry_cleaning/star/favorite/shopping_cart/grid_view/home` with `fontVariation` fill | |
| `aspect-square` + `shadow-sm` `primary 2-4%` | `AspectRatio(1)` + `BoxShadow(color: scheme.primary.withAlpha(.035 light/.12 dark), blur 8, offset (0,3))` per `app_theme.dart:88` | |

**Widget contracts:**
- `StitchHeroCarousel` props: `imageUrl`, `eyebrow`, `title`, `priceOff`, `onShopNow` — stateless, 180dp, `ClipRRect(cardRadius)`.
- `StitchCategoryChips` props: `selected: String`, `onSelect(String)` — horizontal `ListView.separated`.
- `StitchFlashSaleCard` props: `product`, `discountPct`, `onAdd` — 120dp row `Card`, gold `add` fab 32dp.
- `StitchProductGridCard` props: `product`, `onTap`, `onWishlist` — `Card` + `Stack` wishlist heart.

---

## 5. Data Flow

```
UI event (tap chip / type search / tick timer)
 → Cubit method (select/mic/updateQuery/flash tick)
 → State copyWith(visible/isLoading/flashRemaining)
 → BlocBuilder rebuilds primitive subtree only
 → Repo (Supabase) only on load/filter, returns Result<T>
```

- **Home search:** `HomeSearchBar(controller, onChanged: cubit.updateQuery)` → `CatalogCubit` debounces (existing) → `state.visible` filtered, `RecentQueries` Wrap rendered. Voice mic button is stub (shows SnackBar "Voice search coming soon").
- **Flash sale timer:** `CatalogCubit.startFlashSale(end: DateTime.now()+ Duration(hours:2,minutes:45,seconds:12))` → `Timer.periodic(1s, (_) => emit(... remaining))` → `StitchFlashSaleCard` reads `state.flashRemaining` (`Duration`). Canceled on `close`.
- **Categories:** `CategoryChips(state: CatalogState.category, onSelect: cubit.select)` → same `visible` grid, no extra fetch.
- **Dark toggle:** `SettingsCubit` already owns `themeMode`; Stitch header `dark_mode` icon calls `settings.toggleTheme()`. No new state.
- **Cart/wishlist:** `WishlistToggleIcon(productId)` and `AddToCartButton(state)` already read `CartCubit`/`WishlistCubit`; just restyled with Stitch visuals.

---

## 6. Error Handling, Security & Constraints

- **Error states:** Every `Cubit` exposes `status: initial/loading/success/error/empty`. Pages branch: `loading→FeedbackView.loading`, `error→FeedbackView.error(onAction: retry)`, `empty→CatalogEmptyState` (Stitch line-art + primary CTA), `success→content`. Widgets never catch; repos catch and return `Result.failure(AppError)`.
- **Security:** No secrets in `lib/`; no `supabase/` migration edits; no `pubspec.yaml` dep add without human; no `.env` asset; no `auth`/`payments`/`secrets` edits per AGENTS.md Scope & Safety. `flutter build apk --debug` will be smoke-checked for stray `PAYMOB_` strings (already 0 per STATE.md P0).
- **Scope limits:** `lib/` only, one feature worktree at a time, `flutter analyze` + `flutter test` per phase, verifier sub-agent after each.

---

## 7. Testing

- **Unit:** `test/features/storefront/presentation/cubit/catalog_cubit_test.dart` — `flashRemaining` ticks 3s via `fakeAsync`, `select("Silk")` filters, `updateQuery` debounces.
- **Widget:** `test/features/storefront/presentation/pages/home_page_test.dart` — pump with `CatalogState.stub(success, 4 products, flashRemaining 8040s)` → finds `StitchHeroCarousel`, 5 chips, flash card badge `-15%`, 2-col grid 4 cards; tap `Silk` verify `cubit.select` called; theme toggle finds `AppTheme`.
- **No coverage theatre:** Only test logic/state transitions, mapping, error handling per INSTRUCTIONS.md. One behavior per test, deterministic (clock injection for timer).
- **Gates:** `flutter analyze` 0 issues, `flutter test` ≥198 + new passing, `dart analyze lib test` if needed.

---

## 8. Phases & File Ownership

| Phase | Worktree | Files touched | Exit gate |
|---|---|---|---|
| **0 Tokens** | `fix/stitch-tokens` | `lib/shared/theme/app_theme.dart`, `DESIGN.md`, `assets/` if font sync | `flutter analyze` + `flutter test` + token diff vs Stitch `designMd` |
| **1 Home** | `fix/stitch-home` | `lib/features/storefront/presentation/pages/home_page.dart:14`, `lib/shared/components/app_shell.dart`, `lib/shared/components/stitch/*.dart` (4 new), `lib/features/storefront/presentation/cubit/catalog_cubit.dart`, `lib/features/storefront/presentation/widgets/*` (deprecate old) | `flutter test` + screenshot parity vs `73e4aab0`/`8340772e` downloadUrls |
| **2 Details/Cart** | `fix/stitch-details-cart` | `lib/features/storefront/presentation/pages/details_page.dart:20`, `cart_page.dart`, `widgets/variant_selector.dart`, `add_to_cart_button.dart`, `image_gallery.dart` | Parity vs `7d6fddb5`/`98f5eee4` |
| **3 Categories/Orders** | `fix/stitch-categories-orders` | `lib/features/storefront/presentation/pages/categories_page.dart`, `catalog_page.dart:14`, `orders_page.dart` | Parity vs `681d222d`/`4e05cdd4` |
| **4 Checkout** | `fix/stitch-checkout` | `lib/features/storefront/presentation/pages/checkout_page.dart`, `order_success_page.dart`, `lib/features/payments/presentation/pages/payment_method_page.dart` | Parity vs `211e0580`/`c6d4e319`/`b8f36a41` |
| Each | — | No `pubspec.yaml`, no `supabase/`, `worktree` isolated | Verifier sub-agent + human PR approval |

**Rollback:** Each worktree is independent; revert by deleting branch if `test_rls_adversarial.sql` or payment E2E regresses.

---

## 9. Verification Checklist (per phase)

- [ ] `flutter analyze` 0 issues (allow pre-existing `macos` lock noise per STATE.md Watch List, but `lib/` clean)
- [ ] `flutter test` all green (baseline 198 + new widget/unit)
- [ ] `flutter build apk --debug --dart-define-from-file=config/env.staging.local.json` artifact has no `.env` (recursive zip search)
- [ ] Manual: light ↔ dark toggle, English ↔ Arabic RTL (`l10n` `ar`), 390dp device (Stitch MOBILE), screenshot diff < 2% vs Stitch PNG
- [ ] `git status` clean of secrets, `git diff --check` 0 whitespace errors

---

## 10. Risks & Mitigations

- **Token drift Stitch `#F9F9F9` vs `DESIGN.md #FAFAFA`:** Mitigate by Phase 0 single-source sync; document alias rationale in `DESIGN.md` comments.
- **Flash timer `setState` jank on low-end devices:** Use `Stream.periodic` + `BlocBuilder(buildWhen: previous.remaining.inSeconds != next.remaining.inSeconds)` to rebuild only timer text, not grid.
- **Image CDN CORS on Stitch downloadUrls:** Copy URLs to `assets/images/stitch_placeholders/` or use `cached_network_image` fallback (already in I-5 reference repo list) — but no new dep, so use `Image.network` with errorBuilder placeholder `Icons.texture`.
- **Worktree sprawl:** Prune `_worktree-*` via `git worktree prune` before each new phase (AGENTS.md Safety).

---

## 11. References

- Stitch evidence: `stitch_get_project 10846693823016291635`, `stitch_list_screens` (23 screens), `stitch_get_screen 73e4aab0` HTML Tailwind config + screenshots, `stitch_get_screen 7d6fddb5/681d222d/211e0580` parity (fetch on demand).
- App evidence: `lib/shared/theme/app_theme.dart:1`, `DESIGN.md`, `lib/shared/routing/app_router.dart:32`, `lib/features/storefront/presentation/pages/home_page.dart:14`, `lib/features/storefront/presentation/pages/details_page.dart:20`, `lib/features/storefront/presentation/pages/catalog_page.dart:14`, `STATE.md` baseline.
- Constraints: `AGENTS.md` (L1 report-only, L2 worktree, `lib/` only, 3 attempts, verifier), `INSTRUCTIONS.md` (Clean Architecture, BLoC, teaching walkthrough), `LOOP.md`/`loop-constraints.md`.

---

## 12. Approval & Next Steps

Design sections 1–3 approved via superpowers brainstorming (2026-08-22). Next skill: `writing-plans` to generate `docs/superpowers/plans/2026-08-22-stitch-implementation-plan.md` with per-phase checklists, then L2 worktree execution starting Phase 0.
