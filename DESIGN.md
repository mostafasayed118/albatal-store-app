---
version: alpha
name: Al Batal Elite — Design System
description: A tactile, textile-inspired design language for a premium fabric-commerce Flutter app. Emerald/Gold light mode and an intentional Charcoal/Slate dark mode, Montserrat display headings paired with Inter body, and rounded tactile surfaces that read like fine cloth.
colors:
  emerald: "#064E3B"
  gold: "#D97706"
  off-white: "#FAFAFA"
  charcoal: "#121212"
  slate: "#1E293B"
  terracotta: "#BA1A1A"
  light-surface: "#FFFFFF"
  light-on-surface: "#17201C"
  light-outline: "#B7C1BB"
  dark-primary: "#95D3BA"
  dark-on-primary: "#002117"
  dark-secondary: "#FFB77D"
  dark-on-secondary: "#2F1500"
  dark-on-surface: "#F0F4F1"
  dark-outline: "#BFC9C3"
  dark-error: "#FFB4AB"

typography:
  display-lg:
    fontFamily: "Montserrat, sans-serif"
    fontSize: 48px
    fontWeight: 700
    lineHeight: 1.17
    letterSpacing: -0.96px
  headline-lg:
    fontFamily: "Montserrat, sans-serif"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: -0.64px
  headline-md:
    fontFamily: "Montserrat, sans-serif"
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: -0.32px
  title-lg:
    fontFamily: "Montserrat, sans-serif"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: -0.2px
  title-md:
    fontFamily: "Montserrat, sans-serif"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: 0
  body-lg:
    fontFamily: "Inter Variable, Inter, sans-serif"
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.56
    letterSpacing: 0
  body-md:
    fontFamily: "Inter Variable, Inter, sans-serif"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0
  label-lg:
    fontFamily: "Inter Variable, Inter, sans-serif"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.43
    letterSpacing: 0.14px
  label-sm:
    fontFamily: "Inter Variable, Inter, sans-serif"
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.33
    letterSpacing: 0.6px

rounded:
  control: 8px
  card: 16px
  chip: 4px

spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px

components:
  button-primary:
    backgroundColor: "{colors.emerald}"
    textColor: "#FFFFFF"
    typography: "{typography.label-lg}"
    rounded: "{rounded.control}"
    height: 50px
  button-accent:
    backgroundColor: "{colors.gold}"
    textColor: "#FFFFFF"
    typography: "{typography.label-lg}"
    rounded: "{rounded.control}"
    height: 50px
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.emerald}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.control}"
    height: 50px
    border: 1.25px {colors.emerald}
  card-surface:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-on-surface}"
    rounded: "{rounded.card}"
    padding: 12px
  input-field:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.control}"
    padding: 14px 16px
  bottom-nav:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.emerald}"
    typography: "{typography.label-sm}"
    height: 72px
  chip-tag:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.emerald}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.chip}"
---

## Overview

Al Batal Elite is a premium fabric-commerce foundation with a tactile, textile-inspired visual language. The system runs two intentional appearance modes that never blur: a warm **Emerald / Gold light mode** and a deliberate **Charcoal / Slate dark mode**. Both are built on Material 3 with a restrained, luxurious palette and rounded surfaces that feel like finely finished cloth.

Typography splits across two families. **Montserrat** — set at semibold (600) and bold (700) with tight negative tracking — carries every display, headline, and title; it is the brand's confident, editorial voice. **Inter** handles all body, label, and form text with calm, readable rhythm. Negative letter-spacing on Montserrat headings gives the large sizes a custom, premium tightness without sacrificing legibility.

**Key Characteristics:**
- Two intentional themes: `{colors.emerald}` primary + `{colors.gold}` secondary on `{colors.off-white}` light canvas; softened `{colors.dark-primary}` / `{colors.dark-secondary}` on a `{colors.charcoal}` / `{colors.slate}` dark canvas. The dark mode is a separate, hand-tuned palette — not a simple inversion.
- Montserrat for all headings (display → title), Inter for all body and labels. Never swap the two roles.
- Rounded tactile surfaces: `{rounded.card}` 16px cards, `{rounded.control}` 8px controls and inputs, `{rounded.chip}` 4px chips. Radius is a brand signature — flat/sharp corners do not exist.
- Subtle, primary-tinted shadows only: cards float with a faint `{colors.emerald}` halo (3%–12% alpha) rather than hard drop shadows.
- InkSparkle splash on taps — a small, luxurious interaction detail that reinforces the tactile feel.

## Colors

> **Source:** `lib/shared/theme/app_theme.dart`.

### Brand & Accent
- **Emerald** (`{colors.emerald}` — `#064E3B`): The primary brand color — deep, botanical, premium. Used for primary buttons, navbar indicators, focus rings, and the light-mode surface tint.
- **Gold** (`{colors.gold}` — `#D97706`): The secondary accent — warm, artisanal, fabric-market energy. Used for accent buttons, prices, and highlighted values.
- **Terracotta** (`{colors.terracotta}` — `#BA1A1A`): The error / destructive color — used for "Remove" actions, validation failures, and the delete affordance. In dark mode this softens to `{colors.dark-error}` (`#FFB4AB`).

### Light Mode Surface
- **Off-White** (`{colors.off-white}` — `#FAFAFA`): The scaffold background — a whisper warmer than pure white.
- **Surface White** (`{colors.light-surface}` — `#FFFFFF`): Cards, inputs, navbar, and chips sit on pure white for quiet contrast against the off-white canvas.
- **On-Surface** (`{colors.light-on-surface}` — `#17201C`): Near-black green-tinted text on light.
- **Outline** (`{colors.light-outline}` — `#B7C1BB`): Hairline borders, dividers, unfocused input edges.

### Dark Mode Surface
- **Charcoal** (`{colors.charcoal}` — `#121212`): The dark scaffold background.
- **Slate** (`{colors.slate}` — `#1E293B`): Dark cards and navbar — a cool slate that separates from the charcoal canvas.
- **Dark Primary** (`{colors.dark-primary}` — `#95D3BA`): The lightened emerald used as the primary action color on dark.
- **Dark On-Primary** (`{colors.dark-on-primary}` — `#002117`): Text on the dark primary fill.
- **Dark Secondary** (`{colors.dark-secondary}` — `#FFB77D`): The lightened gold for dark-mode accents.
- **Dark On-Surface** (`{colors.dark-on-surface}` — `#F0F4F1`): Soft near-white text on dark.
- **Dark Outline** (`{colors.dark-outline}` — `#BFC9C3`): Hairlines on dark.

## Typography

### Font Family
The heading tier is **Montserrat** at 600–700 with negative tracking. The body tier is **Inter Variable** at 400 with `fontFamilyFallback: ['sans-serif']` so it degrades gracefully when the font files are absent. The app ships both families as variable fonts under `assets/fonts/` and declares them in `pubspec.yaml`.

### Hierarchy

| Token | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|
| `{typography.display-lg}` | 48px | 700 | 1.17 | -0.96px | Hero / page display headline |
| `{typography.headline-lg}` | 32px | 700 | 1.25 | -0.64px | Major section opener |
| `{typography.headline-md}` | 24px | 700 | 1.33 | -0.32px | Sub-section / product title |
| `{typography.title-lg}` | 20px | 600 | 1.4 | -0.2px | Card title, app bar title |
| `{typography.title-md}` | 16px | 600 | 1.5 | 0 | Compact title, list label |
| `{typography.body-lg}` | 18px | 400 | 1.56 | 0 | Lead body, large reading copy |
| `{typography.body-md}` | 16px | 400 | 1.5 | 0 | Default body, input text |
| `{typography.label-lg}` | 14px | 600 | 1.43 | 0.14px | Button labels, emphasized caption |
| `{typography.label-sm}` | 12px | 600 | 1.33 | 0.6px | Nav labels, chips, eyebrows |

### Principles
- **Montserrat for structure, Inter for reading.** Headings stay in Montserrat; body and labels stay in Inter.
- **Tight tracking on Montserrat.** Display (-0.96px) through title (-0.2px) is always negative; it is the brand's premium tightness. Labels stay positive/neutral.
- **Weight discipline.** Headings use 600–700 only; body uses 400; labels use 600. No other weights.

## Layout

### Spacing System
- **Base unit**: 4px. Tokens: `{spacing.xs}` 4px · `{spacing.sm}` 8px · `{spacing.md}` 12px · `{spacing.lg}` 16px · `{spacing.xl}` 24px · `{spacing.xxl}` 32px.
- **Screen padding**: `{spacing.lg}` 16px default body inset (see `CartPage` list padding).
- **Card padding**: `{spacing.md}` 12px inner padding on product/cart cards.
- **Button height**: 50px minimum — comfortably above the 44px touch-target floor.

### Grid & Container
- Scaffold-driven, single-column mobile-first layout. Content uses `EdgeInsetsDirectional` so RTL (Arabic) mirrors correctly without extra logic.
- `NavigationBar` height `{bottom-nav}` 72px, fixed to the bottom of every shell screen (`AppShell`).
- Bottom-nav destinations: Home, Categories, Cart (with item-count `Badge`), Wishlist, Profile.

### Whitespace Philosophy
Generous but grounded. The off-white canvas and white cards create soft separation, so spacing stays calm (16–24px) rather than sparse. Negative space reads as "premium restraint," not emptiness.

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| 0 | Flat, `elevation: 0` | Default cards, navigation bar (Material 3 default) |
| 1 | `BoxShadow(color: primary.withAlpha(0.035 light / 0.12 dark), blurRadius: 8, offset: (0, 3))` | Subtle card float — the only shadow in the system |

### Decorative Depth
Depth is intentionally minimal and tinted with the brand primary. Cards do not use hard shadows; they float on a faint emerald halo. The dark mode uses the same shadow at higher alpha for visibility against charcoal.

## Shapes

### Border Radius Scale

| Token | Value | Use |
|---|---|---|
| `{rounded.control}` | 8px | Buttons, inputs, outlined fields, FABs |
| `{rounded.card}` | 16px | Product cards, summary cards, dialogs |
| `{rounded.chip}` | 4px | Chips, tags, badges |

## Components

### Buttons
Three styles via `AppButton` (`AppButtonStyle`): `primary`, `accent`, `outline`.

**`button-primary`** — the dominant CTA.
- Background `{colors.emerald}`, text `#FFFFFF`, type `{typography.label-lg}`, height 50px, rounded `{rounded.control}`.

**`button-accent`** — secondary/specialist CTA (e.g. promotions).
- Background `{colors.gold}`, text `#FFFFFF`, otherwise same geometry as primary.

**`button-outline`** — low-emphasis / tertiary action.
- Transparent background, `{colors.emerald}` text, 1.25px `{colors.emerald}` border, same geometry.

All buttons optionally take a trailing `icon` rendered 8px after the label.

### Cards & Containers

**`card-surface`** — default content card.
- Background `{colors.light-surface}` (dark: `{colors.slate}`), text `{colors.light-on-surface}` (dark: `{colors.dark-on-surface}`), rounded `{rounded.card}` 16px, `elevation: 0`, subtle primary halo shadow, padding `{spacing.md}` 12px.

See `CartPage` for the canonical usage: a 72×72 color swatch (fabric placeholder) on the left, product name in `titleSmall`, then color · length · price, quantity steppers, and a terracotta "Remove" `TextButton`.

### Inputs & Forms

**`input-field`** — text input.
- Background `{colors.light-surface}`, text `{colors.light-on-surface}`, type `{typography.body-md}`, padding 14px 16px, rounded `{rounded.control}`, filled, no border by default; focused border is 1.5px `{colors.emerald}`. Hint color is on-surface at 55% alpha.

### Navigation

**`bottom-nav`** — `AppShell` navigation bar.
- Background `{colors.light-surface}` (dark: `{colors.slate}`), height 72px, `elevation: 0`. Active destination uses an indicator of `{colors.emerald}` at 12% alpha; labels in `{typography.label-sm}`. Icons are Material directional (outlined → filled on selection) so RTL flips correctly.

### Chips, Tags, and Badges

**`chip-tag`** — small filter / category chip.
- Background `{colors.light-surface}`, text `{colors.emerald}`, type `{typography.label-sm}`, rounded `{rounded.chip}` 4px.
- The cart badge shows the item count only when `count > 0`.

### Signature Components
- **Fabric swatch thumbnail**: a 72×72 solid `{Color(imageColor)}` block with a centered `Icons.texture` (white) standing in for product photography until real imagery lands.
- **InkSparkle splash**: every tap uses `InkSparkle.splashFactory` — a tactile, cloth-like ripple that reinforces the premium feel.
- **Direction-safe layouts**: all insets use `EdgeInsetsDirectional` and all icons are Material directional, so English and Arabic (RTL) render mirrored without branching.

## Do's and Don'ts

### Do
- Use `{colors.emerald}` as the primary action color and `{colors.gold}` as the warm secondary/accent.
- Keep headings in Montserrat with negative tracking; keep body and labels in Inter.
- Round everything: `{rounded.card}` 16px for cards, `{rounded.control}` 8px for controls, `{rounded.chip}` 4px for chips.
- Use the faint primary-tinted shadow (Level 1) for card float; never hard/black drop shadows.
- Respect RTL: use `EdgeInsetsDirectional` and Material directional icons.
- Reserve `{colors.terracotta}` for destructive actions only ("Remove", delete, errors).

### Don't
- Don't invert the dark palette mechanically — dark mode uses hand-tuned `{colors.dark-primary}` / `{colors.dark-secondary}` on `{colors.charcoal}` / `{colors.slate}`, not a literal color flip.
- Don't put body text in Montserrat or headings in Inter.
- Don't use sharp corners or radii outside the three defined tokens.
- Don't add heavy elevation; cards float on a subtle halo, not a stack of shadows.
- Don't use terracotta for non-destructive emphasis.

## Responsive Behavior

### Breakpoints
This is a mobile-first Flutter app. Layout is single-column and scales fluidly; no fixed desktop grid is defined yet.

| Name | Width | Key Changes |
|---|---|---|
| Phone | < 600px | Default single-column, bottom nav, 16px screen padding |
| Tablet | ≥ 600px | Same components; more whitespace, wider reading column |
| Desktop | ≥ 1200px | Unconstrained; shell and components scale, no separate layout |

### Touch Targets
- Buttons and inputs are 50px tall (≥ 44px floor). Icon steppers in the cart use `IconButton` (default 48px hit area).

### Collapsing Strategy
- Navigation stays a bottom `NavigationBar` across all sizes (no hamburger).
- Lists (cart, catalog) scroll vertically; no horizontal paging yet.
- Display type does not drop below `{typography.headline-md}` (24px) on small screens.

### Localization
- English and Arabic via Flutter generated `l10n`. The `ar` locale drives RTL automatically; all layout uses directional insets/icons, so no per-language branching is needed.

## Iteration Guide

1. Focus on ONE component at a time.
2. Reference tokens directly: `{colors.emerald}`, `{rounded.card}`, `{typography.title-lg}`.
3. Add new variants as separate entries under `components:`.
4. Default body to `{typography.body-md}`; use `{typography.body-lg}` for leads.
5. Keep the two themes separate — design for light OR dark, never a blended surface.
6. When adding a button, pick `primary` / `accent` / `outline` from `AppButton` — do not invent a new shape.
7. Keep radius within the three tokens; keep shadows to the single primary-tinted Level 1.
