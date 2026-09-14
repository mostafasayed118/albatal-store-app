# Packages Proposal — Images / Offline / Notifications

> **Status: APPROVED (docs) — DO NOT APPLY to `pubspec.yaml` yet** — L1 report-only.
> No `pubspec.yaml`, `supabase/`, native, or CI change was made. Per `loop-constraints.md`:
> do not add dependencies without why + alternatives; never run
> `flutter pub upgrade` without approval; `flutter analyze` before `flutter test`.
> Verified 2026-09-10 against pub.dev + local tree (Flutter 3.48.0 / Dart 3.12.2).
> Re-verified 2026-09-10 via pub.dev API: all 11 pins below match `latest.version`
> live (no drift).

## 0. Grounding (what exists today)

- `pubspec.yaml:10` — `cached_network_image ^3.3.1`, `image_picker ^1.1.2`,
  `supabase_flutter ^2.8.4`, `go_router ^18.0.1`, `flutter_bloc ^9.1.1`,
  `sentry_flutter ^9.28.0`, `flutter_secure_storage ^9.2.4`.
- Single image pipeline: `lib/shared/components/app_image.dart` (SVG local-only
  assert + `CachedNetworkImage` remote) and
  `lib/features/storefront/presentation/widgets/product_image_resolver.dart`
  (null → swatch fallback, http → `CachedNetworkImage` 1080px, asset → `Image.asset`).
  No zoom viewer, no skeleton loader, no client-side compression.
- InstaPay proof path: `lib/features/payments/presentation/pages/instapay_instructions_page.dart`
  picks via `ImagePicker`, holds `_attachedBytes/_attachedExt`, submits to the
  private `instapay-proofs` bucket (server enforces size+ext, fails closed).
- Offline: catalog has cache-restore but **no** `connectivity_plus` listener —
  grep finds zero references in `lib/`. A router Wi-Fi with no internet would
  read as "connected" if only interface type is checked.
- Notifications: only a code comment about "bad notifications" deep links in
  `admin_order_detail_page.dart:64`. No local or push plugin in `lib/`.

## 1. INSTRUCTIONS D3 decision table (why now / alternatives / defer?)

| # | Package (pin, 2026-09-10) | Why needed now | Alternatives considered | Defer? | Risk |
|---|---|---|---|---|---|
| A1 | `flutter_image_compress: ^2.5.1` (1.8k likes, 150 pts, verified publisher fluttercandies) | InstaPay proofs hit server size guard with 4K phone photos. Native compress (not Dart isolate) before upload cuts rejects + storage egress. | `image` pure-Dart (too slow per upstream; release-build jank), skip + rely on server reject (bad UX). | **No** — ships with InstaPay #37/#38 | Low. Federated plugin, Android/iOS/macOS/Web. Catch `UnsupportedError` → fallback JPEG (HEIC/WebP matrix). Needs `path_provider` for `compressAndGetFile` target dir (already transitive via others; add explicitly if used). |
| A2 | `photo_view: ^0.15.0` (3.2k likes, 150 pts, MIT) | Fabric texture needs pinch-zoom on PDP gallery; current resolver has no zoom path. | `easy_image_viewer` (simpler dialog, less controller control), hand-rolled `InteractiveViewer` (no gallery, no hero, reinvent). | **Yes** — until PDP-zoom scoped | **Medium — staleness.** Last publish ~2y ago. Zero-dep (`flutter` only) so breakage risk is low, but expect no fixes. Isolate to one `FabricZoomViewer` wrapper so swap-out is one file. |
| A3 | `skeletonizer: ^2.1.3` (2.3k likes, 160 pts, MIT, zero-dep) | Catalog/home grids flip spinner → content; premium feel needs skeleton matching `card-surface 16px` + RTL shimmer. Wraps existing layout, no duplicate skeleton layout to drift. | `shimmer` classic (manual colors, duplicate layouts drift), `adaptive_shimmer` (newer, smaller community). | Soon — catalog polish batch | Low. Pure Flutter. Needs fake data while loading (`BoneMock`/filled list) + `Skeleton.replace` around `CachedNetworkImage` so empty URLs don't throw during skeleton. |
| A4 | `flutter_animate: ^4.5.2` | Hero/carousel/order-success entrances without `AnimationController` boilerplate + disposal bugs. | Hand-rolled implicit animations (more code), `rive` (native runtime in 2026, heavy for simple fades). | Yes — motion pass | Low. Pure Dart. |
| B1 | `connectivity_plus: ^7.3.1` (Flutter Favorite, 4k likes, 160 pts) | Only interface-type signal; drives offline banner + pauses proof upload + resumes Supabase watch on foreground. | Hand-rolled `Socket` ping (no stream, battery), `like`/`flutter_omni_kit` mega-kits (fight Clean Arch + BLoC). | **No** — offline correctness | **Medium — native bump.** Requires Flutter ≥3.19 (have 3.48 ✓), Dart ≥3.3 <4.0 (have 3.12 ✓), **Java 17 + AGP ≥8.12.1**. Verify `android/` AGP + `compileSdk` before `pub get`; iOS simulator stream is known-unreliable (test on device). Never gate requests on it alone — always keep timeout/catch (upstream note). |
| B2 | `internet_connection_checker_plus: ^3.1.2` (530 likes, 160 pts, pure Dart) | `connectivity_plus` reports hotel-WiFi-no-internet as online. This checks real reachability (1.1.1.1, icanhazip, gstatic, captive.apple) with subsecond stream. | `internet_connection_checker` legacy (superseded), custom HEAD to Supabase URL (reinvent, CORS/cache pitfalls on web). | With B1 | **Medium — v3 breaking.** v3 **removes** the `connectivity_plus` dep and changes API (`InternetConnection().hasInternetAccess` / `onStatusChange`, `createInstance` + `dispose` only for custom instances, never dispose singleton). Pair: `connectivity_plus` = cheap interface flap, this = debounced truth. Web needs non-cached, non-CORS-blocked endpoints if customized. |
| C1 | `flutter_local_notifications: ^22.3.0` (Flutter Favorite, 7.3k likes) | Order `paid→shipped→delivered` + InstaPay review outcomes need foreground/background/terminated taps with deep-link payload (`orderId` rehydration path already exists on Instapay page). | `awesome_notifications` (smaller core team), FCM-only (forces Firebase, conflicts with Supabase-only per INSTRUCTIONS I-11). | Yes — until notify scoped | **High — native setup.** Requires **Flutter ≥3.38.1 (have 3.48 ✓), `compileSdk 36`, AGP 8.11.1+, Java 17, desugaring + `multiDexEnabled`**, `POST_NOTIFICATIONS`/`VIBRATE` + receivers/services in `AndroidManifest.xml`, iOS `UNUserNotificationCenter.delegate`, web permission only after user gesture. Samsung 500-alarm limit + Xiaomi/Huawei background kills apply to scheduled notifications. Recommend: start with show-only + tap-payload, no exact-alarms (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` need store audit). |
| C2 | `onesignal_flutter: ^5.6.10` | Server-side order pushes without running Firebase; fits Supabase edge-function trigger → OneSignal REST. | `firebase_messaging` (forces Firebase project), raw APNs/FCM (native code, violates Flutter-first). | Yes — with C1, server-gated | **Medium.** Unverified uploader, license unknown on pub.dev — legal flag. v5 user-centric API has migration advisory (not 1:1 with v4); use staged rollout. `ONESIGNAL_DISABLE_LOCATION=true` if location unused (clears caches on change). Needs Notification Service Extension subspec parity on iOS. |
| S1 | `share_plus: ^13.3.0` + `app_links: ^7.2.1` | Share fabric/product via WhatsApp + `/product/:id` deep link; reuses existing `go_router` rehydration pattern. | `share` legacy (unmaintained), manual `MethodChannel` (native, no). | Yes — growth loop | Low-Medium. `app_links` needs intent-filter / associated-domains + router test for `?redirect=`-style guard. |
| S2 | `permission_handler: ^13.0.2` | Camera/gallery (proofs) + notification permission rationale in one place. | Per-plugin requests (scattered UX). | With A1/C1 | Low. Justification strings required on iOS/Android 13+. |

Health rule applied: latest stable, likes+points+publisher checked 2026-09-10;
no alpha/beta; `photo_view` flagged stale explicitly; `onesignal` license flagged.

## 2. Deep dive — A. Images

Current: `AppImage` + `ProductImageResolver` already centralize fallback
(swatch + `Icons.texture`), `memCacheWidth` budgets (grid 420px, hero 1080px),
150ms fade. Gaps: (1) upload size, (2) zoom, (3) loading shimmer.

**A1 compress — where it lands (Clean Architecture):**
presentation (`instapay_instructions_page.dart`, payments feature) calls a new
`ProofImageCompressor` interface in `payments/domain`; impl in `payments/data`
wraps `FlutterImageCompress.compressWithFile(path, minWidth: 1920,
minHeight: 1920, quality: 88)` → JPEG; on `UnsupportedError` retry JPEG;
skip when `bytes < threshold` (upstream FAQ: re-encoding small PNGs can grow).
Keep server size+ext check as authority — client compress is UX, not security.
Tests: unit loop-to-under-N-bytes (quality steps), fallback-on-UnsupportedError,
EXIF-orientation upright (`autoCorrectionAngle` default true; don't also pass
non-zero `rotate`).

**A2 zoom — one wrapper:** new `shared/components/fabric_zoom_viewer.dart`
owning `PhotoView`/`PhotoViewGallery` + `CachedNetworkImageProvider`. Call sites
(product gallery only) keep resolver for cards. Staleness containment: if
`photo_view` breaks on a future Flutter, rewrite is one file → `InteractiveViewer`.

**A3/A4 loading+motion:** `Skeletonizer(enabled: loading, child: existingCard)`
with filled fake products; `Skeleton.replace(width/height)` on the image slot;
`SkeletonizerConfigData` light/dark in `app_theme.dart` extensions to match
emerald/gold shimmer. `flutter_animate` only for `.animate().fade().slide()`
entrances — no controllers, no new state classes (constraint: no Cubit signature
changes without approval).

```yaml
# PROPOSAL ONLY — DO NOT APPLY (needs human approval per loop-constraints.md)
# dependencies:
#   flutter_image_compress: ^2.5.1
#   photo_view: ^0.15.0
#   skeletonizer: ^2.1.3
#   flutter_animate: ^4.5.2
```

## 3. Deep dive — B. Offline

Two-layer signal, one Cubit seam:

1. `connectivity_plus.onConnectivityChanged` — cheap, immediate (none vs wifi/mobile).
2. `InternetConnection().onStatusChange` — debounced truth (connected/disconnected).

New `core/network/connectivity_gate.dart` (data-layer service, GetIt lazy
singleton) exposes `Stream<bool> isOnline` combining both; `CatalogCubit`/
`PaymentCubit` subscribe for banner copy + pause/resume of the server watch
(reuse existing poll/watch, don't duplicate timers). App-lifecycle: cancel on
pause, re-subscribe on resume (broadcast-stream stale-event note, issue #105).
`enableStrictCheck` stays OFF with defaults; if custom endpoints are added they
must be no-cache + CORS-open for web. Tests: `fake_async` stream flap
(none→wifi→none), hotel-WiFi case (interface wifi + checker disconnected →
banner stays), no request gated solely on interface type.

```yaml
# PROPOSAL ONLY — DO NOT APPLY
# dependencies:
#   connectivity_plus: ^7.3.1
#   internet_connection_checker_plus: ^3.1.2
```

Pre-flight before any `pub get`: confirm `android/settings.gradle(.kts)` AGP
≥8.12.1, Java 17 toolchain, `compileSdk` level; run `flutter pub outdated`
first (never `pub upgrade` unapproved).

## 4. Deep dive — C. Notifications

Phased — local first, push second, exact-alarms never (unless store-approved):

**Phase 1 (local, `flutter_local_notifications ^22.3.0`):** init in
`bootstrap.dart` (composition root, not widgets); channels per order event;
payload = `orderId` string; tap → existing `go_router` order-details route
(reuse `orderId` rehydration idiom from Instapay page). Foreground: show +
in-app snackbar; background/terminated: tap opens order. Android: add
`POST_NOTIFICATIONS` runtime request on 13+, receivers for actions, `keep.xml`
for icons, desugaring block in `build.gradle(.kts)`. iOS: delegate in
AppDelegate + permission text. Tests: payload parse, tap→route, permission-denied
path keeps app usable.

**Phase 2 (push, `onesignal_flutter ^5.6.10`):** Supabase edge function on
`orders`/`payments` transition → OneSignal REST with `orderId` data; client sets
external-id = `auth.user.id` on sign-in, clears on sign-out (PII wipe rule from
STATE.md audit stays: sign-out clears addresses+orders snapshots). Staged rollout
per OneSignal v5 advisory; `ONESIGNAL_DISABLE_LOCATION=true` unless geo needed.
Legal gate: confirm license + DPA before prod (pub.dev lists license unknown).

```yaml
# PROPOSAL ONLY — DO NOT APPLY
# dependencies:
#   flutter_local_notifications: ^22.3.0
#   onesignal_flutter: ^5.6.10
#   permission_handler: ^13.0.2
#   share_plus: ^13.3.0
#   app_links: ^7.2.1
```

## 5. Rollout order (separate draft PRs, L2 worktree each)

1. A1 compress (payments, unblocks InstaPay) + tests.
2. B1+B2 gate (core service + banner copy EN/AR) + tests.
3. A3 skeleton (catalog cards) + A4 entrances.
4. A2 zoom wrapper (gallery only).
5. C1 local notify (show-only + tap-payload).
6. C2 push + S1/S2 (server-gated, needs human deploy review).

Verification each slice: `flutter analyze` → `flutter test` → `dart format`
canonical → `git diff --check`; record evidence in `STATE.md`. No
`pubspec.lock` hand-edits; no BLoC signature / GoRouter / RLS changes without
explicit review.

## 6. Rejected (and why)

- `like`, `flutter_omni_kit`, `fluxy`, `moose_core` — framework-kits that replace
  BLoC/GetIt/GoRouter layering; violate INSTRUCTIONS I-11 + smallest-change rule.
- `dio`/`retrofit` — no direct REST outside Supabase client today; adding an HTTP
  client without a caller is ceremony.
- `firebase_messaging`/`firebase_analytics` — forces Firebase; project is
  Supabase-only by decision.
- `getx`/`riverpod` — conflicts with BLoC/Cubit stack in place.
- `drift`/`hive`/`isar` — no relational offline requirement yet; Supabase cache +
  `shared_preferences` suffice until offline-first is scoped.
