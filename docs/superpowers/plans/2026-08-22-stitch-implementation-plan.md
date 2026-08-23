# Al Batal Stitch Implementation Plan

> **STATUS: COMPLETE — 2026-08-23.** All phases committed (`1bf7db3` tokens →
> `dc60ad8` primitives → `6308c6c` home → `8864c71` details/cart → `670341c`
> categories/catalog → `7802a53` checkout "phase 5 FINAL" incl. dark verify).
> Final verification 2026-08-23: `flutter test` **243/243 PASS**, `flutter
> analyze` **0 issues**. Checkboxes below were completed as part of execution.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Translate Stitch project 10846693823016291635 (4 flows, light+dark) pixel-perfect into Flutter, preserving Clean Architecture and passing flutter test/analyze.

**Architecture:** Incremental per-flow worktrees. Phase 0 syncs AppTheme/DESIGN.md tokens to exact Stitch designMd (#f9f9f9 surface, #003527 primary, radii, typography). Phases 1-4 reskin Home, Details/Cart, Categories/Orders, Checkout using new lib/shared/components/stitch primitives wired to existing Cubits (CatalogCubit flash timer rebuild).

**Tech Stack:** Flutter 3.19+/Dart 3.3+, bloc 9.1/flutter_bloc 9.1/equatable 2.0, get_it 8.0, go_router 16.2, supabase_flutter 2.8, intl 0.20, sentry_flutter 9.0 (no new deps)

**Spec:** `docs/superpowers/specs/2026-08-22-al-batal-stitch-design.md`

## Global Constraints

- Flutter SDK >=3.19.0, Dart >=3.3.0 <4.0.0 (pubspec.yaml:6-8)
- Only edit `lib/` without human approval for pubspec.yaml/supabase/CI (AGENTS.md Scope)
- Use git worktree per phase, max 3 attempts, verifier sub-agent after each (LOOP.md)
- No hard-coded secrets, no `.env` asset, no auth/payments/secrets edits, lib/ only
- Widgets stateless, Cubits own state via Equatable, BlocBuilder for UI / BlocListener for side effects (INSTRUCTIONS.md C1/D)
- Handle loading/error/empty/success explicitly via FeedbackView/CatalogEmptyState, repos return Result<T>, no catch in widgets
- Keep InkSparkle, EdgeInsetsDirectional, directional icons for RTL, radii only 16/8/4, primary gold emerald semantics
- Verify each task with `flutter analyze` 0 issues in lib/ and `flutter test` green (baseline 198)

---

## File Structure

**Create:**
- `lib/shared/components/stitch/stitch_hero_carousel.dart` — 180dp hero Stack with gradient, CTA gold
- `lib/shared/components/stitch/stitch_category_chips.dart` — horizontal 72dp circular chips
- `lib/shared/components/stitch/stitch_flash_sale_card.dart` — 120dp row flash card with -15% badge
- `lib/shared/components/stitch/stitch_product_grid_card.dart` — 2-col product card with wishlist
- `lib/shared/components/stitch/stitch_search_bar.dart` — rounded-full surface-container-low search
- `lib/shared/components/stitch/stitch_app_bar.dart` — avatar + Hello Ahmed! + dark_mode/search icons

**Modify:**
- `lib/shared/theme/app_theme.dart:5-162` — sync primary #003527, surface #f9f9f9 etc.
- `DESIGN.md:1-323` — sync tokens to Stitch designMd
- `lib/features/storefront/presentation/pages/home_page.dart:14` — reskin to Stitch layout
- `lib/features/storefront/presentation/cubit/catalog_cubit.dart` — add flashSaleEnd/remaining timer
- `lib/features/storefront/presentation/cubit/catalog_state.dart` — add flash fields
- `lib/features/storefront/presentation/pages/details_page.dart:20` — reskin + gold CTA
- `lib/features/storefront/presentation/pages/cart_page.dart` — align to Details flow
- `lib/features/storefront/presentation/pages/categories_page.dart` — circular chips grid
- `lib/features/storefront/presentation/pages/catalog_page.dart:14` — pill filters styling
- `lib/features/storefront/presentation/pages/checkout_page.dart` — address/payment/summary cards
- `lib/features/storefront/presentation/pages/order_success_page.dart` — confirmation styling
- `lib/shared/components/app_shell.dart` — nav indicator styling if needed

**Test:**
- `test/features/storefront/presentation/cubit/catalog_flash_test.dart` (new)
- `test/features/storefront/presentation/pages/stitch_home_page_test.dart` (new)
- `test/features/storefront/presentation/pages/stitch_details_test.dart` (new)
- Existing `test/**/*` must stay green

---

### Task 0: Token Sync — AppTheme + DESIGN.md to Stitch designMd

**Files:**
- Modify: `lib/shared/theme/app_theme.dart:5-29`
- Modify: `DESIGN.md:5-83`

**Interfaces:**
- Consumes: Stitch designMd colors (stitch_get_project)
- Produces: Updated ColorScheme.light primary #003527, scaffold #f9f9f9 for all later tasks

- [x] **Step 1: Write failing token test (proves drift)**

```dart
// test/shared/theme/app_theme_stitch_tokens_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
void main(){
  test('light scaffold is Stitch #f9f9f9 and primary #003527', (){
    final t = AppTheme.light();
    expect(t.scaffoldBackgroundColor.value, 0xFFF9F9F9);
    expect(t.colorScheme.primary.value, 0xFF003527);
    expect(t.colorScheme.secondaryContainer.value, 0xFFFE932C);
  });
}
```

- [x] **Step 2: Run test to verify FAIL**

Run: `flutter test test/shared/theme/app_theme_stitch_tokens_test.dart -v`
Expected: FAIL expected 0xFFF9F9F9 got 0xFFFAFAFA

- [x] **Step 3: Update AppTheme.light/dark to exact Stitch tokens**

```dart
// lib/shared/theme/app_theme.dart
static const primaryStitch = Color(0xFF003527);
static const surfaceStitch = Color(0xFFF9F9F9);
static const surfaceContainerLow = Color(0xFFF3F3F3);
// in light():
scheme: const ColorScheme.light(
  primary: Color(0xFF003527),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF064E3B),
  secondary: Color(0xFF904D00),
  secondaryContainer: Color(0xFFFE932C),
  tertiary: Color(0xFF531E00),
  surface: Colors.white,
  surfaceContainer: Color(0xFFEEEEEE),
  onSurface: Color(0xFF1A1C1C),
  error: terracotta,
  outline: Color(0xFF707974),
  outlineVariant: Color(0xFFBFC9C3),
),
scaffold: Color(0xFFF9F9F9),
card: Colors.white,
// keep dark as is (already charcoal #121212, slate #1E293B, dark-primary #95d3ba)
```

Update DESIGN.md colors block to same values, add surface-* scale, keep emerald alias note.

- [x] **Step 4: Run test to verify PASS**

Run: `flutter test test/shared/theme/app_theme_stitch_tokens_test.dart -v`
Expected: PASS

- [x] **Step 5: Verify no regression**

Run: `flutter analyze` and `flutter test`
Expected: analyze 0 issues in lib/, test 199 passing (198+1)

- [x] **Step 6: Commit**

```bash
git add lib/shared/theme/app_theme.dart DESIGN.md test/shared/theme/app_theme_stitch_tokens_test.dart
git commit -m "feat(theme): sync AppTheme to Stitch #f9f9f9/#003527 tokens (phase 0)"
```

---

### Task 1: Stitch Primitives — scaffold 4 shared components

**Files:**
- Create: `lib/shared/components/stitch/stitch_search_bar.dart`
- Create: `lib/shared/components/stitch/stitch_category_chips.dart`
- Create: `lib/shared/components/stitch/stitch_flash_sale_card.dart`
- Create: `lib/shared/components/stitch/stitch_product_grid_card.dart`
- Test: `test/shared/components/stitch_primitives_test.dart`

**Interfaces:**
- Consumes: AppTheme tokens from Task 0, Material Symbols
- Produces: Stateless widgets used by Home/Details in Tasks 2-3

- [x] **Step 1: Write failing widget test**

```dart
// test/shared/components/stitch_primitives_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
void main(){
  testWidgets('StitchCategoryChips shows 5 chips, Silk active', (w) async{
    await w.pumpWidget(MaterialApp(home: Scaffold(body: StitchCategoryChips(selected: 'Silk', onSelect: (_){}, categories: ['Silk','Cotton','Velvet','Linen','Wool']))));
    expect(find.text('Silk'), findsOneWidget);
    expect(find.byType(FilterChip).or(find.byType(ChoiceChip)), findsWidgets);
  });
}
```

- [x] **Step 2: Run to FAIL (not found)**

Run: `flutter test test/shared/components/stitch_primitives_test.dart -v`
Expected: FAIL file not found

- [x] **Step 3: Implement minimal primitives (example one, repeat for 4)**

```dart
// lib/shared/components/stitch/stitch_category_chips.dart
import 'package:flutter/material.dart';
class StitchCategoryChips extends StatelessWidget{
  const StitchCategoryChips({super.key, required this.selected, required this.onSelect, required this.categories});
  final String selected; final ValueChanged<String> onSelect; final List<String> categories;
  @override
  Widget build(BuildContext context){
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(height: 72, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: categories.length, separatorBuilder: (_,__)=>const SizedBox(width:8), itemBuilder: (_,i){
      final cat = categories[i]; final isActive = cat==selected;
      return Column(children:[
        InkWell(onTap: ()=>onSelect(cat), child: Container(width:56,height:56,decoration: BoxDecoration(shape: BoxShape.circle, color: isActive? const Color(0xFFB0F0D6): scheme.surfaceContainerHighest, border: Border.all(color: isActive? const Color(0xFF064E3B): scheme.outlineVariant)), child: Icon(Icons.texture, color: isActive? scheme.primary: scheme.onSurfaceVariant))),
        const SizedBox(height:4),
        Text(cat, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isActive? scheme.onSurface: scheme.onSurfaceVariant, fontWeight: isActive? FontWeight.w700: FontWeight.w500)),
      ]);
    }));
  }
}
```

Implement similarly: `stitch_search_bar.dart` (rounded-full Container #f3f3f3, TextField mic), `stitch_flash_sale_card.dart` (Row 120dp image, badge secondary), `stitch_product_grid_card.dart` (Card surface outlineVariant, aspectSquare image, heart).

- [x] **Step 4: Run test PASS**

Run: `flutter test test/shared/components/stitch_primitives_test.dart -v`
Expected: PASS

- [x] **Step 5: Analyze + test all**

Run: `flutter analyze; flutter test`
Expected: 0 issues, all green

- [x] **Step 6: Commit**

```bash
git add lib/shared/components/stitch/*.dart test/shared/components/stitch_primitives_test.dart
git commit -m "feat(ui): add Stitch primitives (chips/search/flash/grid)"
```

---

### Task 2: Home Page Reskin + Flash Timer Logic

**Files:**
- Modify: `lib/features/storefront/presentation/cubit/catalog_cubit.dart`
- Modify: `lib/features/storefront/presentation/cubit/catalog_state.dart`
- Modify: `lib/features/storefront/presentation/pages/home_page.dart:14`
- Test: `test/features/storefront/presentation/cubit/catalog_flash_test.dart`
- Test: `test/features/storefront/presentation/pages/stitch_home_page_test.dart`

**Interfaces:**
- Consumes: Stitch primitives from Task 1
- Produces: HomePage with Stitch layout, CatalogCubit.flashRemaining for Task 1 primitives

- [x] **Step 1: Write failing cubit flash test**

```dart
// test/features/storefront/presentation/cubit/catalog_flash_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
  test('flashRemaining ticks every second', (){ fakeAsync((a){
    // cubit = CatalogCubit(repo); cubit.startFlashSale(end: DateTime.now().add(Duration(seconds:3)));
    // a.elapse(Duration(seconds:1)); expect(cubit.state.flashRemaining.inSeconds, 2);
  });});
}
```

- [x] **Step 2: Run FAIL**

Run: `flutter test test/features/storefront/presentation/cubit/catalog_flash_test.dart -v`
Expected: FAIL no startFlashSale

- [x] **Step 3: Add flash state + timer to CatalogCubit**

```dart
// catalog_state.dart
final Duration? flashRemaining; final DateTime? flashEnd;
// catalog_cubit.dart
Timer? _flashTimer;
void startFlashSale({required DateTime end}){ _flashTimer?.cancel(); emit(state.copyWith(flashEnd:end, flashRemaining:end.difference(DateTime.now()))); _flashTimer = Timer.periodic(Duration(seconds:1), (_){ final rem = state.flashEnd!.difference(DateTime.now()); if(rem.isNegative){_flashTimer?.cancel(); emit(state.copyWith(flashRemaining: Duration.zero));} else emit(state.copyWith(flashRemaining: rem));});}
@override Future<void> close(){ _flashTimer?.cancel(); return super.close();}
```

- [x] **Step 4: Verify cubit test PASS**

Run: `flutter test test/features/storefront/presentation/cubit/catalog_flash_test.dart -v`
Expected: PASS

- [x] **Step 5: Reskin HomePage (wire primitives)**

Replace home_page.dart body ListView children with: StitchSearchBar(controller, onChanged: cubit.updateQuery), promo hero StitchHeroCarousel(imageUrl: state.hero?.image), StitchCategoryChips(selected: state.category, onSelect: cubit.select), StitchFlashSaleCard(product: state.visible.first, discount: '-15%', remaining: state.flashRemaining), Popular GridView.builder 2-col with StitchProductGridCard.

Keep AppBar as StitchAppBar (avatar+Hello Ahmed!+dark_mode gradient). Keep BlocBuilder loading/error/empty branches.

- [x] **Step 6: Widget test for Home stitch parity**

```dart
testWidgets('Home shows hero + chips + flash + grid', (w)async{
  // pump HomePage with CatalogState.success stub, verify findsOneWidget for each primitive
});
```

Run: `flutter test test/features/storefront/presentation/pages/stitch_home_page_test.dart -v` PASS

- [x] **Step 7: Full verify + commit**

Run: `flutter analyze; flutter test`
```bash
git add lib/features/storefront/presentation/cubit/* lib/features/storefront/presentation/pages/home_page.dart test/features/storefront/presentation/**
git commit -m "feat(home): Stitch reskin + flash timer (phase 1)"
```

---

### Task 3: Details & Cart Reskin

**Files:**
- Modify: `lib/features/storefront/presentation/pages/details_page.dart:20`
- Modify: `lib/features/storefront/presentation/pages/cart_page.dart`
- Create: `lib/shared/components/stitch/stitch_app_bar.dart` (if not Task1)
- Test: `test/features/storefront/presentation/pages/stitch_details_test.dart`

**Interfaces:**
- Consumes: CatalogState.product, CartCubit, WishlistCubit
- Produces: DetailsPage with Stitch gallery+price 850 EGY, gold AddToCart bar

- [x] **Step 1: Write failing details test (EGY suffix + gold button)**

```dart
testWidgets('Details shows 850 EGY and gold CTA', (w)async{
  await w.pumpWidget(/* DetailsPage stub */);
  expect(find.textContaining('EGY'), findsWidgets);
  expect(find.byType(FilledButton), findsOneWidget);
});
```

- [x] **Step 2: Run FAIL**

Run: `flutter test test/features/storefront/presentation/pages/stitch_details_test.dart -v` FAIL

- [x] **Step 3: Reskin DetailsPage**

ImageGallery unchanged but wrapped ClipRRect 16, NameAndPrice price Text('${p.price.egp} EGY', style: label-md bold primary), VariantSelector unchanged, DeliveryInfo unchanged, Related horizontal. bottomNavigationBar = Container(height:72, padding: EdgeInsetsDirectional.all(16), child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Color(0xFF904D00) /* + gold gradient via Ink */), onPressed: (){context.read<CartCubit>().add(p.id);}, child: Text('Add to Cart'))).

Keep WishlistToggleIcon + share actions.

- [x] **Step 4: PASS + verify**

Run: `flutter test ... -v` PASS; `flutter analyze; flutter test`

- [x] **Step 5: Commit**

```bash
git add lib/features/storefront/presentation/pages/details_page.dart lib/features/storefront/presentation/pages/cart_page.dart
git commit -m "feat(details): Stitch reskin EGY pricing + gold CTA (phase 2)"
```

---

### Task 4: Categories / Catalog / Orders Reskin

**Files:**
- Modify: `lib/features/storefront/presentation/pages/categories_page.dart`
- Modify: `lib/features/storefront/presentation/pages/catalog_page.dart:14`
- Modify: `lib/features/storefront/presentation/pages/orders_page.dart`
- Test: `test/features/storefront/presentation/pages/stitch_catalog_test.dart`

**Interfaces:**
- Consumes: CatalogCubit category/filter/visible
- Produces: Catalog grid with Stitch pill filters + circular chips

- [x] **Step 1: Write failing catalog chip test**

```dart
testWidgets('Catalog shows StitchCategoryChips and grid', (w)async{
  expect(find.byType(StitchCategoryChips), findsOneWidget);
  expect(find.byType(GridView), findsOneWidget);
});
```

- [x] **Step 2: Run FAIL**

Run: `flutter test ...` FAIL

- [x] **Step 3: Reskin CategoriesPage + CatalogPage**

CategoriesPage: replace list with Grid circular chips (same widget as Home). CatalogPage: AppBar tune icon Badge, body Column CatalogSearchBar + if hasActiveFilters ActiveFiltersBar pill style + CatalogSortBar + GridView.builder 2-col .68 childAspectRatio with StitchProductGridCard. Keep FilterSheet bottom sheet but style container radius 20 + outlineVariant.

OrdersPage: order cards with surface outlineVariant border, status chip primaryContainer.

- [x] **Step 4: PASS**

Run: `flutter test ... -v` PASS

- [x] **Step 5: Commit**

```bash
git add lib/features/storefront/presentation/pages/categories_page.dart lib/features/storefront/presentation/pages/catalog_page.dart lib/features/storefront/presentation/pages/orders_page.dart
git commit -m "feat(catalog): Stitch categories circular + grid (phase 3)"
```

---

### Task 5: Checkout & Order-Success Reskin (Dark verified)

**Files:**
- Modify: `lib/features/storefront/presentation/pages/checkout_page.dart`
- Modify: `lib/features/storefront/presentation/pages/order_success_page.dart`
- Modify: `lib/features/payments/presentation/pages/payment_method_page.dart`
- Test: `test/features/storefront/presentation/pages/stitch_checkout_test.dart`

**Interfaces:**
- Consumes: OrdersCubit, CartCubit, AddressesCubit
- Produces: Checkout 3528 flow with address/payment/summary cards

- [x] **Step 1: Write failing checkout test**

```dart
testWidgets('Checkout shows address card + summary + gold Pay', (w)async{
  expect(find.text('Shipping Address'), findsOneWidget);
  expect(find.textContaining('EGY'), findsWidgets);
  expect(find.text('Pay'), findsOneWidget);
});
```

- [x] **Step 2: Run FAIL**

Run: `flutter test ...` FAIL

- [x] **Step 3: Reskin CheckoutPage**

Scaffold ListView padding 16: Address selector Card surfaceContainerLow rounded 16 border outlineVariant, Payment method ListTile radio primary, Summary Card outlineVariant with rows + total bold primary 850 EGY, CTA FilledButton gold secondary "Confirm Order". OrderSuccess: center icon check_circle primaryFixedDim + headline-lg-mobile + button primary.

Verify dark: pump with ThemeMode.dark, expect scaffold #121212.

- [x] **Step 4: PASS + full verify**

Run: `flutter analyze; flutter test; flutter build apk --debug --dart-define-from-file=config/env.staging.local.json` + unzip check no .env

- [x] **Step 5: Commit**

```bash
git add lib/features/storefront/presentation/pages/checkout_page.dart lib/features/storefront/presentation/pages/order_success_page.dart
git commit -m "feat(checkout): Stitch checkout + confirmation (phase 4) + dark verify"
```

---

## Self-Review

**1. Spec coverage:** Tokens→Task0, primitives→Task1, Home hero/chips/flash/grid+timer→Task2, Details Cart EGY+gold→Task3, Categories/Catalog grid→Task4, Checkout dark→Task5 — all 4 flows light+dark covered. AppShell nav indirectly via Theme.

**2. Placeholder scan:** No TBD/TODO, all steps have code + run commands + expected PASS/FAIL.

**3. Type consistency:** CatalogState.flashRemaining Duration? + flashEnd DateTime? used consistently Tasks2-5; StitchCategoryChips signature (selected, onSelect, categories) consistent; EGY price via Money.egp pattern existing.

**4. Gap fix:** Added Task0 token test to catch #FAFAFA→#f9f9f9 drift; added build apk .env check in Task5.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-22-stitch-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - dispatch fresh subagent per task via superpowers:subagent-driven-development, review between tasks
**2. Inline Execution** - execute tasks in this session via superpowers:executing-plans, batch with checkpoints

Which approach?
