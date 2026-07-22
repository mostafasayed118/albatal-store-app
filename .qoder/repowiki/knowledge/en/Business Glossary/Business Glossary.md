---
kind: business_term
name: Business Glossary
category: business_term
scope:
    - '**'
---

### Al Batal Elite
- Definition：The project name for a premium fabric-commerce Flutter application targeting the Egyptian market, featuring a textile-inspired design system with Emerald/Gold light mode and Charcoal/Slate dark mode.
- Aliases：albatal_store、Al Batal

### Money
- Definition：A value object representing monetary amounts as integer minor units (cents) shared between the Flutter client and PostgreSQL database to avoid decimal rounding errors; all money columns are INTEGER cents and no *100/**/100 conversion leaks across layers.
- Aliases：minor units、integer cents

### Local-first storefront
- Definition：Architecture decision where catalog browsing and all client-side personal data (cart, wishlist, addresses, order history) are stored locally via SharedPreferences, while only authentication, profiles, admin operations, and checkout remain server-backed through Supabase.
- Aliases：local persistence、offline-first

### Server-side checkout
- Definition：Checkout flow where the client calls the `create_checkout_order` SECURITY DEFINER RPC which validates prices, checks stock, calculates shipping, decrements inventory, and creates orders atomically in one transaction — the client never sends or overrides price/total values.
- Aliases：atomic checkout、RPC checkout

### HMAC verification
- Definition：Security mechanism used in the Paymob callback Edge Function to verify webhook authenticity by building a canonical payload from documented fields in exact order and comparing signatures in constant time before processing any payment state changes.
- Aliases：callback verification、webhook security

### Stock restoration
- Definition：Mechanism that restores product inventory exactly once when an order is cancelled or payment fails, using a `stock_restorations` ledger table and `order_items.restored` flags with triggers to prevent double-restoration of stock.
- Aliases：inventory recovery、stock rollback

### Order idempotency
- Definition：Protection against duplicate order creation using an `idempotency_key` parameter in the checkout RPC, ensuring that concurrent or retried checkout requests return the same existing order rather than creating duplicates.
- Aliases：idempotent checkout、duplicate prevention

### Row Level Security (RLS)
- Definition：PostgreSQL security policy layer that restricts data access at the row level, ensuring users can only access their own profiles, addresses, wishlists, cart items, and orders — enforced on every table in the schema.
- Aliases：RLS policies、row-level access control

### Staging deployment
- Definition：Deployment process using the Supabase CLI to apply migrations and deploy Edge Functions to a staging environment, with separate `.env.staging` configuration and manual secret setup for Paymob credentials.
- Aliases：staging setup、deploy-staging

### Environment banner
- Definition：Development-only UI indicator showing a colored 'DEV' banner at the top of the screen to distinguish development builds from production, automatically hidden in release builds.
- Aliases：dev banner、environment indicator
