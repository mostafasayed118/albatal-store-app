# Acceptance Test Checklist

## Test Environment
- **Staging Supabase project**: [URL]
- **Test devices**: Android (physical), iOS (physical/simulator)
- **Test accounts**: Customer (test@test.com), Admin (admin@test.com)

---

## 1. Authentication

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 1.1 | Sign up with valid email | Account created, verification email sent | | |
| 1.2 | Sign in with correct credentials | Session restored, redirected to home | | |
| 1.3 | Sign in with wrong password | Error message shown | | |
| 1.4 | Forgot password | Reset email sent | | |
| 1.5 | Reset password | New password works | | |
| 1.6 | Sign out | Session cleared, redirected to home | | |
| 1.7 | Relaunch app with active session | Session restored automatically | | |
| 1.8 | Arabic sign-in UI | RTL layout, Arabic strings | | |

## 2. Product Discovery

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 2.1 | Browse catalog | Products load with images | | |
| 2.2 | Search "silk" | Silk products shown | | |
| 2.3 | Filter by category "Velvet" | Only velvet products shown | | |
| 2.4 | Filter by price range | Products within range shown | | |
| 2.5 | Sort by price low→high | Correct order | | |
| 2.6 | Product details page | Name, price, stock, variants shown | | |
| 2.7 | Out-of-stock variant | Add to cart disabled | | |
| 2.8 | Related products | Same category products shown | | |

## 3. Cart & Wishlist

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 3.1 | Add to cart (guest) | Item stored locally | | |
| 3.2 | Add to cart (signed in) | Item stored locally on the device | | |
| 3.3 | Update quantity | Total recalculated | | |
| 3.4 | Remove from cart | Item removed | | |
| 3.5 | Add to wishlist (signed in) | Product saved locally on the device | | |
| 3.6 | Move to cart from wishlist | Item added, removed from wishlist | | |

## 4. Checkout

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 4.1 | Checkout without address | Validation error shown | | |
| 4.2 | Add new address | Address saved and selected | | |
| 4.3 | Select existing address | Address shown in review | | |
| 4.4 | Shipping fee (Cairo) | 50 EGY | | |
| 4.5 | Free shipping (>500 EGY) | 0 EGY shipping | | |
| 4.6 | Select payment method | Method highlighted | | |
| 4.7 | Place order (COD) | Order created, cart cleared | | |

## 5. Payments

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 5.1 | Paymob card success | Payment completed, order confirmed | | |
| 5.2 | Paymob card decline | Error shown, stock restored | | |
| 5.3 | Duplicate Paymob callback | No duplicate order created | | |

## 6. Admin

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 6.1 | Admin dashboard (admin user) | Stats and actions shown | | |
| 6.2 | Admin dashboard (non-admin) | Access denied | | |
| 6.3 | View order queue | All orders listed | | |
| 6.4 | Filter orders by status | Correct filter applied | | |
| 6.5 | Update order status | Status changed, notification sent | | |
| 6.6 | Add tracking number | Tracking saved | | |
| 6.7 | Low stock alert | Low stock products shown | | |

## 7. Localization

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 7.1 | English UI | All strings in English | | |
| 7.2 | Arabic UI | All strings in Arabic | | |
| 7.3 | Arabic RTL | Layout mirrors correctly | | |
| 7.4 | Switch language | UI updates immediately | | |

## 8. Edge Cases

| # | Test Case | Expected | Actual | Pass |
|---|-----------|----------|--------|------|
| 8.1 | Slow network | Loading states shown | | |
| 8.2 | No network | Error states with retry | | |
| 8.3 | Empty cart checkout | Validation error | | |
| 8.4 | Concurrent stock update | Stock integrity maintained | | |
