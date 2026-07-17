# Foundation Learning Walkthrough

## Problem and approach
A commerce application needs an appearance and locale choice before feature screens multiply. Retrofitting dark mode or RTL after catalog and checkout are built produces pervasive layout fixes and inconsistent tokens. This slice creates one theme source, a persisted settings feature, and localization generation before those feature flows exist.

A single `SettingsCubit` owns user-visible settings state. Its repository contract keeps storage out of widgets and Cubit. This is deliberately a small Clean Architecture example with a real boundary, not a folder hierarchy added for ceremony.

## Files and ownership
- `app.dart`: app composition; observes settings and configures `MaterialApp.router`.
- `shared/theme/app_theme.dart`: all Material theme tokens and component defaults.
- `features/settings/domain/...`: contract and domain value for persisted settings.
- `features/settings/data/...`: `SharedPreferences` implementation and error translation.
- `features/settings/presentation/...`: Cubit, immutable state, and settings UI.
- `l10n/*.arb`: translated user-facing strings only.
- `shared/routing/app_router.dart`: route ownership and navigation shell.

## Tests
The Cubit test covers successful hydration and a save failure. The widget test asserts that an Arabic subtree has RTL directionality. It does not attempt to test Flutter framework behavior or pixel-match the design.

## Limitations
- No platform folders or test run were possible in this environment.
- Font files are not bundled; fallbacks apply until they are added locally.
- Persistence initialization is required before `runApp`; a later production hardening slice can add a controlled startup failure screen.
- Sentry is intentionally deferred: adding the SDK before a DSN, release strategy, and PII policy would be configuration without operational value.

## Self-check
1. Why does `SettingsCubit` depend on `SettingsRepository` instead of `SharedPreferences`?
2. Where are persistence errors converted into app-level errors, and why there?
3. What makes `EdgeInsetsDirectional` safer than `EdgeInsets` for this app?
4. Why is dark mode defined as its own color scheme rather than color inversion?
5. Which layer should map a future API settings payload into `AppSettings`?
