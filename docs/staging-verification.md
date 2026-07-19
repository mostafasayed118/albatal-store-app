# Staging Verification Checklist

## Pre-Deploy Verification

### 1. Secret Protection ✅
- [ ] `.env`, `.env.staging`, `.env.production` are in `.gitignore`
- [ ] Only `.env.example` was ever committed (verified via `git log`)
- [ ] No API keys, tokens, or secrets in source code
- [ ] Supabase anon key (not service role) used in Flutter app
- [ ] Paymob API key only in Edge Function environment variables
- [ ] Production secrets stored in Supabase Edge Function settings only

### 2. Database Migrations ✅
- [ ] `001_initial_schema.sql` — 10 tables created
- [ ] `002_rls_policies.sql` — RLS enabled on all tables
- [ ] `003_auth_profiles_and_hardening.sql` — Profile trigger, admin role
- [ ] `004_stock_function.sql` — Stock decrement function
- [ ] `005_storage_buckets.sql` — product-images, avatars buckets
- [ ] `006_payments_table.sql` — Payments tracking
- [ ] `007_stock_increment_function.sql` — Stock recovery
- [ ] `008_order_fulfillment.sql` — Status validation, low stock
- [ ] `009_shipping_zones.sql` — 7 Egyptian zones, fee calculation
- [ ] `010_notifications_analytics.sql` — Notifications, analytics, errors

### 3. Edge Functions ✅
- [ ] `checkout` — Server-side order creation
- [ ] `paymob-auth` — Paymob auth token (server-only)
- [ ] `paymob-order` — Paymob order registration (server-only)
- [ ] `paymob-payment-key` — Paymob payment key (server-only)
- [ ] `paymob-callback` — Webhook with HMAC verification
- [ ] `vodafone-cash-payment` — Vodafone Cash initiation
- [ ] `vodafone-cash-verify` — Vodafone Cash verification (idempotent)
- [ ] `send-order-notification` — Email notifications

### 4. Storage Rules
- [ ] `product-images` bucket is public read
- [ ] `avatars` bucket is private (user-scoped)
- [ ] Admin can manage product images
- [ ] Users can upload/manage their own avatar

## Post-Deploy Verification

### 5. Environment Variables
- [ ] Staging Supabase URL loads correctly
- [ ] Staging anon key authenticates
- [ ] Paymob test credentials work
- [ ] Vodafone Cash test credentials work

### 6. Authentication Flow
- [ ] Sign up with email → verification email sent
- [ ] Sign in with credentials → session restored
- [ ] Password reset → email received → new password works
- [ ] Sign out → session cleared
- [ ] Profile created automatically on sign up

### 7. Catalog
- [ ] Products load from Supabase
- [ ] Categories display correctly
- [ ] Search returns relevant results
- [ ] Filters (category, color, price) work
- [ ] Sort options work
- [ ] Product details show stock levels
- [ ] Out-of-stock shows disabled button

### 8. Cart & Wishlist
- [ ] Add to cart (guest) → stored locally
- [ ] Sign in → cart persists across devices
- [ ] Wishlist syncs per user
- [ ] Quantity update works
- [ ] Remove from cart works

### 9. Checkout
- [ ] Address picker shows saved addresses
- [ ] Add new address works
- [ ] Shipping fee calculated by zone
- [ ] Free shipping threshold applied
- [ ] Payment method selection works
- [ ] Order created successfully

### 10. Payments
- [ ] Paymob card: success flow
- [ ] Paymob card: decline handling
- [ ] Vodafone Cash: phone input → verification
- [ ] Cash on Delivery: order placed
- [ ] Payment callback updates order status
- [ ] Failed payment restores stock

### 11. Admin
- [ ] Admin dashboard loads for admin users
- [ ] Non-admin users see access denied
- [ ] Order queue shows all orders
- [ ] Order detail shows items and address
- [ ] Status update works (placed → processing → shipped → delivered)
- [ ] Low stock alerts show correctly
- [ ] Stock editing works

### 12. Notifications
- [ ] Order placed → email notification
- [ ] Payment confirmed → email notification
- [ ] Order shipped → email with tracking
- [ ] Order delivered → email
- [ ] Order cancelled → email

### 13. Localization
- [ ] English displays correctly
- [ ] Arabic RTL layout works
- [ ] All strings translated
- [ ] Currency formatting correct (EGY)

### 14. Analytics & Monitoring
- [ ] Analytics events logged
- [ ] Error events logged
- [ ] No sensitive data in logs
