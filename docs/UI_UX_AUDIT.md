# Al Batal Elite — UI/UX Audit Report

> **STATUS:** ACCEPTED as the authoritative UI/UX baseline (2026-07-28)
> **BASE CANDIDATE:** `release-candidate/e9a6deb` (`e9a6debbb3f807030bab698f8b92241e5b3526d4`)
> **UI/UX MATURITY:** 54/100 · **P0 UI/UX BLOCKERS:** 4+ · **RELEASE:** NO-GO
> **FIX PLAN:** see `docs/UI_UX_FIX_PLAN.md` (Package UI-0)

**Audit type:** Read-only code inspection (no screenshots/recordings provided — visual findings are code-derived)
**Scope:** Customer-facing app under `lib/` (admin screens excluded except where they leak into customer UX)
**Locales inspected:** `l10n/app_en.arb` (280 lines), `l10n/app_ar.arb` (282 lines) — key parity confirmed

---

## 1. UI/UX Audit Summary

### Overall UX Maturity Score: **54 / 100**

| Dimension | Score | Notes |
|---|---|---|
| Architecture & state foundation | 8/10 | Clean cubits, Result types, M3 theme, light+dark, idempotent checkout |
| Money/payment safety | 7/10 | Server-authoritative payments, URL guard, double-submit guards |
| Order transparency | 2/10 | No order details page, dev "advance" button, contradictory status text |
| Localization execution | 4/10 | ARB parity is good, but ~25 hardcoded English strings sit in the money path |
| Error/empty/loading states | 4/10 | Good components exist but many screens skip them |
| Accessibility | 4/10 | Contrast tested; semantics & touch targets mostly unaddressed |
| Trust & honesty | 3/10 | Fake flash-sale countdown, fake share, dead mic button, wrong-product fallback |
| Forms | 4/10 | No phone field for COD delivery, discarded country, silent dialog failure |

### Top 10 Issues

1. **UX-001 (P0)** — Customers can "advance" their own order status from order history ([order_card.dart#L55-L65](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/order_card.dart#L55-L65))
2. **UX-002 (P0)** — Unknown product ID silently renders the *first* catalog product; user can buy the wrong item ([product_details_cubit.dart#L57-L58](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/cubit/product_details_cubit.dart#L57-L58))
3. **UX-003 (P0)** — Shipping address has **no phone number field**; COD delivery is operationally impossible ([address_form.dart](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/address_form.dart))
4. **UX-004 (P0)** — Address form validates "Country is required" then **discards** it (`country: ''`) ([address_form.dart#L49-L58](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/address_form.dart#L49-L58))
5. **UX-005 (P1)** — All payment failure/timeout/cancel messages are hardcoded English; Arabic users get English in the money flow ([payment_method_page.dart#L79-L129](file:///c:/flutter_projects/albatal_store/lib/features/payments/presentation/pages/payment_method_page.dart#L79-L129), [payment_cubit.dart#L212-L267](file:///c:/flutter_projects/albatal_store/lib/features/payments/presentation/cubit/payment_cubit.dart#L212-L267))
6. **UX-006 (P1)** — Cancelled orders display "**Delivered** · date" in the card body while the corner badge says "Cancelled" ([order_card.dart#L50-L54](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/order_card.dart#L50-L54))
7. **UX-007 (P1)** — Fake flash-sale countdown (hardcoded `saleSeconds: 14362`, resets on every launch, tied to no real discount) ([catalog_cubit.dart#L37](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/cubit/catalog_cubit.dart#L37), [flash_sale_section.dart](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/flash_sale_section.dart))
8. **UX-008 (P1)** — Sign-in ignores the `?redirect=` param; after login users land on `/home` instead of the cart/checkout they were heading to ([sign_in_page.dart#L36-L37](file:///c:/flutter_projects/albatal_store/lib/features/auth/presentation/pages/sign_in_page.dart#L36-L37) vs [app_router.dart#L61](file:///c:/flutter_projects/albatal_store/lib/shared/routing/app_router.dart#L61))
9. **UX-009 (P1)** — Server-sourced products render as gray placeholders (`imageColor: 0xFF888888`, no image URL mapping) ([supabase_catalog_repository.dart#L251-L253](file:///c:/flutter_projects/albatal_store/lib/features/storefront/data/supabase_catalog_repository.dart#L251-L253))
10. **UX-010 (P1)** — After closing the Paymob WebView, no "verification in progress" UI exists; user can tap **Pay Now** again while `awaitingVerification` ([payment_method_page.dart#L170-L184](file:///c:/flutter_projects/albatal_store/lib/features/payments/presentation/pages/payment_method_page.dart#L170-L184), [payment_cubit.dart#L117-L119](file:///c:/flutter_projects/albatal_store/lib/features/payments/presentation/cubit/payment_cubit.dart#L117-L119))

### Critical User Journey Risks
- **Browse → Buy:** wrong-product fallback (UX-002) + gray product images (UX-009) undermine purchase confidence.
- **Checkout → Deliver:** no phone number (UX-003) breaks COD fulfillment; discarded country (UX-004) corrupts the address snapshot sent to the server.
- **Pay → Trust:** English-only payment errors (UX-005), no persistent failure screen (snackbars only), no pending-verification UI (UX-010).
- **Post-purchase:** no order details page, no payment method/status/total anywhere in order history; "advance order" button destroys status credibility (UX-001, UX-006).

### Accessibility Risks
- Only 2 `Semantics` usages in the entire app (`product_tile.dart`, `bottom_action_button.dart`).
- Sub-44dp touch targets: cart "Remove"/"Save for later" text buttons (`minimumSize: Size.zero`, `fontSize: 12`).
- Loading state is a static hourglass icon — no live announcement, no motion cue.
- No error announcements (snackbars only, no `SemanticsService.announce`).
- Contrast: covered by `test/contrast_audit_test.dart` (AA 4.5:1 asserted for both themes) — **PASS** at token level.

### RTL Risks
- Layout hygiene is largely good (`AlignmentDirectional`, `EdgeInsetsDirectional` used; only one `Alignment.centerRight` found).
- **But:** ~25 hardcoded English strings appear inside Arabic UI (payments, addresses, checkout totals, sort labels, color filter names).
- `Icons.arrow_forward` used in 4 CTA buttons — does not mirror in RTL.
- Date formatting uses hardcoded English month abbreviations ([order_card.dart#L84-L98](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/order_card.dart#L84-L98)).
- `Money.format()` returns `"1290 EGY"` — wrong code (EGP), never localized, no Arabic display form ([money.dart#L36-L37](file:///c:/flutter_projects/albatal_store/lib/core/entities/money.dart#L36-L37)).
- No Arabic font family: Inter/Montserrat contain no Arabic glyphs; Arabic falls back to system `sans-serif` — brand typography breaks in Arabic.

### Missing States
- Catalog page: no loading/error state — shows "empty results" while loading ([catalog_page.dart#L84-L102](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/catalog_page.dart#L84-L102))
- Product details: infinite spinner on fetch failure (`failure: (_) {}`)
- Orders page: `OrdersStatus.error` unhandled; no pull-to-refresh
- Payment: no dedicated failure/pending screens (transient snackbars only)
- Global: no offline/connectivity detection anywhere

### Missing Feedback
- Address delete: no confirmation
- Address dialog Save: silently does nothing when fields empty ([addresses_page.dart#L92-L94](file:///c:/flutter_projects/albatal_store/lib/features/addresses/presentation/pages/addresses_page.dart#L92-L94))
- COD: no confirmation step before "Pay Now" commits the order
- Cart "Remove" button: no undo (only swipe-dismiss offers undo)

### Missing Design System Components
- Skeleton loader / shimmer (loading is a static icon)
- Status badge (order/payment status colors are ad hoc)
- Unified empty state (two duplicates: `FeedbackView`, `EmptyStateView`)
- Localized price display widget (currency logic scattered: `PriceText`, `money()`, inline `.format()`)
- Confirmation dialog component
- Phone input component

---

## 2. Screen-by-Screen Issue Register

### 2.1 App Startup & Shell
**Works well:** bootstrap failure fallback UI ([main.dart#L58-L62](file:///c:/flutter_projects/albatal_store/lib/main.dart#L58-L62)); crash reporting wired before `runApp`; DEV banner debug-only; M3 light+dark themes; cart badge on nav.
**Broken/weak:**
- No `StatefulShellRoute` → tabs share one navigator; scroll position and sub-state lost on tab switch; `/catalog` (inside shell) highlights the **Home** tab (`_index` has no `/catalog` case, [app_shell.dart#L56-L62](file:///c:/flutter_projects/albatal_store/lib/shared/components/app_shell.dart#L56-L62)).
- Cart and Wishlist tabs are auth-gated ([app_router.dart#L55-L57](file:///c:/flutter_projects/albatal_store/lib/shared/routing/app_router.dart#L55-L57)) — a guest tapping the Cart tab is bounced to sign-in. Guests cannot build a cart at all, a major conversion killer.
- `GoRouter` has no `refreshListenable` on `AuthCubit` — session expiry mid-session is only enforced on the next navigation.
- No splash/branding screen; no onboarding.
**Missing states:** offline banner; splash.

### 2.2 Home / Storefront
**Works well:** loading + error states via `FeedbackView` with retry; recent search chips with delete; promo banner fully localized; categories/flash-sale/popular sections composed cleanly.
**Broken/weak:**
- Settings action uses `Icons.dark_mode_outlined` — reads as a theme toggle, opens Settings ([home_page.dart#L63-L67](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/home_page.dart#L63-L67)).
- Fake flash-sale countdown (UX-007); ticks re-emit `CatalogState` every second → the entire home `BlocBuilder` subtree rebuilds 1×/sec (perf + battery).
- Dead mic button (`onPressed: () {}`) in search bar ([home_search_bar.dart#L39-L43](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/home_search_bar.dart#L39-L43)).
- `l.goodMorning` greeting is static regardless of time of day.
- Loading state is a static hourglass — no skeleton.

### 2.3 Catalog / Search / Filters
**Works well:** filter bottom sheet, active-filters bar with clear-all, filter count badge, debounced recent-query recording, query passed via `/catalog?q=`.
**Broken/weak:**
- AppBar title is `l.categories` ("Categories") on the catalog/search screen — wrong title, and it collides with the actual Categories tab ([catalog_page.dart#L48](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/catalog_page.dart#L48)).
- **No loading/error handling** — during load or on failure the grid shows the "no results, clear filters" empty state, which is a lie about system status.
- Sort labels hardcoded English (`'Price: low to high'`… [catalog_cubit.dart#L12-L20](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/cubit/catalog_cubit.dart#L12-L20)); color filter names English-only (`'Emerald'`, `'Gold'`… L267-280); `'All'` category sentinel not localized.
- No pagination (whole catalog fetched at once) — acceptable now, cliff later.

### 2.4 Product Details
**Works well:** variant chips, stock badge with "Only X left", quantity clamped to variant stock, related products, size guide, out-of-stock disables CTA, added-to-cart snackbar.
**Broken/weak:**
- **Wrong product fallback** (UX-002) and infinite spinner on fetch failure (`failure: (_) {}`) — no "product not found" or retry state.
- Share button shows "link copied" but copies nothing — fabricated feedback ([details_page.dart#L48-L53](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/details_page.dart#L48-L53)).
- No image gallery for server products (assets only); no price-per-unit clarity for fabric (price vs. length variant relationship unexplained).
- AppBar title is the category, not the product name.

### 2.5 Cart
**Works well:** swipe-to-delete with Undo snackbar; optimistic persistence with failure surfacing; localized quantity stepper with tooltips; subtotal/shipping/total summary.
**Broken/weak:**
- Empty state has no CTA ([cart_page.dart#L22-L27](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/cart_page.dart#L22-L27)) — `EmptyStateView` supports `actionLabel`/`onAction` but they're not passed. No "Continue shopping".
- "Save for later" calls `WishlistCubit.toggle()` — if the item is *already* wishlisted it is removed from **both** cart and wishlist → silent data loss ([cart_item_tile.dart#L96-L106](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/cart_item_tile.dart#L96-L106)).
- "Remove" text button deletes with no undo (inconsistent with swipe path).
- Quantity clamped 1–99 with **no stock validation** in cart (stock only enforced on details page).
- Shipping displayed as flat client-side `Money.egp(75)` ([cart_cubit.dart#L25](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/cubit/cart_cubit.dart#L25)) which may diverge from the server-computed shipping shown later.
- Sub-44dp touch targets on Remove/Save-for-later.
- Cart persistence error message hardcoded English (`'Cart may not be saved: …'`).

### 2.6 Checkout
**Works well:** idempotency key reuse on retry (excellent duplicate-order prevention); step indicator; address-required validation with inline error; button disabled + spinner while creating order; server totals displayed after order creation.
**Broken/weak:**
- `'Server-confirmed totals'`, `'Subtotal'`, `'Shipping'`, `'Total'` hardcoded English ([checkout_page.dart#L116-L125](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/checkout_page.dart#L116-L125)).
- Two totals shown simultaneously (client `CartSummary` + "Server-confirmed totals" card) with no explanation of which one the user pays — confusing when they differ.
- Raw exception leaked to snackbar: `'Failed to create order: $e'` ([checkout_cubit.dart#L173](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/cubit/checkout_cubit.dart#L173)).
- No empty-cart guard — `/checkout` is reachable with an empty cart, and the button enables once an address exists.
- Fallback `customerEmail: 'customer@example.com'` sent to the payment provider ([checkout_page.dart#L44-L45](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/checkout_page.dart#L44-L45)).
- Address added at checkout (`AddressForm.show`) is only passed to `CheckoutCubit` — never saved to `AddressesCubit`, so it vanishes from "saved addresses".
- Address model duplicated: `core/entities/address.dart` vs `features/addresses/domain/address.dart`.

### 2.7 Payments
**Works well:** server-authoritative status via Realtime watch (never trusts callback URL); Paymob URL allow-list guard both at initiation and in the WebView `NavigationDelegate`; 15-min timeout matching server order expiry; timeout never claims success; button disabled during `processing`.
**Broken/weak:**
- All 8 user-facing payment strings hardcoded English (UX-005).
- `awaitingVerification` has **no on-page UI**: after the user closes the WebView (X button, no confirmation), the payment method page looks idle; "Pay Now" is enabled and can re-initiate payment for the same order (UX-010).
- Terminal failures produce only a transient snackbar — no persistent failure/pending screen with retry and "check my orders" affordances.
- COD confirms immediately on "Pay Now" — no "Confirm COD order for X EGP?" step; for money actions a confirm step is standard.
- No order summary (items) on the payment page — only the total.

### 2.8 Order Success
**Works well:** localized title/body; graceful missing-order-ID state; Track order + Continue shopping CTAs; `context.go` prevents back-into-payment.
**Broken/weak:**
- Missing-ID message hardcoded English ([order_success_page.dart#L27](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/order_success_page.dart#L27)).
- Raw order UUID displayed as `#<uuid>` — unreadable; no short order number.
- No expected delivery, no payment-method recap, no order summary.

### 2.9 Orders History
**Works well:** Active/Completed/Cancelled tabs; localized empty states per tab; loading state.
**Broken/weak:**
- **"Advance order" customer button** (UX-001) — a local dev tool shipped in customer UI, localized into Arabic too (`"advanceOrder": "تقديم الطلب"`).
- Cancelled/refunded cards read "Delivered · date" (UX-006); the date shown is `placedAt`, mislabeled as delivery.
- Status collapse: `pending/placed/paid/processing` → all "Placed" — payment state invisible; user who paid by card cannot verify their order is paid ([order_card.dart#L72-L81](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/widgets/order_card.dart#L72-L81)).
- No order details page: no items list, no total, no payment method/status, no shipping address, no cancel/reorder.
- No error state (`OrdersStatus.error` unhandled in [orders_page.dart](file:///c:/flutter_projects/albatal_store/lib/features/storefront/presentation/pages/orders_page.dart)); no pull-to-refresh.
- English month names in dates.

### 2.10 Auth
**Works well:** clean sign-in form; password visibility toggle; loading state on submit; friendly error mapping at data boundary (`_mapAuthError`); guest continue; forgot/reset flow present.
**Broken/weak:**
- Redirect param dropped after login (UX-008).
- No `AutofillHints` (email/password) — no password-manager integration.
- Email validation is only `contains('@')`.
- `Alignment.centerRight` for forgot-password link — not directional (RTL).
- Mapped error strings are English-only.

### 2.11 Profile / Account / Addresses / Settings
**Works well:** guest profile state with sign-in CTA; settings has proper theme (system/light/dark) and language radios; addresses support default/edit/delete.
**Broken/weak:**
- No Settings entry on Profile — settings reachable only via the (mislabeled) home AppBar icon.
- No edit-profile UI (the `editProfile` l10n key exists, unused); no account deletion (Google Play account-deletion policy risk for published apps).
- Logout: no confirmation dialog.
- Addresses page: menu items + dialog fully hardcoded English (`'Set as default'`, `'Edit'`, `'Delete'`, `'Add address'`, `'Cancel'`, `'Save'`, field labels).
- Delete has no confirmation; Save silently no-ops on empty fields; `TextField` (not `TextFormField`) → no inline errors; no phone field.
- Addresses stored in SharedPreferences only ([service_locator.dart#L51-L52](file:///c:/flutter_projects/albatal_store/lib/shared/services/service_locator.dart#L51-L52)) — lost on reinstall/device change, invisible to support staff.
- Raw `s.errorMessage!` rendered on failure.

### 2.12 Wishlist
**Works well:** empty state **with** CTA ("Explore categories"); grid reuses product tiles; persisted.
**Broken/weak:** empty title is generic "No items found" instead of wishlist-specific copy; move-to-cart uses default variant (`'Emerald'`, `'2m'` defaults in `CartCubit.add`) without asking the user to choose.

---

## 3. Prioritized Issue Table

| ID | Screen | Issue | Sev | Impact | Fix | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|---|
| UX-001 | Orders | Customer "Advance order" button mutates order status | **P0** | Users fake-progress orders; status meaningless; support chaos | Remove button + `advanceOrder` key from customer UI (keep in admin) | XS | Low | No status-mutating control on customer order card; `flutter test` green |
| UX-002 | Product details | Unknown ID falls back to first product | **P0** | User views/buys wrong product | Return not-found state; render "Product not found" + back CTA | S | Low | Invalid `/product/xyz` shows not-found, never another product |
| UX-003 | Address form ×2 | No phone number field | **P0** | COD orders undeliverable; courier can't call | Add required phone field (EG format `01XXXXXXXXX`, `TextInputType.phone`, `AutofillHints.telephoneNumber`) in both forms + snapshot | M | Med (server snapshot schema — needs backend review) | Order address snapshot contains validated phone; form blocks invalid |
| UX-004 | Checkout address form | Country validated then discarded (`country: ''`) | **P0** | Corrupt address data on server order | Pass `_countryCtrl.text.trim()` into `Address` | XS | Low | Created order snapshot contains entered country |
| UX-005 | Payments | 8 payment error/status strings hardcoded English | P1 | Arabic users can't read money-flow errors | Move to ARB (both locales), reference via l10n; map cubit errors to keys | S | Low | Grep shows no literal English UI strings in `features/payments`; AR snapshot verified |
| UX-006 | Orders | Cancelled orders show "Delivered · date" | P1 | User misled about order outcome | Branch label by status; label date as "Placed on" | XS | Low | Cancelled card shows "Cancelled"; date labeled correctly |
| UX-007 | Home | Fake flash-sale countdown | P1 | Fabricated urgency = trust/dark-pattern; possible store-policy issue | Remove section until real sale data exists (or drive from server `sale_ends_at`) | S | Low | No countdown unless backed by real sale entity |
| UX-008 | Sign-in | `?redirect=` ignored after login | P1 | Cart/checkout intent lost; conversion drop | Read `redirect` query in `SignInPage`, `context.go(redirect ?? '/home')` (validate as internal path) | S | Low | Guest tapping Cart → sign-in → lands back on `/cart` |
| UX-009 | Catalog | Server products render gray placeholders | P1 | No product photography = no purchases | Map `images` column to UI; add `cached_network_image` with placeholder/error builders | M | Med (needs image URLs in DB) | Server product shows its photo; failed loads show branded fallback |
| UX-010 | Payment method | No `awaitingVerification` UI; Pay Now re-enabled | P1 | Duplicate payment attempts; user confusion after closing WebView | Add persistent "Verifying payment…" panel w/ spinner + cancel; block `processPayment` during `awaitingVerification` | M | Med | Closing WebView shows verifying state; Pay Now disabled until terminal state |
| UX-011 | Payment method | Failures surfaced only as transient snackbars | P1 | Users miss failure reason; no clear retry path | Inline persistent status card for failed/cancelled/expired/timedOut w/ Retry + View orders | M | Low | Terminal states render persistent card; snackbar optional supplement |
| UX-012 | Catalog page | No loading/error state (empty state shown instead) | P1 | "No results" lie during load/failure | Handle `CatalogStatus.loading/error` before `visible.isEmpty` | S | Low | Loading skeleton during load; error+retry on failure |
| UX-013 | Orders | No customer order details page (items, total, payment method/status, address) | P1 | Users can't verify what they ordered or paid | Add `/profile/orders/:id` page fed by orders repo | L | Med | Tapping order opens details with items, totals, payment + shipping info |
| UX-014 | Addresses | English-only menus/dialog; no delete confirmation; silent save failure | P1 | Arabic users blocked; accidental deletions | Localize all strings; confirm dialog on delete; `Form` validation with inline errors | S | Low | All strings from ARB; delete confirms; invalid save shows field errors |
| UX-015 | Cart | "Save for later" can delete item from cart *and* wishlist | P1 | Silent data loss | Use explicit `addToWishlist` (idempotent) instead of `toggle` | XS | Low | Item already wishlisted stays wishlisted; cart item moves, never vanishes |
| UX-016 | Router/shell | Guests can't open Cart/Wishlist tabs (auth wall) | P1 | Guest conversion killed; unusual e-commerce pattern | Allow guest cart/wishlist (local repos already support it); require auth at `/checkout` only | M | Med (business decision) | Guest adds to cart, sees cart, is asked to sign in at checkout |
| UX-017 | Checkout | Raw exception in snackbar (`Failed to create order: $e`) | P1 | Technical jargon leaks to users | Map to friendly localized message; log the raw error | XS | Low | No exception text ever rendered |
| UX-018 | Checkout | Empty-cart checkout not guarded | P1 | Zero-item order attempt; server error surfaced raw | Redirect/disable when `cart.items.isEmpty` | XS | Low | `/checkout` with empty cart shows empty-cart state |
| UX-019 | Global | `Money.format()` = "1290 EGY", unlocalized | P1 | Wrong currency code on every price; Arabic users see Latin-only prices | Localized formatter (`intl NumberFormat.currency`, `ar`: "ج.م."/EGP) via one `PriceText`-style widget | M | Med (touches all price call sites; keep integer math) | EN: "EGP 1,290"; AR: "١٬٢٩٠ ج.م." (or agreed style); all screens use it |
| UX-020 | Global | No offline/connectivity handling | P1 | Silent hangs on network loss | Connectivity listener + offline banner; retryable errors distinguish network vs server | M | Low | Airplane mode shows offline indicator; retry works on reconnect |
| UX-021 | Product details | Fake share ("link copied", nothing copied) | P1 | Fabricated feedback erodes trust | Implement `share_plus`/`Clipboard` with deep link, or remove button | S | Low | Share invokes real share sheet or button absent |
| UX-022 | Orders | Payment status never shown (paid/pending collapsed to "Placed") | P1 | Card payer can't confirm payment landed | Distinct labels: Pending payment / Paid / Processing; payment badge on card | S | Low | Paid card order shows "Paid"; pending shows "Awaiting payment" |
| UX-023 | Orders | No error state / no pull-to-refresh | P1 | Stale or blank order list, no recovery | Handle `OrdersStatus.error` + `RefreshIndicator` | S | Low | Failure shows retry; pull-to-refresh refetches |
| UX-024 | Checkout | Dual totals (client vs server) unexplained | P2 | Which total will I pay? | Hide client `CartSummary` once server totals arrive; label final total | S | Low | Single authoritative total visible at payment time |
| UX-025 | Cart | Empty cart state lacks CTA | P2 | Dead end | Pass `actionLabel: continueShopping` → `/home` | XS | Low | Empty cart shows CTA that navigates home |
| UX-026 | Cart | No stock validation on quantity update | P2 | Over-order → checkout failure later | Clamp to available stock; show "only X available" | S | Med (needs stock lookup in cart) | Quantity cannot exceed stock; feedback shown |
| UX-027 | Shell | `/catalog` highlights Home tab; tab state not preserved | P2 | User loses place; wrong "you are here" | `StatefulShellRoute.indexedStack`; add catalog index case | M | Med | Tab state survives switching; correct tab highlighted |
| UX-028 | Home | Settings icon is `dark_mode_outlined` | P2 | Icon lies about action | Use `Icons.settings_outlined` | XS | Low | Settings action uses settings glyph |
| UX-029 | Home/search | Dead mic (voice search) button | P2 | Fake affordance | Remove until speech-to-text implemented | XS | Low | No non-functional controls |
| UX-030 | Global | Loading = static hourglass icon | P2 | App feels frozen | `CircularProgressIndicator` minimum; skeletons for catalog/home lists | M | Low | All loading states animate; grids show skeletons |
| UX-031 | Catalog | Sort labels + color names English-only | P2 | Mixed-language Arabic UI | Localize `CatalogSortLabel` + color names via ARB | S | Low | AR locale shows Arabic sort/color labels |
| UX-032 | Global RTL | `Icons.arrow_forward` in CTAs doesn't mirror | P2 | Backwards arrows in Arabic | Swap for `Icons.arrow_forward` wrapped in directional icon or use `Icons.chevron` w/ `matchTextDirection`; simplest: `Directionality`-aware icon | XS | Low | AR: CTA arrows point left (forward) |
| UX-033 | Orders | English month names in dates | P2 | Unlocalized dates in AR | `DateFormat.yMMMd(locale)` | XS | Low | AR shows Arabic-formatted date |
| UX-034 | Global | No Arabic brand font (Inter/Montserrat lack Arabic) | P2 | Arabic renders in system font; brand inconsistency | Add Arabic family (e.g., Cairo/Tajawal/IBM Plex Arabic) in fallback chain | S | Low | Arabic text uses bundled Arabic font |
| UX-035 | A11y | Sparse Semantics; sub-44dp targets in cart | P2 | Screen-reader & motor-impaired users struggle | Add semantics labels to icon-only/state widgets; raise min target sizes | M | Low | `accessibility_test.dart` extended: tap-target + label guidelines pass |
| UX-036 | Auth | No `AutofillHints`; weak email validation | P2 | No password manager support | Add autofill hints, regex email check | XS | Low | Autofill offers credentials on sign-in |
| UX-037 | Profile | No settings/edit-profile entries; logout unconfirmed | P2 | Feature discoverability; accidental logout | Add Settings tile; confirm logout | S | Low | Settings reachable from profile; logout asks confirmation |
| UX-038 | Home | `CatalogState` re-emits every second (timer) | P2 | Constant rebuilds; jank/battery | Remove countdown (UX-007) or isolate ticker into dedicated widget/cubit | S | Low | No 1 Hz rebuild of home tree |
| UX-039 | Design system | Duplicate empty-state components (`FeedbackView` vs `EmptyStateView`) | P2 | Inconsistent visuals | Merge into one configurable component | S | Low | Single empty/error/loading component used everywhere |
| UX-040 | Addresses | Local-only storage (SharedPreferences) | P2 | Addresses lost on reinstall; not visible cross-device | Server-backed address repo (needs backend table + RLS — human review per project rules) | L | High (backend) | Addresses persist across reinstall for signed-in users |
| UX-041 | Order success | Raw UUID; no delivery estimate or summary | P2 | Weak confirmation moment | Short order number, expected-delivery copy, mini summary | S | Low | Success shows human order ref + delivery expectation |
| UX-042 | Payments | No COD confirm step | P2 | Accidental order commitment | Confirm sheet: "Place COD order for {total}?" | S | Low | COD requires explicit confirm before RPC |
| UX-043 | Profile | No account deletion | P2 | Play Store account-deletion policy risk | Add delete-account flow (needs backend function — human review) | L | High (backend) | Deletion entry point exists and works |
| UX-044 | Home | Static "Good morning" greeting | P3 | Minor mismatch at night | Time-based greeting keys | XS | Low | Greeting matches local time bucket |
| UX-045 | Wishlist | Generic empty copy; move-to-cart uses default variant | P3 | Weak microcopy; wrong variant risk | Wishlist-specific copy; route move-to-cart via details page | S | Low | Copy specific; variant chosen explicitly |
| UX-046 | Shell | Cart badge unbounded (`99+` not handled) | P3 | Layout blowout at high counts | Cap display at `99+` | XS | Low | Badge never exceeds 3 chars |
| UX-047 | Details | AppBar shows category not product name | P3 | Weaker context | Show product name (ellipsized) | XS | Low | Title = product name |

*(Effort: XS < 0.5d, S = 0.5–1d, M = 1–3d, L = 3d+)*

---

## 4. Fix Roadmap

### Phase 0 — Purchase/Payment Blockers *(target: immediately)*
UX-001, UX-002, UX-003, UX-004, UX-010, UX-018, UX-006, UX-022
> Everything that misleads about money/orders or breaks COD fulfillment.

### Phase 1 — Core Usability *(week 1–2)*
UX-005, UX-008, UX-011, UX-012, UX-014, UX-015, UX-017, UX-023, UX-025, UX-026, UX-020

### Phase 2 — Trust & Clarity *(week 2–3)*
UX-007, UX-009, UX-013, UX-019, UX-021, UX-024, UX-041, UX-042, UX-016 (guest cart — needs product decision)

### Phase 3 — Accessibility & RTL *(week 3–4)*
UX-031, UX-032, UX-033, UX-034, UX-035, UX-036, plus sign-in `Alignment.centerRight` → `AlignmentDirectional.centerEnd`

### Phase 4 — Visual Polish & Design System *(week 4–5)*
UX-027, UX-028, UX-029, UX-037, UX-039, UX-045, UX-046, UX-047, component inventory (§6), tokens (§7)

### Phase 5 — Performance & Delight *(week 5+)*
UX-030 (skeletons), UX-038, UX-044, image caching, hero transitions on product tap, optimistic wishlist toggle animation
Backend-dependent items tracked separately (human review required per `AGENTS.md`): UX-040, UX-043, image URLs for UX-009.

---

## 5. Implementation Plan

### Phase 0 — Purchase/Payment Blockers
- **Goal:** No customer can be misled about a product, order status, or payment; COD orders are deliverable.
- **Files:** `order_card.dart`, `orders_cubit.dart`, `product_details_cubit.dart`, `details_page.dart`, `address_form.dart`, `addresses_page.dart`, `payment_method_page.dart`, `payment_cubit.dart`, `checkout_page.dart`, both ARB files.
- **Tasks:** remove advance button; add `DetailsStatus {loading, ready, notFound, error}` to details cubit; add phone field + fix country pass-through; add verifying-payment panel + block re-initiation; empty-cart guard; fix cancelled-order label.
- **Effort:** ~4–5 dev-days. **Dependencies:** none client-side; phone-in-snapshot needs backend ack (snapshot is a JSON map — likely additive-safe, but confirm RPC validation).
- **Regression checks:** `flutter test` (notably `payment_checkout_flow_test`, `cod_server_confirm_test`, `orders_cubit_test`, `address_form_test`, `details_page_test`), `flutter analyze`.
- **DoD:** all Phase 0 acceptance criteria pass; AR + EN manual walkthrough of buy flow.

### Phase 1 — Core Usability
- **Goal:** Every screen has honest loading/error/empty states; forms validate visibly; auth redirect works.
- **Files:** `catalog_page.dart`, `orders_page.dart`, `sign_in_page.dart`, `cart_page.dart`, `cart_item_tile.dart`, `checkout_cubit.dart`, `addresses_page.dart`, new `connectivity` service, ARBs.
- **Effort:** ~5–6 dev-days. **Dependencies:** Phase 0 ARB additions.
- **Regression:** widget tests for each state branch; `catalog_cubit_test`, `cart_cubit_test`.
- **DoD:** no screen can render a false "empty" during load; no raw exception strings; redirect-after-login verified.

### Phase 2 — Trust & Clarity
- **Goal:** Prices, totals, order history, and promotions are truthful and complete.
- **Files:** `money.dart`/new `PriceFormatter`, `price_text.dart`, new `order_details_page.dart` + route, `flash_sale_*`, `supabase_catalog_repository.dart`, `order_success_page.dart`.
- **Effort:** ~7–8 dev-days. **Dependencies:** product image URLs in DB (backend); sale entity (or removal).
- **Regression:** money formatting golden tests EN/AR; `orders_cubit_test`.
- **DoD:** single authoritative total; order details complete; no fabricated UI elements remain.

### Phase 3 — Accessibility & RTL
- **Goal:** WCAG-AA-oriented pass; Arabic experience equals English.
- **Files:** theme (Arabic font), all CTA icons, `order_card.dart` dates, catalog labels, `accessibility_test.dart` extensions.
- **Effort:** ~4 dev-days.
- **Regression:** extend `accessibility_test.dart` with `textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`; AR screenshot review.
- **DoD:** checklists §8/§9 all PASS or consciously waived.

### Phase 4 — Visual Polish & Design System
- **Goal:** One component per concept; tokens documented and enforced.
- **Files:** `shared/components/*`, merge `FeedbackView`/`EmptyStateView`, `app_shell.dart` (StatefulShellRoute).
- **Effort:** ~5 dev-days. **Dependencies:** none.
- **DoD:** component inventory §6 exists in code; no ad-hoc text styles in money/status contexts.

### Phase 5 — Performance & Delight
- **Goal:** Perceived speed and premium feel.
- **Tasks:** skeleton loaders, remove 1 Hz rebuild, `cached_network_image`, hero image transition, wishlist micro-animation.
- **Effort:** ~4 dev-days.
- **DoD:** no full-page rebuild per second (DevTools verified); skeletons on home/catalog/orders.

---

## 6. UI Component Inventory (to standardize)

| Component | Today | Action |
|---|---|---|
| Primary button | `AppButton.primary` + raw `FilledButton` mixed | Route all through `AppButton`; add loading variant |
| Secondary button | `AppButton.outline` + raw `OutlinedButton` | Consolidate |
| Danger button | ✗ (ad-hoc red `TextButton`) | Add `AppButtonStyle.danger` |
| Loading button | Inline spinner hacks in 3 pages | Fold into `AppButton(isLoading:)` (pattern exists in `BottomActionButton`) |
| Text input | Theme-level only | `AppTextField` wrapper (label, error, autofill, keyboard type) |
| Phone input | ✗ | New — EG format + validation |
| Address form | 2 divergent implementations (bottom sheet vs dialog) | One `AddressForm` used by both addresses page & checkout |
| Product card | `ProductTile` ✓ | Add discount badge + stock hint |
| Order card | `OrderCard` (needs status fixes) | Rework with `StatusBadge`, total, tap→details |
| Payment method card | `_PaymentOption` (private) | Promote to shared component |
| Status badge | ✗ (`StockBadge` exists for stock only) | Generic `StatusBadge(color, label)` for order+payment |
| Price display | `PriceText` + `money()` + inline `.format()` | Single localized `PriceText` everywhere |
| Quantity selector | `QuantityStepper` ✓ (has tooltips) | Add max-stock feedback |
| Empty state | `FeedbackView` + `EmptyStateView` duplicates | Merge |
| Error state | `FeedbackView.error` | Keep; add message param |
| Loading skeleton | ✗ | New shimmer components (product grid, order list) |
| Dialog | Raw `AlertDialog`s, unlocalized | `AppDialog.confirm()` localized helper |
| Bottom sheet | Consistent 20px top radius ✓ | Codify as token |
| Snackbar/toast | Raw `ScaffoldMessenger` everywhere | `AppSnackbar.success/error/info` helper + theme |
| Rating | `RatingStars` ✓ | Keep |

---

## 7. Design Token Proposal

A design system partially exists ([app_theme.dart](file:///c:/flutter_projects/albatal_store/lib/shared/theme/app_theme.dart), `DESIGN.md`). Gaps to formalize:

- **Colors:** keep emerald `#064E3B` / gold `#D97706` / terracotta error; **add semantic aliases**: `success` (currently primary doubles as success), `warning`, `info`, `pending` (order status needs non-error amber).
- **Typography:** existing Montserrat display / Inter body scale is solid. **Add Arabic families** (e.g., Cairo for display, IBM Plex Sans Arabic for body) as locale-aware fallback.
- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 (already the de facto rhythm — name them `space1..space6`).
- **Radius scale:** 4 (chip) / 8 (control) / 12 (image) / 16 (card) / 20 (sheet) — currently implicit; codify (12 for images is used but undeclared).
- **Elevation:** level 0 (flat cards) + "subtle halo" shadow (primary @ 3.5%/12%) — already consistent, document it.
- **Icon sizes:** 14 (inline) / 18 (button) / 24 (default) / 48–64 (empty states).
- **Touch targets:** minimum 48×48dp (fix cart text buttons).
- **Layout margins:** 16dp page padding (consistent today), 24dp for auth/empty layouts.
- **Button height:** 50dp (already tokenized via `minimumSize`).
- **Input height:** derived from 14dp vertical padding — declare ≥48dp.

---

## 8. Accessibility Checklist

| Check | Status | Evidence |
|---|---|---|
| Contrast (theme tokens) | **PASS** | `test/contrast_audit_test.dart` asserts AA 4.5:1 both themes |
| Contrast (ad-hoc alphas, e.g. hint @ .55, secondary small text) | **UNKNOWN** | Not covered by token tests |
| Touch targets ≥48dp | **FAIL** | Cart Remove/Save-for-later: `minimumSize: Size.zero`, 12sp |
| Semantics labels | **FAIL** (partial) | Only 2 `Semantics` widgets; icon buttons rely on tooltips |
| Focus order | **UNKNOWN** | No `FocusTraversalGroup`; untested |
| Screen reader support | **PARTIAL** | ProductTile labeled; status badges, price rows, steppers unlabeled as groups |
| Text scaling | **UNKNOWN** | No `textScaleFactor` clamping or overflow tests; fixed-height sections (200px related list, 170px banner) at risk |
| Color-only indicators | **PASS** | Stock badge & payment selection pair color with text/icon |
| RTL support | **PARTIAL** | Directional APIs mostly used; arrow icons + 1 alignment miss |
| Error announcements | **FAIL** | Snackbar-only; no `SemanticsService.announce` |
| Loading announcements | **FAIL** | Static icon; no live region |

## 9. RTL / Arabic Checklist

| Check | Status | Evidence |
|---|---|---|
| Layout mirroring | **PASS** (mostly) | `AlignmentDirectional`/`EdgeInsetsDirectional` used; 1 exception in sign-in |
| Text alignment | **PASS** | No hardcoded `TextDirection` found |
| Icon direction | **FAIL** | `Icons.arrow_forward` in 4 CTAs won't mirror |
| Number formatting | **FAIL** | Western digits, no locale-aware `NumberFormat` |
| Currency formatting | **FAIL** | `"1290 EGY"` — wrong code, unlocalized ([money.dart#L36](file:///c:/flutter_projects/albatal_store/lib/core/entities/money.dart#L36)) |
| Date formatting | **FAIL** | Hardcoded English months in order cards |
| Arabic text overflow | **UNKNOWN** | No screenshots; `maxLines: 1` product names + longer Arabic strings = risk |
| Translation completeness (ARB) | **PASS** | EN/AR key parity confirmed |
| Translation completeness (runtime) | **FAIL** | ~25 hardcoded English strings (payments, addresses, checkout totals, sort/color labels) |
| Arabic font readability | **FAIL** | No Arabic font bundled; brand fonts lack Arabic glyphs → system fallback |

---

## 10. Missing Information (could not verify)

- **Screenshots/recordings:** none provided — all visual/overflow findings are static-analysis inferences; an on-device AR + dark-mode pass is still needed.
- **Runtime behavior:** did not run the app or payments (read-only mandate) — perceived performance, jank, and WebView behavior unverified.
- **Backend contracts:** `create_checkout_order` RPC validation rules (does it reject empty carts? does the address snapshot schema allow a `phone` field?), server shipping-fee logic vs the client's flat EGP 75, and whether `initiatePayment` is idempotent per order.
- **Product images:** whether the Supabase `products` table has populated `images` URLs (the client currently ignores them for display).
- **Deep linking / App Links:** no `android:autoVerify` intent-filter inspection was done; GoRouter paths exist but external deep-link config unverified.
- **Expired-order UX:** `expiresAt` is captured in `CheckoutState` but never surfaced; what the user sees when a pending order expires mid-payment is untested.
- **Push notifications / order update notifications:** absent from code; unknown if planned.
- **Design guidelines:** `DESIGN.md` exists and theme matches it; no Figma/source-of-truth was available to diff against.
- **Admin app expectations:** admin pages exist in the same bundle behind an `isAdmin` guard — whether the "advance order" capability was meant to live only there needs product confirmation.

---

**Bottom line:** the engineering foundation (payment safety, state management, theming, l10n infrastructure) is genuinely strong — but the customer-facing surface currently contains four P0 trust/fulfillment breakers (advance-order button, wrong-product fallback, missing phone number, discarded country) that should be fixed before any release, followed by the localization of the entire money path. Phases 0–1 (~2 weeks) would move this app from "demo-quality storefront" to "shippable customer experience."