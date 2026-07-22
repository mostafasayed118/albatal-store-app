---
kind: configuration_system
name: Flutter dotenv-based environment configuration
category: configuration_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - .env.example
    - lib/shared/services/supabase_config.dart
    - lib/shared/services/env_config.dart
    - lib/main.dart
---

The app uses a minimal, file-driven configuration system built on flutter_dotenv with no runtime feature flags or remote config. Configuration is loaded from a .env file at the project root and consumed through two static service classes.

How it works:
- pubspec.yaml declares flutter_dotenv: ^5.2.1 and registers .env under flutter.assets, so the file is bundled into every build.
- lib/shared/services/supabase_config.dart::initialize() calls dotenv.load() once in main(), reads SUPABASE_URL and SUPABASE_ANON_KEY, throws an AssertionError if either is missing, then initializes Supabase.initialize(url, publishableKey).
- lib/shared/services/env_config.dart::EnvConfig exposes read-only getters for the same two values plus environment (development vs production) derived from kDebugMode, and a validate() helper that returns a list of missing keys.
- lib/main.dart wraps Supabase + DI bootstrap in a try/catch; on failure it renders _BootstrapErrorApp instead of a red framework crash screen.

Security boundary:
- Payment provider secrets (PAYMOB_API_KEY, PAYMOB_INTEGRATION_ID, PAYMOB_HMAC_SECRET, VODAFONE_CASH_MERCHANT_CODE, VODAFONE_CASH_API_KEY) are explicitly documented as Edge Function-only variables and must never be exposed via EnvConfig. The test suite enforces this contract.

What is not present:
- No per-environment .env.dev / .env.prod files — environment selection is purely kDebugMode.
- No remote/feature-flag service, no JSON/YAML/TOML config loader, no dart:io Platform.environment usage for app config.
- Platform-specific native configs (Android gradle.properties, iOS xcconfig, macOS Configs/*.xcconfig) exist but are not wired into the Dart layer by this codebase.

Conventions developers should follow:
- Put new client-visible settings only in EnvConfig; keep secrets out of the Flutter bundle.
- Add required keys to .env.example whenever a new one is introduced.
- Call SupabaseConfig.initialize() before runApp and rely on the existing try/catch fallback rather than adding another init path.