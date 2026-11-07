# Responsive & Adaptive Readiness — Full Audit + Remediation Plan

Date: 2026-11-07
Repo: `C:\flutter_projects\albatal_store`
Baseline commit: `2f8dd3c` (`master`)
Scope: every page/widget under `lib/` (storefront, auth, settings, addresses, payments, onboarding, admin, shared shell/theme)
Verdict: **NOT 100% responsive/adaptive today.** Partial support only.

---

## 1. Executive verdict

What is already good:

- One width-aware product-grid delegate (`lib/shared/theme/grid_delegate.dart`): 2 / 3 / 4 columns at `<700` / `700–999` / `≥1000`.
- `ResponsiveShell` caps content at 1200px (`lib/shared/components/responsive_shell.dart`).
- Home and Catalog already use `ResponsiveShell`.
- Product grid, flash-sale card, stitch chips, cart tile, address form, size-guide sheet, fit-recommender sheet, variant dialog, admin order-detail dialog are scroll-safe or text-scale-aware.
- RTL is mostly handled with `EdgeInsetsDirectional` and `context.directional*Icon`.

What blocks "100%":

| Dimension | Status | Main gap |
|---|---|---|
| Phone portrait | Good | A few hard overflows at text scale 2.0 |
| Phone landscape | **Broken** | Catalog header stack, onboarding image floor, details gallery 300dp |
| Tablet / desktop | **Partial** | Only 2 screens capped; no `NavigationRail`; admin stays phone-shaped |
| Text scale 2.0 | **Broken** | ~12 non-scrollable `Column`s and fixed-height rows |
| Edge-to-edge / safe area | **Broken** | Details + Checkout bottom bars have no `SafeArea` |
| RTL | Mostly good | 3 `Alignment.centerRight` literals |
| Sheets / dialogs + keyboard | **Broken** | 4 sheets and 3 dialogs are non-scrollable |
| iOS landscape | Not supported | `Info.plist` portrait-only (product decision, outside `lib/`) |

---

## 2. Severity model

- **P0** — content unreachable / hard overflow / broken layout on a common device or keyboard state.
- **P1** — usable but visibly broken on landscape, tablet, RTL, or text scale 2.0; or CTA covered by system nav bar.
- **P2** — polish, wide-screen density, test coverage, product decisions.

---

## 3. Findings (evidence at source)

### P0 — must fix

| # | File:line | Problem | Fix |
|---|---|---|---|
| P0-1 | `lib/features/storefront/presentation/widgets/reviews/review_submit_sheet.dart:79-163` | Non-scrollable `Column` inside `viewInsets` padding. Keyboard + 5 stars + 3-line field + action row overflows on small phones; Submit can be unreachable. | Adaptive sheet: `SingleChildScrollView`, `SafeArea(top:false)`, max width 640. |
| P0-2 | `lib/features/storefront/presentation/widgets/wishlist_tile.dart:33-44` | `ProductImagePlaceholder` returns `Expanded` when `constraints == null` (`product_image_placeholder.dart:86`), and the tile also has `Spacer()` at line 44. Two flex children split free space; the image collapses as text grows. | Give the tile a bounded media slot (`AspectRatio`/`SizedBox` + `constraints`), drop the `Spacer` dependency. |
| P0-3 | `lib/features/admin/presentation/widgets/coupons/admin_coupons_view.dart:75-118` | Non-scrollable create-coupon sheet; keyboard overflows. | Adaptive sheet wrapper. |
| P0-4 | `lib/features/admin/presentation/widgets/wholesale_prices/admin_wholesale_prices_view.dart:96-160` | Non-scrollable add/edit sheet; keyboard overflows. `DropdownButtonFormField` (line 119) has no `isExpanded: true`, so long product names overflow the field. | Adaptive sheet + `isExpanded: true`. |
| P0-5 | `lib/shared/components/feedback_view.dart:74-105` | `Center > Padding > Column`; no scroll. Used by ~20 screens. At text scale 2.0 in landscape it overflows and the CTA is clipped. | `SingleChildScrollView` + `ConstrainedBox(minHeight: viewport)` + `IntrinsicHeight`-free centered column. |
| P0-6 | `lib/features/auth/presentation/widgets/profile/guest_profile.dart:15-45` | Non-scrollable centered column: icon + text + 3 buttons. Overflows at 2.0 scale / small landscape. | Scroll view + `ResponsiveShell`-style cap. |
| P0-7 | `lib/features/settings/presentation/pages/maintenance_page.dart:31-68` | Forced-update / maintenance gate is non-scrollable; can become unusable at 2.0 scale. | Scroll view. |
| P0-8 | `lib/features/storefront/presentation/pages/catalog_page.dart:100-206` | Fixed header stack (recents + search + active filters + 78dp chips + sort bar) in a `Column` above `Expanded(GridView)`. In landscape (~360dp height) headers consume the viewport and the grid collapses. | Convert to `CustomScrollView`: headers as `SliverToBoxAdapter`, grid as `SliverGrid`, with `SliverPersistentHeader` only if needed. |

### P1 — safe area, RTL, landscape, wide screen

| # | File:line | Problem | Fix |
|---|---|---|---|
| P1-1 | `lib/features/storefront/presentation/widgets/add_to_cart_button.dart:53-114` | Bottom bar has no `SafeArea`; Android 15/16 edge-to-edge nav bar covers the CTA. | `SafeArea(top:false, minimum: EdgeInsets.only(bottom: 8))`. |
| P1-2 | `lib/features/storefront/presentation/pages/checkout_page.dart:172-223` | Same missing `SafeArea` on the checkout CTA bar. | Same. |
| P1-3 | `lib/features/storefront/presentation/widgets/catalog_sort_bar.dart:19-39` | `Row` = `Text` + `Spacer` + `Chip`; at 2.0 scale both labels overflow. | `Expanded` + ellipsis on the count, flexible chip label. |
| P1-4 | `lib/shared/components/stitch/hero/hero_slide_card.dart:86-128` | `PositionedDirectional` sets only `start` + `bottom`; the content column has unbounded width, so long titles clip past the card instead of ellipsizing. Fixed 180dp carousel height also overflows at 2.0 scale. | Add `end: 20`; scale carousel height by `textScaler`. |
| P1-5 | `lib/features/auth/presentation/pages/sign_in_page.dart:129-135` | `Alignment.centerRight` is not direction-aware — "Forgot password" sits on the wrong side in Arabic. | `AlignmentDirectional.centerEnd`. |
| P1-6 | `lib/features/storefront/presentation/widgets/variant_selector.dart:110,133` | Same `Alignment.centerRight` RTL bug. | `AlignmentDirectional.centerEnd`. |
| P1-7 | `lib/features/auth/presentation/pages/sign_in_page.dart:154-186`, `sign_up_page.dart:181-190` | Footer `Row`s (`Text` + `TextButton`, and Google/Apple buttons) overflow at 2.0 scale. | `Wrap` with alignment; `Flexible` labels. |
| P1-8 | `lib/features/settings/presentation/widgets/settings/delete_account_flow.dart:52-89` | `AlertDialog` content column + auto-focused `TextField`; keyboard overflows on small screens. | `scrollable: true` (or `SingleChildScrollView`). |
| P1-9 | `lib/features/admin/presentation/pages/admin_instapay_reviews_page.dart:213-248` | Reject dialog content column with a `TextField`; no scroll. | `scrollable: true`. |
| P1-10 | `lib/features/admin/presentation/widgets/membership_tier_dialog.dart:31-72` | 3 `RadioListTile`s in a non-scrollable dialog. | `scrollable: true`. |
| P1-11 | `lib/features/payments/presentation/widgets/instapay_transfer_card.dart:64-75` | `Row` label + `Spacer` + amount; amount overflows at 2.0 scale. | `Expanded` amount with `textAlign: end` + ellipsis. |
| P1-12 | `lib/features/storefront/presentation/widgets/search_suggestions_bar.dart:74` | Fixed `SizedBox(height: 36)` around chips; label clips at 2.0 scale. | Remove fixed height / derive from `textScaler`. |
| P1-13 | `lib/features/onboarding/presentation/pages/onboarding_page.dart:85-87` | Image height floor 240dp; landscape leaves almost no content and the hero dominates. | `min(0.55*h, 0.45*w)` with a 120dp floor; side-by-side layout when `w > h`. |
| P1-14 | `lib/features/storefront/presentation/widgets/image_gallery.dart:76-94` | Fixed 300dp gallery on every viewport; consumes a landscape phone and letterboxes on tablet. | `min(300, 0.45 * viewportHeight)` + aspect-ratio cap. |
| P1-15 | `lib/features/storefront/presentation/widgets/related_card.dart:20-23` | Fixed `140x200`; at 2.0 scale the text block eats the image (Expanded). | Scale height by text scale or make the card height intrinsic with a min. |
| P1-16 | Cart, Checkout, Details, Orders, Wishlist, Categories, Profile, Settings, Addresses, Support, Auth, Admin | No 1200px content cap; content stretches edge-to-edge on tablet/desktop. | Adopt `ResponsiveShell` (or a new `ResponsiveBody`) at the top of each page. |
| P1-17 | `lib/shared/components/app_shell.dart:38-87` | Bottom `NavigationBar` at every width; no `NavigationRail`. Biggest adaptive gap. | `LayoutBuilder`: `NavigationRail` at `≥840`, bottom bar below. Keep badge selectors. |
| P1-18 | `lib/features/admin/presentation/widgets/dashboard/admin_image_grid.dart:26-33` | Fixed 2-column grid → 500px tiles on tablet/desktop. | Width-aware delegate (2/3/4/5). |
| P1-19 | `lib/features/admin/presentation/pages/admin_dashboard_page.dart:65-140` | Full-width stacked stat cards on every width. | Responsive stat grid (1 / 2 / 3 columns) + `ResponsiveShell`. |
| P1-20 | `lib/features/admin/presentation/widgets/product_edit_form.dart:108-121` | Category dropdown without `isExpanded: true`. | Add it. |
| P1-21 | `lib/features/storefront/presentation/pages/details_page.dart:235-320` | Single-column 1200px-wide body on tablet; fixed 300 gallery + 200 related strip. | `ResponsiveShell` + 2-column tablet layout (gallery left, info right) at `≥900`. |
| P1-22 | `lib/features/storefront/presentation/pages/checkout_page.dart:114-171` | Single-column body on tablet. | `ResponsiveShell`; two-column summary at `≥900` (optional, P2). |
| P1-23 | `lib/features/storefront/presentation/pages/order_success_page.dart:43-68` | Invalid-id branch is non-scrollable. | Scroll view. |
| P1-24 | `lib/features/payments/presentation/widgets/invalid_checkout_body.dart:17-37` | Non-scrollable centered column. | Scroll view. |
| P1-25 | `lib/shared/components/step_indicator.dart:17-35` | 3 fixed `Expanded` columns with 12sp labels; at 2.0 scale labels wrap heavily and push layout. | `maxLines: 1` + ellipsis, or a compact wrap layout at large scale. |

### P2 — polish / coverage / product decisions

| # | Item | Note |
|---|---|---|
| P2-1 | `ios/Runner/Info.plist` portrait-only (iPhone + iPad) | Product decision. Changing it is outside `lib/` and needs approval. |
| P2-2 | No app-level text-scale clamp | Intentional; means 2.0 must genuinely work. Add tests instead of clamping. |
| P2-3 | Text-scale tests only at 1.4× | `cart_text_scale_test.dart`, `checkout_text_scale_test.dart`, `details_text_scale_test.dart`, `home_text_scale_test.dart`, `stitch_product_grid_card_test.dart`. Add 2.0×. |
| P2-4 | No tablet-width widget tests | Add 800×1280 and 1280×800 coverage for shell + catalog + details. |
| P2-5 | `sales_revenue_chart.dart:32-33` fixed 220dp, 10sp labels | Acceptable; consider scaling labels. |
| P2-6 | `admin_customers_page.dart:151` body `Column` | Verify search + list split is `Expanded`; likely fine. |
| P2-7 | `order_card`, `order_list`, `address_tile`, `support_page` | Mostly `ListTile`/`ListView`; verify 2.0 scale after P0/P1 wave. |
| P2-8 | `splash_page.dart:146` fixed 240 logo | Splash is short-lived; verify landscape only. |

---

## 4. Remediation waves

### Wave 0 — shared primitives (new files, no behavior change)

1. `lib/shared/layout/breakpoints.dart`
   - `kCompactMax = 600`, `kMediumMax = 840`, `kExpandedMax = 1200`.
   - `contentMaxWidth(context)`, `isCompact/isMedium/isExpanded`.
2. `lib/shared/components/adaptive_sheet.dart`
   - Wraps sheet content: `SafeArea(top: false)`, `SingleChildScrollView`, `viewInsets` bottom padding, `ConstrainedBox(maxWidth: 640)`, centered on wide screens.
3. `lib/shared/components/safe_bottom_bar.dart`
   - `SafeArea(top: false)` + surface color + directional padding.
4. Extend `ResponsiveShell` with optional `padding` and `maxWidth` (defaults preserved).

### Wave 1 — P0

P0-1 … P0-8 above. One commit per item is preferred; a single scoped commit is acceptable if the gate run is green.

### Wave 2 — P1

P1-1 … P1-25. Group into:
- **2a** Safe area + RTL + text scale (P1-1…P1-15, P1-23…P1-25).
- **2b** Wide-screen adoption (P1-16, P1-19, P1-21, P1-22).
- **2c** Adaptive navigation + admin grids (P1-17, P1-18, P1-20).

### Wave 3 — tests + close-out

- Add `test/shared/components/feedback_view_text_scale_test.dart` (2.0×, 320×480).
- Add `test/features/storefront/presentation/pages/catalog_landscape_test.dart` (640×360).
- Add `test/shared/components/app_shell_adaptive_test.dart` (840×600 → rail; 400×800 → bar).
- Add `test/features/storefront/presentation/widgets/wishlist_tile_test.dart` (image not collapsed at 2.0×).
- Extend existing text-scale tests to 2.0× where the page is in scope.
- Update `STATE.md` with evidence.

---

## 5. Gates (every wave)

```powershell
flutter analyze --no-pub
flutter test --no-pub
dart format --output=none --set-exit-if-changed lib test
```

- No `pubspec.yaml`, CI, router definitions, migrations, or generated files touched.
- `lib/` only. Any platform-config need (iOS landscape) is escalated, not edited.
- Max 3 attempts per item, then stop and report.
- Verifier sub-agent after the implementation wave.

---

## 6. Out of scope (explicit)

- iOS orientation unlock (`Info.plist`) — requires product + platform approval.
- New design-system tokens or visual redesign.
- Backend/Supabase changes.
- Web/desktop-specific layouts beyond the 1200px cap + rail.
- Performance work unrelated to layout.

---

## 7. Definition of done

1. Every P0 and P1 finding closed with a source-verified change.
2. `flutter analyze --no-pub` clean.
3. Full `flutter test --no-pub` green, with the new responsive tests included.
4. `dart format` clean.
5. Manual/automated checks at:
   - 360×640 (small phone), 390×844 (modern phone)
   - 640×360 (phone landscape)
   - 800×1280 (tablet portrait), 1280×800 (tablet landscape)
   - text scale 1.0 and 2.0
   - LTR and RTL
6. `STATE.md` records the run, evidence, and any deferred items.
