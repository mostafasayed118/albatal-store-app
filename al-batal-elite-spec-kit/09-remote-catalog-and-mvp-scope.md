# P1 — Remote Catalog and Explicit MVP Scope

## Objective
Replace demonstration-only catalog behavior when real commerce launch requires remotely managed products, while preventing scope creep.

## Remote catalog requirements
- Wire `SupabaseCatalogRepository` as the default only after schema, seed data, RLS, image/storage policy, and offline fallback are verified.
- Preserve a safe cached/read-only fallback for network failure.
- Populate staging with real product records, categories, prices, stock, colors, and image references.
- Confirm server-side checkout uses the same canonical product and price records.
- Do not expose admin catalog mutation to ordinary users.

## Admin catalog decision
If admin CRUD is launch scope, implement product/category/image/variant pages using the existing repository methods and add authorization/UI tests. Otherwise mark it explicitly as post-MVP and provide a documented seed/deployment workflow.

## Cloud data decision
Orders should remain server-authoritative with an idempotent local cache. Cart and wishlist synchronization may be deferred only if the product requirements accept device-local behavior; document reinstall and cross-device consequences.

## Acceptance criteria
- Product source of truth is documented.
- Staging catalog is not hardcoded demonstration data.
- A product price/stock change is reflected without an app release when remote catalog is in scope.
- Offline and empty/error states remain usable and localized.
