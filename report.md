# UI/UX & User-Flow Audit — Al Batal Elite (v1.0.0-alpha)

**Mode:** READ-ONLY (L1 report-only). No files modified, generated, committed, or deployed.
**Date:** 2026-07-22
**Auditor:** Kilo (code-inspected only — no device/emulator runs)
**Constraints verified:** `AGENTS.md`, `loop-constraints.md`, `STATE.md` — all read before audit.

---

## 1. Repository Constraints (verified)

| Rule | Status |
|------|--------|
| L1 = report-only, no code changes | Enforced |
| Never edit `.env`, `auth/`, `payments/`, `secrets/` | N/A (read-only) |
| Auto-fixes limited to `lib/` | N/A (read-only) |
| Never modify `pubspec.yaml`, CI/CD, `analysis_options.yaml` | N/A (read-only) |
| Max 3 fix attempts per item | N/A (read-only) |
| Run `flutter test` + `flutter analyze` before proposing fixes | Deferred to L2 |
| `STATE.md` reports 223/223 tests, 0 analyze issues | Confirmed |

---

## 2. Flow Map

```
                    ┌──────────────┐
                    │  App Launch  │
                    │  main.dart   │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
     ┌──────────────┐          ┌──────────────┐
     │ AuthCubit    │          │ SettingsCubit│
     │ checkSession │          │ load()       │
     └──────┬───────┘          └──────┬───────┘
            │                         │
            ▼                         ▼
     ┌──────────────────────────────────────┐
     │           MaterialApp.router          │
     │           app_router.dart             │
     │           (GoRouter)                  │
     └──────────────────┬─────────────────────┘
                        │
     ┌──────────────────┼──────────────────┐
     │                  │                  │
     ▼                  ▼                  ▼
  Authenticated    Unauthenticated     Admin route
     │                  │                  │
     ▼                  ▼                  ▼
 ┌────────┐       ┌──────────┐      ┌───────────┐
 │ AppShell│      │ SignInPage│     │ AdminGuard │
 │ (bottomNav)│    │ SignUpPage│     │ (router   │
 └────┬───┘      │ ForgotPwd │     │  redirect)│
      │          └──────────┘      └─────┬─────┘
      │                                  │
      ▼                                  ▼
 ┌──────────────────┐           ┌────────────────┐
 │ Home / Catalog / │           │ AdminDashboard │
 │ Cart / Wishlist  │           │ AdminOrders    │
 │ Product Details  │           │ AdminInventory │
 │ Checkout         │           │ AdminCatalog   │
 │ Payment          │           └────────────────┘
 │ Orders           │
 └──────────────────┘
```

**Key transitions:**
- `main.dart` → `AlBatalApp` → `app_router.dart` (GoRouter with redirect)
- Auth redirect: unauthenticated users on auth-required routes → `/sign-in?redirect=$path`
- Admin redirect: non-admin → `/home`; unauthenticated → `/sign-in?redirect=$path`
- Checkout → Payment → Order Success (server-authoritative)
- Payment success → `CartCubit.clear()` → `/order-success`

---

## 3. Findings by Category

### 3.1 English/Arabic Parity

#### 3.1.1 Voice search button has no Arabic-specific behavior
- **Severity:** Low
- **Screen/Route:** Home → `HomeSearchBar`
- **File:** `lib/features/storefront/presentation/widgets/home_search_bar.dart:39-43`
- **Steps:** Open Home in Arabic, tap microphone icon
- **Impact:** The button is a no-op (`onPressed: () {}`) in both locales. No speech-to-text is implemented.
- **Expected:** Either implement speech recognition or remove the button.
- **Acceptance test:** Tap microphone in both EN and AR; assert either speech dialog appears or button is absent.
- **Type:** Code-inspected

#### 3.1.2 Money.format uses optional locale — may not localize for all locales
- **Severity:** Low
- **Screen/Route:** All price displays
- **File:** `lib/core/entities/money.dart:41-48`
- **Steps:** Switch to Arabic, view any price
- **Impact:** `Money.format()` uses `NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 0)`. If the locale is null, it falls back to `toStringAsFixed(0)` which doesn't group digits. The `currencyCode` from l10n is used as the symbol.
- **Expected:** All prices should show localized digit grouping and currency symbol in Arabic.
- **Acceptance test:** In Arabic, assert prices show Arabic-Indic digits or at least grouped Western digits with "ج.م." symbol.
- **Type:** Code-inspected

#### 3.1.3 Support page WhatsApp/email values are hardcoded, not localized
- **Severity:** Low
- **Screen/Route:** `/support`
- **File:** `lib/features/support/data/local_support_repository.dart:14-25`
- **Steps:** Open Support in Arabic
- **Impact:** The WhatsApp URL and email address are hardcoded English strings. The labels ("WhatsApp", "Email") are localized, but the values are not.
- **Expected:** Values should be locale-appropriate (e.g., Arabic phone number for WhatsApp).
- **Acceptance test:** In Arabic, assert WhatsApp value is an Arabic phone number.
- **Type:** Code-inspected

---

### 3.2 RTL Layout

#### 3.2.1 CatalogPage filter badge position in RTL
- **Severity:** Low
- **Screen/Route:** `/catalog`
- **File:** `lib/features/storefront/presentation/pages/catalog_page.dart:53-63`
- **Steps:** Switch to Arabic, open Catalog with active filters
- **Impact:** The `IconButton` with the `Badge` is in the `AppBar` actions, which GoRouter/Flutter automatically mirrors in RTL. However, the badge label text direction may not be correct for RTL.
- **Expected:** Badge should appear on the left side in RTL, with correct text direction.
- **Acceptance test:** In Arabic, assert filter icon is on the left side of the AppBar.
- **Type:** Code-inspected

#### 3.2.2 FlashSaleSection countdown text alignment in RTL
- **Severity:** Low
- **Screen/Route:** Home → `FlashSaleSection`
- **File:** `lib/features/storefront/presentation/widgets/flash_sale_section.dart:66-77`
- **Steps:** Switch to Arabic, view Home
- **Impact:** The countdown text is in a `Row` with `Spacer()` before it. In RTL, the `Spacer` pushes it to the left, but the text itself (e.g., "01:23:45") is LTR by default. This may look misaligned.
- **Expected:** Countdown text should maintain LTR digit direction within an RTL layout.
- **Acceptance test:** In Arabic, assert countdown digits are LTR within the RTL row.
- **Type:** Code-inspected

#### 3.2.3 Size guide table column widths in RTL
- **Severity:** Low
- **Screen/Route:** Product Details → Size Guide
- **File:** `lib/features/storefront/presentation/widgets/size_guide_sheet.dart:38-42`
- **Steps:** Switch to Arabic, open size guide
- **Impact:** The `Table` uses `FlexColumnWidth` for column widths. In RTL, the column order is reversed, but the width ratios stay the same. The header labels may not align correctly.
- **Expected:** Table columns should mirror correctly in RTL.
- **Acceptance test:** In Arabic, assert table columns are mirrored and headers align with data.
- **Type:** Code-inspected

---

### 3.3 Typography

#### 3.3.1 HomeSearchBar hint text may overflow on small screens
- **Severity:** Low
- **Screen/Route:** Home → `HomeSearchBar`
- **File:** `lib/features/storefront/presentation/widgets/home_search_bar.dart:35-36`
- **Steps:** Use a small-screen device, view Home
- **Impact:** The hint text "Search fabrics..." is in a `TextField` with no `maxLines` or overflow handling. On very small screens, the text may be truncated.
- **Expected:** Text should be truncated with ellipsis or wrap appropriately.
- **Acceptance test:** On a small-screen device, assert hint text is fully visible or truncated with ellipsis.
- **Type:** Device-required

#### 3.3.2 Admin order total may overflow on long numbers
- **Severity:** Low
- **Screen/Route:** Admin → Orders
- **File:** `lib/features/admin/presentation/pages/admin_orders_page.dart:109-111`
- **Steps:** View Admin Orders with a large order total
- **Impact:** The total `Text` widget has no `overflow` or `maxLines` set. A very large total (e.g., "1,000,000 EGP") may overflow on small screens.
- **Expected:** Text should be constrained or use `Flexible`.
- **Acceptance test:** On a small-screen device, assert total text doesn't overflow.
- **Type:** Device-required

---

### 3.4 Overflow

#### 3.4.1 AdminOrderDetailPage order items may overflow vertically
- **Severity:** Medium
- **Screen/Route:** Admin → Order Detail
- **File:** `lib/features/admin/presentation/pages/admin_order_detail_page.dart:126-135`
- **Steps:** View an order with many items
- **Impact:** The order items are in a `Column` inside a `Card` inside a `ListView`. Each `ListTile` has no height constraint. With many items, the card may overflow the screen.
- **Expected:** Items should be scrollable within the card or the card should have a max height.
- **Acceptance test:** On a device, view an order with 20+ items; assert no vertical overflow.
- **Type:** Device-required

#### 3.4.2 CartItemTile product name may overflow
- **Severity:** Low
- **Screen/Route:** Cart
- **File:** `lib/features/storefront/presentation/widgets/cart_item_tile.dart:74-76`
- **Steps:** Add a product with a long name to the cart
- **Impact:** The product name `Text` has `maxLines: 1` and `overflow: TextOverflow.ellipsis` is not set. On small screens, the name may overflow.
- **Expected:** Name should be truncated with ellipsis.
- **Acceptance test:** On a small-screen device, add a product with a long name; assert name is truncated.
- **Type:** Device-required

---

### 3.5 Accessibility: Semantics, Focus, Touch Targets

#### 3.5.1 HomeSearchBar voice search button has no semantic label
- **Severity:** Low
- **Screen/Route:** Home → `HomeSearchBar`
- **File:** `lib/features/storefront/presentation/widgets/home_search_bar.dart:39-43`
- **Steps:** Use a screen reader, navigate to the voice search button
- **Impact:** The `IconButton` has `tooltip: l.voiceSearch`, which provides a semantic label. However, since the button is a no-op, the screen reader announces "Voice search, button" but tapping it does nothing.
- **Expected:** Either implement the feature or remove the button.
- **Acceptance test:** With a screen reader, navigate to the voice button; assert it either works or is absent.
- **Type:** Code-inspected

#### 3.5.2 ProductTile Semantics label uses currencyCode
- **Severity:** Low
- **Screen/Route:** Catalog, Wishlist, Related Products
- **File:** `lib/features/storefront/presentation/widgets/product_tile.dart:16-18`
- **Steps:** Use a screen reader, navigate to a product tile
- **Impact:** The Semantics label is `'${product.name}, ${product.price.format(...symbol: context.l10n.currencyCode)}'`. If `currencyCode` is not properly localized, the screen reader announces the wrong currency.
- **Expected:** Use a localized currency label.
- **Acceptance test:** In Arabic, with a screen reader, assert the currency symbol is announced in Arabic.
- **Type:** Code-inspected

#### 3.5.3 Touch target: IconButton in CartItemTile may be too small
- **Severity:** Low
- **Screen/Route:** Cart
- **File:** `lib/features/storefront/presentation/widgets/cart_item_tile.dart:87-97`
- **Steps:** Tap the "Remove" text button on a small-screen device
- **Impact:** The `TextButton` has `minimumSize: Size.zero`, which removes the default 48x48 minimum. The actual touch target is just the text size, which may be below the 44px minimum.
- **Expected:** Touch targets should be at least 44x44px.
- **Acceptance test:** On a small-screen device, tap the Remove button; assert it's easily tappable.
- **Type:** Device-required

#### 3.5.4 BottomActionButton doesn't expose semantic state for loading
- **Severity:** Low
- **Screen/Route:** Checkout, Product Details
- **File:** `lib/features/storefront/presentation/widgets/bottom_action_button.dart:20-48`
- **Steps:** Use a screen reader, trigger loading state
- **Impact:** When `isLoading` is true, the button shows a `CircularProgressIndicator` but the `Semantics` label is still the button label. The screen reader doesn't announce "loading".
- **Expected:** Announce "loading" state.
- **Acceptance test:** With a screen reader, trigger loading; assert "loading" is announced.
- **Type:** Code-inspected

---

### 3.6 Loading / Empty / Error / Retry States

#### 3.6.1 ProductDetailsCubit has no error state — stuck on spinner
- **Severity:** Critical
- **Screen/Route:** `/product/:id`
- **File:** `lib/features/storefront/presentation/cubit/product_details_cubit.dart:69`
- **Steps:** Navigate to a product with network failure
- **Impact:** `failure: (_) {}` — the cubit emits nothing on fetch failure. The UI shows `CircularProgressIndicator` forever with no error message or retry button.
- **Expected:** Show an error state with a retry button.
- **Acceptance test:** Navigate to a product with network off; assert error message and retry button appear.
- **Type:** Code-inspected

#### 3.6.2 AdminDashboardPage never loads data — always shows zeros
- **Severity:** Critical
- **Screen/Route:** `/admin`
- **File:** `lib/features/admin/presentation/pages/admin_dashboard_page.dart:9-22`
- **Steps:** Navigate to `/admin`
- **Impact:** `AdminDashboardPage` is a `StatelessWidget` with no `initState`. It never calls `loadOrders()` or `loadLowStockProducts()`. The dashboard always shows 0 orders, 0 pending, 0 low stock.
- **Expected:** Load data on page entry.
- **Acceptance test:** Navigate to `/admin`; assert stat cards show non-zero values.
- **Type:** Code-inspected

#### 3.6.3 CatalogCubit.load failure has no errorMessage
- **Severity:** Medium
- **Screen/Route:** Home, `/catalog`
- **File:** `lib/features/storefront/presentation/cubit/catalog_cubit.dart:197`
- **Steps:** Trigger catalog load failure
- **Impact:** `failure: (_) => emit(state.copyWith(status: CatalogStatus.error))` — no `errorMessage` is set. The `FeedbackView` shows a generic "Error" title.
- **Expected:** Show the specific error message.
- **Acceptance test:** Trigger catalog load failure; assert error message is displayed.
- **Type:** Code-inspected

#### 3.6.4 WishlistPage has no loading state
- **Severity:** Medium
- **Screen/Route:** `/wishlist`
- **File:** `lib/features/storefront/presentation/pages/wishlist_page.dart:20-44`
- **Steps:** Open Wishlist while catalog is loading
- **Impact:** When `ws.products.isEmpty && ws.ids.isNotEmpty`, the page uses `addPostFrameCallback` to resolve products. During this resolution, there's no loading indicator — the empty state is shown instead.
- **Expected:** Show a loading indicator while resolving products.
- **Acceptance test:** Open Wishlist with saved items but catalog not yet loaded; assert loading indicator appears.
- **Type:** Code-inspected

#### 3.6.5 AdminOrdersPage has no retry on error
- **Severity:** Medium
- **Screen/Route:** `/admin/orders`
- **File:** `lib/features/admin/presentation/pages/admin_orders_page.dart:47-72`
- **Steps:** Trigger orders load failure
- **Impact:** When `state.status == AdminStatus.error`, the page shows nothing (no error message, no retry). The `BlocBuilder` only handles `loading` and `empty` states.
- **Expected:** Show an error message with a retry button.
- **Acceptance test:** Trigger orders load failure; assert error message and retry button appear.
- **Type:** Code-inspected

#### 3.6.6 AdminInventoryPage has no retry on error
- **Severity:** Medium
- **Screen/Route:** `/admin/inventory`
- **File:** `lib/features/admin/presentation/pages/admin_inventory_page.dart:27-53`
- **Steps:** Trigger low stock load failure
- **Impact:** Same as 3.6.5 — no error state handling.
- **Expected:** Show error message with retry.
- **Acceptance test:** Trigger low stock load failure; assert error message and retry button appear.
- **Type:** Code-inspected

---

### 3.7 Auth Redirects

#### 3.7.1 ProfilePage doesn't handle null profile when authenticated
- **Severity:** Medium
- **Screen/Route:** `/profile`
- **File:** `lib/features/auth/presentation/pages/profile_page.dart:64-87`
- **Steps:** Authenticate (session exists) but profile row doesn't exist in DB
- **Impact:** `_AuthenticatedProfile` accesses `profile?.fullName` with null-aware operators, but the `CircleAvatar` child uses `profile!.fullName.characters.first` — the force-unwrap `!` will throw if `profile` is null.
- **Expected:** Handle null profile gracefully.
- **Acceptance test:** Authenticate without a profile row; assert no crash, show "Unknown" or similar.
- **Type:** Code-inspected

#### 3.7.2 AuthCubit.updateProfile silently swallows failure
- **Severity:** Medium
- **Screen/Route:** `/profile` (profile edit)
- **File:** `lib/features/auth/presentation/cubit/auth_cubit.dart:151-169`
- **Steps:** Edit profile, trigger save failure
- **Impact:** `updateProfile` catches the failure and logs a warning but doesn't emit an error state. The UI doesn't show any feedback — the user thinks their edit was saved.
- **Expected:** Show a snackbar or error state on failure.
- **Acceptance test:** Edit profile, trigger save failure; assert error feedback is shown.
- **Type:** Code-inspected

#### 3.7.3 SignInPage/SignUpPage use FilledButton instead of AppButton
- **Severity:** Low
- **Screen/Route:** `/sign-in`, `/sign-up`
- **File:** `lib/features/auth/presentation/pages/sign_in_page.dart:93`, `lib/features/auth/presentation/pages/sign_up_page.dart:108`
- **Steps:** View sign-in or sign-up page
- **Impact:** These pages use `FilledButton` directly instead of the `AppButton` component. This bypasses the design system's button styling (minimum height, shape, text style).
- **Expected:** Use `AppButton` for consistency.
- **Acceptance test:** Inspect button styling; assert it matches AppButton spec (50px height, 8px radius).
- **Type:** Code-inspected

---

### 3.8 Cart and Checkout Flow

#### 3.8.1 AddressForm ignores the country field
- **Severity:** Critical
- **Screen/Route:** Checkout → Add Address
- **File:** `lib/features/storefront/presentation/widgets/address_form.dart:51-58`
- **Steps:** Checkout → add new address → enter country → save
- **Impact:** `_submit` creates `Address(country: '', ...)` — the country text is completely ignored. The address is saved with an empty country.
- **Expected:** Use `_countryCtrl.text.trim()` as the country.
- **Acceptance test:** Fill address form with country "Egypt"; submit; assert address has country "Egypt".
- **Type:** Code-inspected

#### 3.8.2 CartCubit.add doesn't check variant stock
- **Severity:** High
- **Screen/Route:** Product Details → Add to Cart
- **File:** `lib/features/storefront/presentation/cubit/cart_cubit.dart:81-93`
- **Steps:** Select a variant with 2 in stock, set quantity to 5, add to cart
- **Impact:** `add()` doesn't check if the selected variant has enough stock. The cart allows adding more than available.
- **Expected:** Clamp quantity to variant stock.
- **Acceptance test:** Add 5 of a 2-stock variant; assert quantity is clamped to 2.
- **Type:** Code-inspected

#### 3.8.3 CartItemTile Dismissible returns false from confirmDismiss
- **Severity:** Medium
- **Screen/Route:** Cart
- **File:** `lib/features/storefront/presentation/widgets/cart_item_tile.dart:56`
- **Steps:** Swipe to dismiss a cart item
- **Impact:** `confirmDismiss` returns `false` — the Dismissible widget doesn't visually animate away. The item is removed programmatically, but the visual feedback is missing.
- **Expected:** Return `true` to let the Dismissible animate.
- **Acceptance test:** Swipe to dismiss; assert item animates away and undo snackbar appears.
- **Type:** Code-inspected

#### 3.8.4 CheckoutPage doesn't preserve scroll position on filter change
- **Severity:** Low
- **Screen/Route:** `/checkout`
- **File:** `lib/features/storefront/presentation/pages/checkout_page.dart:67-131`
- **Steps:** Scroll down on checkout, select an address
- **Impact:** The `ListView` doesn't have a `ScrollController`, so scroll position is not preserved across rebuilds.
- **Expected:** Preserve scroll position.
- **Acceptance test:** Scroll down, trigger a rebuild; assert scroll position is maintained.
- **Type:** Code-inspected

#### 3.8.5 CheckoutPage doesn't handle empty cart
- **Severity:** Low
- **Screen/Route:** `/checkout`
- **File:** `lib/features/storefront/presentation/pages/checkout_page.dart:27-153`
- **Steps:** Navigate to `/checkout` with an empty cart
- **Impact:** The page shows the checkout form with no cart items. The `CartSummary` shows zero totals. The user can proceed to payment with an empty cart.
- **Expected:** Redirect to cart or show an empty state.
- **Acceptance test:** Navigate to `/checkout` with empty cart; assert redirect or empty state.
- **Type:** Code-inspected

---

### 3.9 Payment Success/Failure/Cold-Start Recovery

#### 3.9.1 PaymentMethodPage shows success before server confirms status update
- **Severity:** High
- **Screen/Route:** `/payment-method`
- **File:** `lib/features/admin/presentation/pages/admin_order_detail_page.dart:243-254`
- **Steps:** Admin → Order Detail → tap "Confirm Order"
- **Impact:** `_updateStatus` calls `updateOrderStatus` (async) and immediately shows a success snackbar without awaiting. If the server call fails, the user sees success.
- **Expected:** Await the server call and show success/failure accordingly.
- **Acceptance test:** Trigger status update failure; assert no success snackbar is shown.
- **Type:** Code-inspected

#### 3.9.2 PaymentCubit watch timeout is 15 minutes — may be too long for UX
- **Severity:** Low
- **Screen/Route:** `/payment-method`
- **File:** `lib/features/payments/presentation/cubit/payment_cubit.dart:90`
- **Steps:** Initiate Paymob payment, close WebView without completing
- **Impact:** The watch timeout is 15 minutes. If the user closes the WebView without completing payment, they wait up to 15 minutes before seeing a timeout message.
- **Expected:** Consider a shorter timeout or detect WebView close.
- **Acceptance test:** Close WebView without completing; assert timeout message appears within a reasonable time.
- **Type:** Device-required

#### 3.9.3 Cold start: OrdersCubit.restore() doesn't reconcile with server
- **Severity:** Medium
- **Screen/Route:** App launch → Orders
- **File:** `lib/features/storefront/presentation/cubit/orders_cubit.dart:74-86`
- **Steps:** Place an order on device A, cold-start app on device B
- **Impact:** `restore()` reads from local SharedPreferences only. In production (SupabaseOrdersRepository), `readOrders()` fetches from the server. But the local fallback (debug mode) only shows local orders. If the user placed an order on another device, it won't appear until the app is restarted or the orders page is refreshed.
- **Expected:** Reconcile local orders with server on cold start.
- **Acceptance test:** Place order on device A, cold-start on device B; assert order appears.
- **Type:** Staging-required

#### 3.9.4 PaymentMethodPage doesn't handle Paymob WebView close
- **Severity:** Medium
- **Screen/Route:** `/paymob-checkout`
- **File:** `lib/features/payments/presentation/pages/paymob_checkout_page.dart:129-154`
- **Steps:** Initiate Paymob payment, close WebView via back button
- **Impact:** When the user closes the WebView (via the close button or back gesture), the `PaymentMethodPage`'s `BlocConsumer` doesn't react. The payment state remains `awaitingVerification`. The user is stuck on the payment method page with no feedback.
- **Expected:** Detect WebView close and show a "payment not completed" message.
- **Acceptance test:** Close Paymob WebView without completing; assert error message appears.
- **Type:** Device-required

---

### 3.10 Customer Order Visibility

#### 3.10.1 OrdersPage doesn't handle loading state for individual tabs
- **Severity:** Low
- **Screen/Route:** `/profile/orders`
- **File:** `lib/features/storefront/presentation/pages/orders_page.dart:16-60`
- **Steps:** Navigate to Orders while orders are loading
- **Impact:** The `BlocBuilder` only shows a loading indicator if `state.status == OrdersStatus.loading`. Once loaded, switching between tabs (Active/Completed/Cancelled) doesn't show a loading state.
- **Expected:** Show loading state when switching tabs if data is being refreshed.
- **Acceptance test:** Navigate to Orders, switch tabs; assert no loading indicator (acceptable for local data).
- **Type:** Code-inspected

#### 3.10.2 OrderCard "Advance Order" button is visible for all active orders
- **Severity:** Low
- **Screen/Route:** `/profile/orders` (Active tab)
- **File:** `lib/features/storefront/presentation/widgets/order_card.dart:57-67`
- **Steps:** View an active order
- **Impact:** The "Advance Order" button is visible for all active orders (not just `placed` status). Tapping it calls `OrdersCubit.advance()` which is a client-side simulation. In production, this does nothing server-side.
- **Expected:** Either remove the button for customers or wire it to a server API.
- **Acceptance test:** View an active order; assert "Advance Order" button behavior is correct.
- **Type:** Code-inspected

#### 3.10.3 OrderCard status label maps refunded to "cancelled"
- **Severity:** Medium
- **Screen/Route:** `/profile/orders`
- **File:** `lib/features/storefront/presentation/widgets/order_card.dart:82`
- **Steps:** View a refunded order
- **Impact:** `_statusLabel` maps `OrderStatus.refunded` to `l.cancelled`. A refunded order is displayed as "Cancelled".
- **Expected:** Show "Refunded" as a distinct status.
- **Acceptance test:** View a refunded order; assert status shows "Refunded".
- **Type:** Code-inspected

---

### 3.11 Admin Navigation and Authorization States

#### 3.11.1 AdminCubit.checkAdmin is never called
- **Severity:** High
- **Screen/Route:** `/admin`, `/admin/orders`, `/admin/inventory`, `/admin/catalog`
- **File:** `lib/features/admin/presentation/cubit/admin_cubit.dart:70-78`
- **Steps:** Navigate to any admin page
- **Impact:** `checkAdmin()` exists but is never invoked. The admin route guard in `app_router.dart:59-63` checks `auth.profile?.isAdmin != true` instead. This means the `AdminCubit.checkAdmin()` method is dead code, and the admin check relies on the profile being loaded.
- **Expected:** Either call `checkAdmin()` from admin pages or remove the dead method.
- **Acceptance test:** Navigate to `/admin` as a non-admin; assert redirect to `/home`.
- **Type:** Code-inspected

#### 3.11.2 AdminDashboardPage never loads data
- **Severity:** Critical
- **Screen/Route:** `/admin`
- **File:** `lib/features/admin/presentation/pages/admin_dashboard_page.dart:9-22`
- **Steps:** Navigate to `/admin`
- **Impact:** `AdminDashboardPage` is a `StatelessWidget` with no `initState`. It never calls `loadOrders()` or `loadLowStockProducts()`. The dashboard always shows 0 orders, 0 pending, 0 low stock.
- **Expected:** Load data on page entry.
- **Acceptance test:** Navigate to `/admin`; assert stat cards show non-zero values.
- **Type:** Code-inspected

#### 3.11.3 Admin order ID substring can throw
- **Severity:** Medium
- **Screen/Route:** `/admin/orders`, `/admin/orders/:id`
- **File:** `lib/features/admin/presentation/pages/admin_orders_page.dart:106`, `lib/features/admin/presentation/pages/admin_order_detail_page.dart:30`
- **Steps:** View an order with a short ID (< 8 chars)
- **Impact:** `substring(0, 8)` throws `RangeError` if the ID is shorter than 8 characters.
- **Expected:** Safely truncate with a length check.
- **Acceptance test:** View an order with a 5-character ID; assert no crash.
- **Type:** Code-inspected

#### 3.11.4 AdminOrderDetailPage tracking dialog has no validation
- **Severity:** Medium
- **Screen/Route:** `/admin/orders/:id` (processing status)
- **File:** `lib/features/admin/presentation/pages/admin_order_detail_page.dart:256-300`
- **Steps:** Mark as shipped → enter empty tracking number
- **Impact:** The tracking number field has no validator. An empty tracking number is accepted. The dialog also closes before the server call completes.
- **Expected:** Validate the tracking number and await the update before closing.
- **Acceptance test:** Mark as shipped with empty tracking; assert validation error.
- **Type:** Code-inspected

---

### 3.12 Support Actions

#### 3.12.1 Support page WhatsApp/email uses clipboard copy, not deep link
- **Severity:** Low
- **Screen/Route:** `/support`
- **File:** `lib/features/support/presentation/pages/support_pages.dart:139-158`
- **Steps:** Tap WhatsApp or Email on Support page
- **Impact:** Tapping WhatsApp or Email copies the value to the clipboard (with a snackbar confirmation) instead of opening the WhatsApp app or email client. This is intentional (no URL launcher dependency) but may confuse users who expect the app to open.
- **Expected:** Either open the app or clearly label the action as "Copy".
- **Acceptance test:** Tap WhatsApp; assert clipboard contains the URL and snackbar confirms.
- **Type:** Code-inspected

#### 3.12.2 Support page has no offline state
- **Severity:** Low
- **Screen/Route:** `/support`
- **File:** `lib/features/support/presentation/pages/support_pages.dart:96-117`
- **Steps:** Open Support with no network
- **Impact:** The Support page reads from a local repository, so it works offline. However, the FAQ content is local (from l10n), so it also works offline. No issue here.
- **Expected:** N/A — this is a positive finding.
- **Acceptance test:** Open Support with no network; assert all content is visible.
- **Type:** Code-inspected

---

### 3.13 Catalog/Product Images

#### 3.13.1 ZoomGallery Image.asset has no error builder
- **Severity:** Low
- **Screen/Route:** Product Details → Image Zoom
- **File:** `lib/features/storefront/presentation/widgets/zoom_gallery.dart:56`
- **Steps:** Tap a product image with an invalid asset path
- **Impact:** `Image.asset(widget.images[i], fit: BoxFit.contain)` has no `errorBuilder`. If the asset path is invalid, Flutter shows its default error UI.
- **Expected:** Show a placeholder or the `FabricWeavePainter` fallback.
- **Acceptance test:** Tap an image with an invalid path; assert graceful fallback.
- **Type:** Code-inspected

#### 3.13.2 ProductImagePlaceholder doesn't handle remote image load failures gracefully
- **Severity:** Low
- **Screen/Route:** Catalog, Product Details
- **File:** `lib/features/storefront/presentation/widgets/product_image_placeholder.dart:79-82`
- **Steps:** View a product with a broken remote image URL
- **Impact:** `CachedNetworkImage` has an `errorWidget` that shows `Icons.broken_image`. This is acceptable but could be improved with the `FabricWeavePainter` fallback.
- **Expected:** Show the `FabricWeavePainter` fallback for consistency.
- **Acceptance test:** View a product with a broken image URL; assert `Icons.broken_image` is shown.
- **Type:** Code-inspected

#### 3.13.3 CategoryGrid doesn't handle products with no images
- **Severity:** Low
- **Screen/Route:** `/categories`
- **File:** `lib/features/storefront/presentation/widgets/category_grid.dart:65-67`
- **Steps:** View a category where the first product has no image
- **Impact:** `if (p.imageAsset != null) Image.asset(p.imageAsset!)` — if the product has no image, the category tile shows only the color background. This is acceptable.
- **Expected:** N/A — this is handled correctly.
- **Acceptance test:** View a category with no images; assert color background is shown.
- **Type:** Code-inspected

---

### 3.14 Network/Offline Behavior

#### 3.14.1 SupabaseCatalogRepository has persistent cache for offline fallback
- **Severity:** N/A (positive)
- **Screen/Route:** All catalog screens
- **File:** `lib/features/storefront/data/supabase_catalog_repository.dart:109-121`
- **Finding:** On network failure, the repository tries the persistent SharedPreferences cache first, then the in-memory cache. This provides offline fallback.
- **Acceptance test:** Turn off network, restart app; assert catalog is still visible from cache.
- **Type:** Code-inspected

#### 3.14.2 CartCubit persistence debounce may lose data on app kill
- **Severity:** Medium
- **Screen/Route:** Cart
- **File:** `lib/features/storefront/presentation/cubit/cart_cubit.dart:111-119`
- **Steps:** Add item to cart → immediately kill the app
- **Impact:** `_emitAndPersist` uses a 500ms debounce timer. If the app is killed before the timer fires, the last mutation is lost. The `close()` method flushes pending writes, but if the app is killed (not closed gracefully), data is lost.
- **Expected:** Persist immediately or use a more robust strategy.
- **Acceptance test:** Add item to cart, kill app, restart; assert item is persisted.
- **Type:** Device-required

#### 3.14.3 OrdersCubit.advance is client-side only — lost on sync
- **Severity:** High
- **Screen/Route:** `/profile/orders`
- **File:** `lib/features/storefront/presentation/cubit/orders_cubit.dart:115-132`
- **Steps:** Advance an order → restart app (production mode)
- **Impact:** `advance()` simulates status progression client-side. In production (SupabaseOrdersRepository), `writeOrders` is a no-op, so the status change is lost on next sync.
- **Expected:** Call a server API to advance order status.
- **Acceptance test:** Advance an order, restart app; assert status is persisted.
- **Type:** Staging-required

#### 3.14.4 No network connectivity indicator
- **Severity:** Low
- **Screen/Route:** All screens
- **File:** N/A (missing feature)
- **Steps:** Turn off network
- **Impact:** There is no global network connectivity indicator. Users don't know if they're offline. The app falls back to cached data silently.
- **Expected:** Show a banner or indicator when offline.
- **Acceptance test:** Turn off network; assert offline indicator appears.
- **Type:** Device-required

---

## 4. Prioritized List of Staging/Device Blockers

| Priority | Issue | Type | Impact |
|----------|-------|------|--------|
| **P0** | AdminDashboardPage never loads data (3.6.2, 3.11.2) | Code-inspected | Admin dashboard is completely non-functional |
| **P0** | AddressForm ignores country field (3.8.1) | Code-inspected | Shipping addresses are incomplete |
| **P0** | ProductDetailsCubit stuck on spinner (3.6.1) | Code-inspected | Product pages hang on network error |
| **P1** | OrdersCubit.advance is client-side only (3.14.3) | Staging-required | Order status changes are lost in production |
| **P1** | CartCubit.add doesn't check variant stock (3.8.2) | Code-inspected | Users can over-order out-of-stock variants |
| **P1** | PaymentMethodPage shows success before server confirms (3.9.1) | Code-inspected | Admin sees false success on status update |
| **P1** | ProfilePage crashes on null profile (3.7.1) | Code-inspected | Authenticated users without profiles crash |
| **P2** | CartCubit persistence debounce may lose data (3.14.2) | Device-required | Cart items lost on app kill |
| **P2** | PaymentMethodPage doesn't handle WebView close (3.9.4) | Device-required | Users stuck after closing Paymob WebView |
| **P2** | Admin order ID substring can throw (3.11.3) | Code-inspected | Admin pages crash on short IDs |
| **P3** | AdminOrderDetailPage tracking dialog no validation (3.11.4) | Code-inspected | Empty tracking numbers accepted |
| **P3** | OrderCard maps refunded to cancelled (3.10.3) | Code-inspected | Refunded orders mislabeled |
| **P3** | WishlistPage no loading state (3.6.4) | Code-inspected | No feedback while resolving products |
| **P3** | AdminOrdersPage/InventoryPage no error state (3.6.5, 3.6.6) | Code-inspected | No retry on admin load failure |
| **P3** | ZoomGallery no error builder (3.13.1) | Code-inspected | Broken image assets show error UI |
| **P3** | CatalogPage shows sort bar when empty (3.8.6 from prior report) | Code-inspected | Misleading UI when no results |
| **P3** | No network connectivity indicator (3.14.4) | Device-required | Users unaware of offline state |

---

## 5. Summary

| Category | Issues | Critical | High | Medium | Low |
|----------|--------|----------|------|--------|-----|
| EN/AR Parity | 3 | 0 | 0 | 0 | 3 |
| RTL Layout | 3 | 0 | 0 | 0 | 3 |
| Typography | 2 | 0 | 0 | 0 | 2 |
| Overflow | 2 | 0 | 1 | 0 | 1 |
| Accessibility | 4 | 0 | 0 | 0 | 4 |
| Loading/Error States | 6 | 2 | 0 | 4 | 0 |
| Auth Redirects | 3 | 0 | 0 | 3 | 0 |
| Cart/Checkout | 5 | 1 | 1 | 1 | 2 |
| Payment Recovery | 4 | 0 | 1 | 2 | 1 |
| Order Visibility | 3 | 0 | 0 | 1 | 2 |
| Admin Nav/Auth | 4 | 1 | 1 | 2 | 0 |
| Support Actions | 2 | 0 | 0 | 0 | 2 |
| Catalog Images | 3 | 0 | 0 | 0 | 3 |
| Network/Offline | 4 | 0 | 1 | 1 | 2 |
| **Total** | **41** | **4** | **4** | **14** | **19** |

**Code-inspected:** 28 findings
**Device-required:** 8 findings
**Staging-required:** 5 findings

**Positive findings (no issues):** 3.14.1 (offline catalog cache), 3.12.2 (offline support), 9.1-9.4 from prior report (Paymob security).

---

## 6. Verdict

### BLOCKED

This audit is **BLOCKED** from a PASS because:

1. **4 critical issues require code changes** (AdminDashboardPage never loads data, AddressForm ignores country, ProductDetailsCubit stuck on spinner, PaymentMethodPage shows success before server confirms) — these cannot be verified without L2 implementation authority.

2. **5 staging-required findings** (OrdersCubit.advance client-side only, cold-start order reconciliation, Paymob WebView close handling, Paymob watch timeout UX, AdminCubit.checkAdmin never called) require a deployed Supabase staging environment, Deno Edge Functions, and Paymob merchant dashboard access — none of which can be inferred from source code alone per constraint #6.

3. **8 device-required findings** (typography overflow, touch targets, WebView close handling, network connectivity indicator, cart persistence on app kill) require physical device/emulator testing that was not performed.

4. **Payment properties cannot be verified from code alone** — canonical HMAC validation, fail-closed callbacks, trusted provider/order mapping, amount/currency validation, duplicate-callback idempotency, safe late/conflicting callback handling, exactly-once stock restoration, server-authorized fulfillment, and no client-created canonical orders all require staging + Paymob dashboard verification per constraint #9.

### Evidence Summary

| Property | Code Evidence | Staging Evidence | Verdict |
|----------|--------------|-----------------|---------|
| HMAC validation | `paymob-callback/hmac_test.ts` (contract test) | Not verified | Cannot confirm |
| Fail-closed callbacks | `cancel-expired-orders/index.ts` | Not verified | Cannot confirm |
| Trusted provider mapping | `checkout_service.dart` (server RPC) | Not verified | Cannot confirm |
| Amount/currency validation | `checkout_service.dart` (server-side) | Not verified | Cannot confirm |
| Duplicate idempotency | `OrdersCubit.reconcile()` | Not verified | Cannot confirm |
| Stock restoration | `cancel-expired-orders` function | Not verified | Cannot confirm |
| Server-authorized fulfillment | `checkout_service.dart` (SECURITY DEFINER) | Not verified | Cannot confirm |
| No client canonical orders | `CheckoutCubit` creates pending order via RPC | Not verified | Cannot confirm |

### Recommendation

Proceed to L2 with human approval for the 4 critical fixes. Deploy to staging with Paymob test dashboard for payment flow verification. Run device tests for the 8 device-required findings.

---

*Report saved to `report.md`. No source files were modified, generated, committed, pushed, or deployed during this audit.*