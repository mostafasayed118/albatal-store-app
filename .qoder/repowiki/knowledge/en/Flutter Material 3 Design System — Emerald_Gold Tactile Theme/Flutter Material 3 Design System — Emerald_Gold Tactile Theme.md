---
kind: frontend_style
name: Flutter Material 3 Design System — Emerald/Gold Tactile Theme
category: frontend_style
scope:
    - '**'
source_files:
    - lib/shared/theme/app_theme.dart
    - lib/app.dart
    - lib/shared/theme/grid_delegate.dart
    - DESIGN.md
    - assets/fonts/Montserrat-VariableFont_wght.ttf
    - assets/fonts/Inter-VariableFont_opsz,wght.ttf
---

The Al Batal Elite Flutter app implements a cohesive, textile-inspired visual system built on Material 3 with two hand-tuned themes (Emerald/Gold light and Charcoal/Slate dark). The entire aesthetic is centralized in a single theme factory and documented in DESIGN.md, ensuring consistency across storefront and admin surfaces.

### What system/approach is used
- Material 3 (useMaterial3: true) as the base framework for colors, typography, elevation, and component theming.
- A custom AppTheme class exposing light() / dark() factories that build ThemeData instances with brand-specific ColorScheme, text styles, button/input/card/navigation bar defaults, and a subtle primary-tinted shadow.
- Two variable fonts shipped under assets/fonts/: Montserrat for headings (display to title) with negative tracking, and Inter Variable for body/labels with sans-serif fallbacks.
- A shared productGridDelegate token standardizes the 2-column product grid spacing.

### Key files and packages
- lib/shared/theme/app_theme.dart - central theme factory, color tokens, radius constants, global text/button/input/nav bar defaults, and the signature InkSparkle splash.
- lib/app.dart - wires AppTheme.light() / AppTheme.dark() into MaterialApp.router and drives themeMode from SettingsCubit.
- lib/shared/theme/grid_delegate.dart - shared 2-column grid delegate matching design spacing tokens.
- DESIGN.md - authoritative design-system spec covering colors, typography, spacing, shapes, components, responsive behavior, and Do's/Don'ts.
- assets/fonts/ - Montserrat and Inter variable font files consumed by the theme.

### Architecture and conventions
- Single source of truth: all colors, radii, and type scales live in AppTheme; feature code never hardcodes hex values or font families.
- Two separate palettes: dark mode is not a mechanical inversion - it uses distinct dark-primary / dark-secondary / dark-on-surface tokens tuned for charcoal/slate backgrounds.
- Global component defaults: FilledButtonThemeData, OutlinedButtonThemeData, InputDecorationTheme, CardThemeData, ChipTheme, and NavigationBarThemeData are set once in _theme(), so every widget inherits consistent height (50px), radius (8px controls, 16px cards, 4px chips), and label style.
- Typography discipline: Montserrat at 600-700 with negative letter-spacing for display/headline/title; Inter at 400 for body and 600 for labels. No other weights are used.
- Elevation & depth: only one shadow level - a faint primary-tinted BoxShadow (alpha 0.035 light / 0.12 dark) applied to navigation bar; cards use elevation: 0 with transparent shadow color.
- RTL-ready: layout uses EdgeInsetsDirectional and Material directional icons throughout; Arabic locale triggers automatic mirroring via generated l10n.

### Rules developers should follow
- Pull colors/radii/type from AppTheme and DESIGN.md tokens - do not invent new hex values or font families.
- Use the three predefined radii: controlRadius (8px), cardRadius (16px), chip (4px). Flat/sharp corners are forbidden.
- Keep headings in Montserrat and body/labels in Inter; never swap roles.
- Reserve terracotta for destructive actions only; emerald is primary, gold is secondary/accent.
- Prefer the prebuilt AppButton variants (primary, accent, outline) rather than constructing buttons inline.
- Respect RTL: always use EdgeInsetsDirectional and directional Material icons.
- Dark mode must use the hand-tuned dark palette - never invert light colors mechanically.