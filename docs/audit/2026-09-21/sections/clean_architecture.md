# Clean Architecture — Re-audit at head `ef91836` (2026-09-21)

- **Dimension:** Clean Architecture — separation of concerns, dependency rules, layering, SOLID
- **Scope:** `lib/` only, 266 non-generated Dart files (~29.8k LOC); `lib/generated/` skipped
- **Prior claim under test:** `docs/audit/2026-09-15/05-reaudit.md` — Clean Architecture **10.0**, "dependency-direction rules were tested mechanically across all 255 files (0 violations)"
- **Commits landed since that claim:** `c7039f3` (full-refactor top-5 + view-layer DI + hardening), `bed0d1c`, `3d78b0c` (core dead-code + codec + fromRow), `024dedd`, plus the admin customer-tier / orders-CSV / admin-coupons-route merges
- **Evidence gates re-run by this auditor:** `flutter analyze --no-pub` → **No issues found** (exit 0, 5.3s)

## 0. Mechanical result (the claim, re-tested)

Method: a parser walked every non-generated `.dart` file, resolved **all** `import`/`export`
directives (relative *and* `package:al_batal_elite/`) to a real target file, classified each file
into `feature/<name>/<layer>` | `core/<sub>` | `shared/<sub>` | `root`, and tested the edges.

**266 files, 1438 resolved import edges.**

| Rule | Violations |
|---|---|
| presentation → data (same feature) | **0** |
| domain → data (same feature) | **0** |
| domain → presentation (same feature) | **0** |
| core → feature | **0** |
| `package:flutter/*` imported by any `domain/` or `core/` file | **0** |
| cubits importing the data layer (24 cubits) | **0** |
| **feature → another feature's internals** | **11** ← the claim does not cover this |
| shared → feature (100 edges) | 90 in the composition root / router (justified), 10 elsewhere |

**Verdict on the claim:** it **holds** for the four vertical layer rules — this is not a case of a
stale claim being repeated; the rules genuinely are clean on the current tree. It does **not** hold
for the rule as this brief states it ("features do not import each other's internals"): there are
**11** such edges, and there are **no barrel files anywhere** under `lib/features/` (`find lib/features -maxdepth 2 -name '*.dart'` returns nothing), so every cross-feature import reaches into
another feature's internals by path. The prior audit's "0 violations" was a narrower rule set than
the claim's wording implies.

Two post-audit commits did **not** add any new dependency-direction violation: a diff of all
`+import` lines over `c7039f3^..HEAD` yields only within-layer edges (`core/error/result.dart`,
the six `admin_*_port.dart` files, `domain/entities/*`, `generated/l10n`). The 11 cross-feature
edges all predate the audit (oldest `34db0a6`, 2026-07-19).

**No CRITICAL finding.** Every feature merged since the audit (admin customer-tier, orders CSV
export, admin coupons route) is reachable and wired: `buildOrdersCsv` is called from
`admin_orders_page.dart:44`, `InvoicePdfBuilder.build` from `admin_order_detail_page.dart:89`,
`setMembershipTier` from `admin_customers_page.dart:73` and `admin_order_detail_page.dart:271`.

---

## HIGH — The domain layer imports a rendering framework: `package:pdf` and `dart:isolate` in `admin/domain/invoice/`

**Location:** `lib/features/admin/domain/invoice/invoice_pdf_builder.dart:1-5`
**Issue:** The domain layer of the admin feature contains a full PDF document renderer. Its first
five lines are `import 'dart:isolate';`, `import 'dart:typed_data';`,
`import 'package:pdf/pdf.dart';`, `import 'package:pdf/widgets.dart' as pw;`. This is the **only**
third-party package imported anywhere under `lib/features/*/domain/` — every other domain import in
the whole tree is `package:equatable` (a pure value-equality library). A grep of
`^import 'package:` over `lib/features/*/domain/` and `lib/core/` returns exactly 16 lines: 14
`equatable`, and these two `pdf` lines. The file was introduced by `b2b0b86` (2026-09-13) — i.e.
it already existed when the 2026-09-15 audit scored Clean Architecture **10.0**. The doc comment
justifies the placement with "Pure Dart — no platform channels, no network", but purity of
implementation is not the test; the test is whether the domain layer knows about document
rendering. It does, and it also owns the isolate-scheduling policy (`Isolate.run` in `build`).
**Impact:** The domain layer can no longer be compiled, unit-tested, or reasoned about without the
`pdf` package and its transitive layout engine. Any `pdf` major bump is now a domain-layer event.
This is the single clearest violation of the hexagonal boundary in the tree, and it was missed by
the audit that declared the dimension clean.
**Fix:** Move the file to `lib/features/admin/data/invoice/invoice_pdf_builder.dart` (one path
change; the file imports only `../entities/admin_order.dart` and the two `pdf` packages, so the
relative import becomes `../../domain/entities/admin_order.dart`). Keep the `InvoicePdfBuilder`
class name and API identical — the two call sites (`admin_order_detail_page.dart:89`) do not
change. If the intent is to keep the domain free of both `pdf` and `isolate`, additionally define
a one-method port `abstract interface class InvoiceRenderer { Future<Uint8List> render(AdminOrder order); }`
in `admin/domain/` and implement it in `admin/data/`.

## HIGH — `SupabaseAdminRepository` is a god-class: 824 lines, 22 public methods, 7 concerns in one class

**Location:** `lib/features/admin/data/supabase_admin_repository.dart:292` (class declaration),
file length 824 lines — the largest non-generated file in the repository, 2.7× the next largest
data-layer file
**Issue:** `c7039f3` split the *interface* into six narrow ports (ISP, see "done well" below), but
left the *implementation* monolithic. `SupabaseAdminRepository implements AdminRepository` — the
facade that extends `AdminOrdersPort`, `AdminCouponsPort`, `AdminCustomersPort`, `AdminReviewsPort`,
`AdminSalesPort`, `AdminCatalogPort` — and implements all 22 methods itself. The file's own section
banners name the seven concerns it carries: Order Fulfillment (322), Variant Management (462),
Catalog Management (472), Coupons (627), Customers (667), Review moderation (780), plus the admin
check at 298. The ISP refactor is therefore only half-applied: a consumer can *depend* on a narrow
port, but every consumer still *loads* a class that knows about all seven concerns.
**Impact:** A change to coupon SQL forces a full re-read/review of the same file that also holds the
keyset-paginated customer directory, the order-status RPC, and the sales aggregation. The seams are
already proven to be correct — the team drew them at the interface — so the cost is pure
maintenance drag on the hottest admin file.
**Fix:** Extract six sibling classes in the same directory, each implementing one port
(`SupabaseAdminOrdersRepository implements AdminOrdersPort`, `SupabaseAdminCouponsRepository`,
`SupabaseAdminCustomersRepository`, `SupabaseAdminReviewsRepository`,
`SupabaseAdminSalesRepository`, `SupabaseAdminCatalogRepository`), each taking the shared
`SupabaseClient` and reusing `AdminMappers`. Then make the registration in
`lib/shared/services/service_locator.dart:98` compose them, e.g.
`SupabaseAdminRepository(client: c, orders: SupabaseAdminOrdersRepository(client: c), …)` — or
simply register each narrow port separately (`registerLazySingleton<AdminCouponsPort>(...)`), which
also lets `app_router.dart` stop resolving the 22-method facade for pages that need three methods
(see the MEDIUM finding below). Do it one concern at a time; the interface already constrains each
extraction.

---

## MEDIUM — DB row mapping lives in a core domain entity: `Profile.fromRow` / `toProfileRow`

**Location:** `lib/core/entities/profile.dart:59` (`factory Profile.fromRow(Map<String, dynamic> row)`)
and `lib/core/entities/profile.dart:79` (`Map<String, dynamic> toProfileRow()`)
**Issue:** The `Profile` entity — a `core/entities` domain model — parses and emits raw `profiles`
table rows. `fromRow` reads the column names `id`, `full_name`, `phone`, `avatar_url`, `is_admin`,
`membership_tier`; `toProfileRow` writes `id`/`full_name`/`phone`/`avatar_url` and documents which
columns RLS pins. This is the one place in the tree where a domain entity owns its own wire
mapping, and it contradicts the convention every other entity follows: `Product` is mapped by
`ProductCodec` in `lib/features/storefront/data/product_mapper.dart`, `Address` by
`AddressCodec` in `lib/core/data/address_codec.dart`, `AdminOrder`/`AdminCoupon`/etc. by
`AdminMappers` in `lib/features/admin/data/admin_mappers.dart`. Post-audit commit `3d78b0c`
("harden `Profile.fromRow`") *reinforced* this placement rather than moving it.
**Impact:** The domain entity is now coupled to the database schema, so a column rename is a
domain-layer edit, and `lib/core/entities/` can no longer be described as schema-free. It also
breaks the single convention an auditor or new contributor would otherwise rely on
("mappers live in `data/`").
**Fix:** Create `lib/core/data/profile_codec.dart` mirroring `address_codec.dart`
(`class ProfileCodec { static Profile fromRow(Map<String, dynamic> row) {...} static Map<String, dynamic> toProfileRow(Profile p) {...} }`), move the two bodies verbatim, and update the callers
(`lib/features/auth/data/supabase_profile_repository.dart` and the `Profile.fromRow` sites) to
`ProfileCodec.fromRow(row)` / `ProfileCodec.toProfileRow(profile)`. Leave the
`membershipTierFromServerValue` decoder where it is — it is a pure enum decoder with no schema
coupling and both layers legitimately share it.

## MEDIUM — Server wire formats are authored in `domain/`: an address-snapshot encoder, a CSV exporter, and a raw map in a repository port

**Location:**
- `lib/features/storefront/domain/usecases/place_checkout_order_usecase.dart:17` —
  `Map<String, dynamic> addressSnapshotJson(Address address)` returns the 5 server keys
  `id/recipient/line/city/country`
- `lib/features/storefront/domain/repositories/checkout_repository.dart:15` —
  `required Map<String, dynamic> addressSnapshot` in a domain port signature
- `lib/features/admin/domain/orders_csv_exporter.dart:8` — `String buildOrdersCsv(List<AdminOrder>)`
  builds a CSV wire format (header row, `\r\n` line endings, RFC-4180 quoting, formula-injection
  guard) and `:30` `ordersCsvFileName(DateTime)`

**Issue:** Three separate encoders for external formats are parked in `domain/`. The address
encoder's own doc comment states the reason explicitly: *"Lives in domain (not `core/data/`) so the
domain use-case no longer imports across the layer boundary."* That is the mechanical rule being
satisfied by relocating the offending code rather than by removing the coupling — the domain still
knows the server's snapshot key names, and a domain port now exposes an untyped
`Map<String, dynamic>` in its public contract. The CSV exporter is the same pattern: `buildOrdersCsv`
was introduced by `32a2bf6` (2026-09-12) and lives in `domain/` purely by placement, not by nature —
it is an export/formatting concern with a caller in presentation
(`admin_orders_page.dart:43-44`).
**Impact:** The domain layer's contracts are untyped at exactly the boundary that matters most (the
checkout RPC payload), so a key rename is a silent runtime mismatch rather than a compile error, and
the "domain has no serialization" invariant this codebase otherwise maintains is untrue in three
places. An auditor cannot use import direction alone to certify domain purity here.
**Fix:** (a) Introduce `final class AddressSnapshot` in
`lib/features/storefront/domain/entities/` with the five fields, change
`CheckoutRepository.placeOrder({required AddressSnapshot addressSnapshot})`, and move the JSON
encoding into the data implementation (`lib/features/storefront/data/checkout_service.dart`), which
is where the Supabase RPC payload is actually built. (b) Move
`lib/features/admin/domain/orders_csv_exporter.dart` → `lib/features/admin/data/orders_csv_exporter.dart`
(its only import is `entities/admin_order.dart`, so the path becomes `../domain/entities/admin_order.dart`).
Both are mechanical moves that shrink the domain surface without changing behaviour.

## MEDIUM — 11 feature→feature internal imports with no barrels; `auth` and `storefront` are mutually coupled

**Location (complete list, mechanically derived):**
| # | From | Line | Imported internal |
|---|---|---|---|
| 1 | `lib/features/auth/data/supabase_auth_session_port.dart` | 3 | `storefront/domain/repositories/auth_session_port.dart` |
| 2 | `lib/features/auth/presentation/cubit/auth_cubit.dart` | 9 | `addresses/domain/repositories/address_repository.dart` |
| 3 | `lib/features/payments/presentation/pages/payment_method_page.dart` | 10 | `storefront/presentation/cubit/cart_cubit.dart` (used at `:127` `context.read<CartCubit>().clear()`) |
| 4 | `lib/features/storefront/data/checkout_service.dart` | 9 | `payments/domain/entities/payment.dart` |
| 5 | `lib/features/storefront/data/storefront_persistence.dart` | 13 | `auth/domain/repositories/order_snapshot_port.dart` |
| 6 | `lib/features/storefront/domain/repositories/checkout_repository.dart` | 3 | `payments/domain/entities/payment.dart` |
| 7 | `lib/features/storefront/domain/usecases/place_checkout_order_usecase.dart` | 5 | `payments/domain/entities/payment.dart` |
| 8 | `lib/features/storefront/presentation/cubit/checkout_cubit.dart` | 10 | `payments/domain/entities/payment.dart` |
| 9 | `lib/features/storefront/presentation/pages/checkout_page.dart` | 16 | `addresses/presentation/cubit/addresses_cubit.dart` (used at `:401` `context.read<AddressesCubit>().upsert(address)`) |
| 10 | `lib/features/storefront/presentation/pages/home_page.dart` | 21 | `auth/presentation/cubit/auth_cubit.dart` (used at `:72` `BlocSelector<AuthCubit, …>`) |
| 11 | `lib/features/storefront/presentation/widgets/address_picker.dart` | 6 | `addresses/presentation/cubit/addresses_cubit.dart` (used at `:30` `BlocBuilder<AddressesCubit, …>`) |

**Issue:** The tree has a documented cross-feature pattern — a narrow domain port owned by the
*consumer* (`OrderSnapshotPort` in `auth/domain`, `AuthSessionPort` in `storefront/domain`,
`AccountDeletionPort` in `settings/domain`) plus an adapter composed at the root — and rows 1, 5,
and the `AccountDeletionPort` case follow it. Rows 2, 3, 9, 10, 11 do not: they are presentation
reaching straight into another feature's cubit, which is the one thing the ports exist to prevent.
Note also that the port pattern has produced a **cycle between two features**: `auth/data` depends
on `storefront/domain` (row 1) while `storefront/data` depends on `auth/domain` (row 5), so the two
features can never be extracted or tested independently — the coupling is mutual, not one-way.
Separately, `AdminReview` is declared in `lib/features/storefront/domain/entities/product_review.dart:33`
— an admin-domain concept parked in the storefront domain, and it is referenced nowhere else in
`lib/` (2 grep hits, both the declaration).
**Impact:** Cross-feature presentation coupling means a change to `AddressesCubit`'s API breaks the
storefront checkout page, and the "features are independently shippable" property the ports were
built to buy is not actually held for `addresses`/`auth`/`payments`/`storefront`. The mutual
auth↔storefront edge is the concrete blocker for any future feature extraction.
**Fix:** (a) Add barrel files so cross-feature access is explicit and versionable —
`lib/features/addresses/addresses.dart` exporting only `AddressesCubit`, `AddressesState`, and
`Address` — and point rows 9 and 11 at the barrel (a two-line change per site). (b) For rows 2, 3,
and 10, extend the existing port pattern: give `storefront` a `CartClearPort` in its own domain
(mirroring `OrderSnapshotPort`) implemented by a thin adapter, and give `auth` a
`LocalAddressWipePort` for the `_clearLocalSnapshots` call at `auth_cubit.dart:258` rather than
importing `addresses/domain/repositories/address_repository.dart`. (c) Move `AdminReview` to
`lib/features/admin/domain/entities/` and delete it if it stays unreferenced.

## MEDIUM — Six admin pages still depend on the 22-method facade and run data orchestration (and the admin authorization check) inside the widget

**Location:** `lib/features/admin/presentation/pages/admin_catalog_page.dart:20`
(`final AdminRepository repository;`), `admin_products_page.dart:28`,
`admin_product_edit_page.dart:32`, `admin_categories_page.dart:24`,
`admin_image_manager_page.dart:44`, `admin_variant_editor_page.dart:27`
**Issue:** `c7039f3` moved four cubits and five pages onto narrow ports; six pages were left on the
full facade. Their actual usage is 1–4 methods each, all of which are members of `AdminCatalogPort`:
`admin_categories_page.dart:47` and `admin_product_edit_page.dart:143` call only
`getAllCategories()`; `admin_products_page.dart:51` only `getAllProducts()`;
`admin_product_edit_page.dart:98/225` `getProductById()` + `adminUpsertProduct()`;
`admin_variant_editor_page.dart:57/175` `getVariants()` + `adminUpsertVariant()`;
`admin_image_manager_page.dart` the image pair. Worse, `admin_catalog_page.dart:25-40` performs an
authorization decision in the view — `await repository.isCurrentUserAdmin()` inside
`_guardedPush`, with its own `try/catch` and its own `showFloatingError` copy — which duplicates the
router's policy at `lib/shared/routing/app_router.dart:90-94` (`auth.profile?.isAdmin != true`).
`admin_product_edit_page.dart:186` similarly swallows a failure into `Log.w` +
`setState(() => _loadingCategories = false)` in a `catch` block, even though the load it wraps
(`getAllCategories()` at `:143`) already returns a `Result` that the caller handles.
**Impact:** These six pages cannot be widget-tested without faking 22 methods, so the ISP work is
half-wired. Authorization has two independent sources of truth (router redirect + page guard) that
can drift; a change to the admin policy must be found and edited in both.
**Fix:** (a) Change the six constructors from `AdminRepository` to `AdminCatalogPort` and change
`app_router.dart:302/316/321/327/333/341/353` to resolve `getIt<AdminCatalogPort>()`. `AdminCatalogPort`
already declares every method these pages call, so no method moves. (b) Delete `_guardedPush`'s
authorization branch from `admin_catalog_page.dart:25-40` and rely on the router's `_redirect`
(`app_router.dart:90-94`), which already returns `Routes.home` for a non-admin; if a defence-in-depth
check is wanted, put it in the router only. (c) Register the narrow ports in
`service_locator.dart:98` alongside the facade so both resolutions work.

## MEDIUM — `app_router.dart` is a 374-line god-file: route table + auth policy + 48 service-location calls + page construction

**Location:** `lib/shared/routing/app_router.dart` — `_redirect` policy at `:80-113`, the route
table at `:115-374`, and **48 `getIt` calls** inside the builders (`:121-359`)
**Issue:** The file mixes four responsibilities that the audit trail treats as three different
things: the route table (`_routes`), the authentication/authorization redirect policy (`_redirect`),
dependency resolution (48 `getIt<…>` / `getIt.isRegistered<…>` probes), and per-route page
construction including argument parsing (`s.extra is Map<String, dynamic> ? … : {}` at `:231-233`,
`:250-256`). DI is otherwise centralized in `lib/shared/services/service_locator.dart` (42
registrations) and app-scoped cubit construction in `lib/app.dart:77-226`; `app_router.dart` is now
the de-facto third composition root. The `getIt.isRegistered` probes are test affordances that have
leaked into production routing — a route builder now has to know which beans a widget test might not
have registered (`:165-173`, `:254-256`, `:344-346`).
**Impact:** Any new screen touches this file, and any new test-only dependency requires another
`isRegistered` branch here. The redirect policy is not unit-testable in isolation because it is a
private function inside a file that also owns the route table.
**Fix:** Split into three files in `lib/shared/routing/`: `app_router.dart` (keeps `createAppRouter`
+ `_routes`, ~250 lines), `auth_redirect.dart` (exports
`String? authRedirect(AuthState auth, GoRouterState state)` — a pure function, directly unit-testable),
and `route_dependencies.dart` (a small class with one accessor per bean, constructed once at the root
and passed to `createAppRouter`, so the `isRegistered` probes live in one place instead of inline in
builders).

## MEDIUM — `PaymentCubit` is a 443-line god-cubit with an if-chain dispatch that grows per payment method

**Location:** `lib/features/payments/presentation/cubit/payment_cubit.dart` — class at `:88`,
dispatch at `:149-155`, handlers `_processCod` `:158`, `_processInstapay` `:213`, `_processCard`
`:242`, watch lifecycle `startWatching` `:351` / `_handleWatchTimeout` `:408` / `_stopWatching` `:430`
**Issue:** One cubit owns three unrelated payment flows plus a server-status watcher plus a 15-minute
timeout, and dispatches by comparing enum members one at a time:
`if (state.selectedMethod == PaymentMethod.cashOnDelivery) return _processCod(); if (… == instapay) return _processInstapay(); return _processCard(…)`. A fourth method (e.g. a wallet or
instalments provider) means editing this file's dispatch, adding a fourth private handler, and
possibly extending the watch rules — a textbook open/closed violation, and the largest cubit in the
tree (443 lines, 1.5× the next largest).
**Impact:** Payment work is the highest-risk area of a commerce app, and it is the least
decomposed. Each new method increases the blast radius of a change to any existing one, and the
watcher/timeout lifecycle cannot be tested without constructing all three flows.
**Fix:** Extract one `PaymentMethodHandler` per method —
`abstract interface class PaymentMethodHandler { PaymentMethod get method; Future<void> process(PaymentCubit ctx, PaymentState state); }` — in
`lib/features/payments/domain/` (pure, no Flutter), implement `CodPaymentHandler`,
`InstapayPaymentHandler`, `PaymobCardPaymentHandler` in
`lib/features/payments/data/`, and replace `:149-155` with a
`Map<PaymentMethod, PaymentMethodHandler>` lookup built in the constructor. Leave the watch/timeout
lifecycle in the cubit (it is genuinely shared) or move it to a small `PaymentStatusWatcher` class
collaborator — either way the dispatch chain stops growing.

---

## LOW — A concrete implementation class lives in a domain directory

**Location:** `lib/features/storefront/domain/repositories/memory_idempotency_store.dart:12`
(`final class MemoryIdempotencyStore implements IdempotencyStore`)
**Issue:** This is the **only** concrete implementing class anywhere under `lib/features/*/domain/`
— every other domain file is an entity, a value object, or an `abstract interface class` port
(verified by grepping `implements`/`extends` across all domain directories). Its doc comment
concedes the reason: *"so presentation cubits never need a data-layer import to default-construct."*
It is a test double shipped in the domain layer to satisfy the import rule.
**Impact:** Small but precedent-setting: the domain layer now contains code that exists only for
tests and for a default constructor argument (`checkout_cubit.dart:145`).
**Fix:** Move the class to `lib/features/storefront/data/memory_idempotency_store.dart` and have
`CheckoutCubit`'s test-only default come from the test file (the cubit already accepts an injected
`IdempotencyStore`), or make the parameter `required` and let `app_router.dart:180-182` supply the
persisted store unconditionally.

## LOW — The shared layer's port implementation holds a `BuildContext` and reads feature presentation cubits

**Location:** `lib/shared/settings_account_adapter.dart:19-22` (class holds `final BuildContext _context`),
cubit reads at `:25`, `:29`, `:33-34`; consumed from `lib/shared/routing/app_router.dart:207-208`
**Issue:** `SettingsAccountAdapter implements AccountDeletionPort` (a settings-domain abstraction)
by resolving `AuthCubit`, `CartCubit`, and `WishlistCubit` out of a `BuildContext`. So the only
production implementation of a domain port lives above the presentation layer and depends on three
other features' presentation types. The comment argues this is acceptable because `shared/` already
imports every feature for routing — which is true, but it means the port abstraction buys
type-decoupling only, not dependency-direction correctness. The same pattern appears in
`lib/shared/components/app_shell.dart:7-8`, which imports `CartCubit` and `WishlistCubit` for the
navigation badges.
**Impact:** Low in practice (the adapter is constructed inside the route builder's context and its
reads happen in callbacks), but it means `settings` cannot be extracted with its port intact, and a
`BuildContext` is now retained in a field whose lifetime is not obviously bounded by the widget tree.
**Fix:** Replace the `BuildContext` field with the three concrete dependencies the adapter actually
needs — `SettingsAccountAdapter({required AuthCubit auth, required CartCubit cart, required WishlistCubit wishlist})` —
and construct it in `app.dart` where all three already exist as fields, passing the instance into
`createAppRouter`. That removes the context retention and makes the adapter's dependency set explicit.

## LOW — `setMembershipTier` is implemented twice in two cubits

**Location:** `lib/features/admin/presentation/cubit/admin_cubit.dart:230` and
`lib/features/admin/presentation/cubit/admin_customers_cubit.dart:258`
**Issue:** Both cubits delegate the same repository call with the same error handling, and both are
reachable from UI (`admin_customers_page.dart:73` uses the customers cubit;
`admin_order_detail_page.dart:271` uses the other). The membership-tier merge added the second path
without removing the first.
**Impact:** Two state/error surfaces for one operation; a change to the tier contract must be made
twice.
**Fix:** Keep the `AdminCustomersCubit` implementation (it owns the directory state) and have
`admin_order_detail_page.dart:271` obtain it via `context.read<AdminCustomersCubit>()` if that cubit
is provided above the detail route; otherwise delete `AdminCustomersCubit.setMembershipTier` and
route both pages through `AdminCubit`. Do not keep both.

## LOW — Empty scaffold directory `lib/core/helper/`

**Location:** `lib/core/helper/` (0 files; `ls -a` returns only `.` and `..`)
**Issue:** The directory is listed in the project's structure description and in this brief's scope
(`lib/core/{data,entities,error,helper,utils}`) but contains nothing. No `.gitkeep`, no file.
**Impact:** Cosmetic; it misleads a reader of the structure map into looking for a layer that does
not exist.
**Fix:** `rmdir lib/core/helper` (it is untracked-empty, so nothing in git changes), or drop it from
the documented structure.

---

## What's done well

- **The four vertical dependency rules are genuinely, mechanically clean.** 0 violations across 266
  files / 1438 resolved import edges: no presentation→data, no domain→data, no domain→presentation,
  no core→feature. Notably **0 `package:flutter/*` imports anywhere in `domain/` or `core/`** — the
  domain is Flutter-free even though the PDF builder shows it is not framework-free.
- **All 24 cubits depend on abstractions only.** A per-file count of `domain/` vs `data/` imports
  over every `lib/features/*/presentation/cubit/*.dart` returns `data=0` for all 24 files, and no
  cubit contains a single `GoRouter` / `context.push` / `Navigator` call — navigation is entirely
  out of the blocs. The repository pattern is real, not nominal.
- **DI is centralized and the post-audit "view-layer DI" work is real.** `getIt<…>` appears in
  exactly three production files (`service_locator.dart` for 42 registrations, `app_router.dart`,
  `app.dart`) and **zero** times under `lib/features/` — the six admin pages that once
  service-located now carry explicit comments recording the removal. Constructor injection is the
  norm.
- **The ISP split into six admin ports is a genuine improvement, not a rename.** `AdminRepository`
  (`admin_repository.dart:30-40`) is now a thin facade that `implements` six single-concern
  `abstract interface class` ports, and four cubits plus five pages consume the narrow ones.
- **Error typing is consistent end to end.** `lib/core/error/result.dart` is a `sealed class Result<T>`
  with `Success`/`Failure` and a single `Result.guard` boundary; the only 16 `catch` sites in
  presentation are local (file picking, image decoding) or deliberate fail-soft degradations, not an
  ad-hoc alternative to `Result`. Routes are centralized in `lib/shared/routing/app_routes.dart` with
  typed builders (`Routes.product(id)`), and deep-link *parsing* is a pure function in
  `shared/services/deep_link_parser.dart` with navigation performed in `app.dart` — the right layer.

---

SCORE: 7.5/10 — The classic dependency rules that the prior audit tested really are clean on the
current tree (0/1438 vertical violations, 24/24 cubits abstraction-only, no Flutter in domain, DI
centralized), and the post-audit commits added no new directional violations. But the 10/10 was
scoped to import direction alone, and by the broader standard this brief sets the dimension has real
defects: the domain layer imports `package:pdf` and owns PDF rendering (`invoice_pdf_builder.dart:4-5`)
and three separate wire-format encoders, the largest service is an 824-line/22-method god-class
whose ISP split was applied to the interface only, 11 feature→feature internal imports exist with no
barrels and `auth`↔`storefront` are mutually coupled, and the router has become a third composition
root. None of these is a silent-breakage bug — `flutter analyze` is clean and every merged feature is
reachable — so the deduction is for structural erosion and for the gap between the claim and its
scope, not for broken behaviour.
