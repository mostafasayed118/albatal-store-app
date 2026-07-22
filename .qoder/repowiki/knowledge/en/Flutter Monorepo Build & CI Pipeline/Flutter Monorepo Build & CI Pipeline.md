---
kind: build_system
name: Flutter Monorepo Build & CI Pipeline
category: build_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - .github/workflows/ci.yml
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - android/gradle.properties
    - scripts/deploy-staging.sh
    - analysis_options.yaml
---

This repository is a single Flutter application built with the standard Flutter toolchain. The build system centers on pubspec.yaml for Dart/Flutter dependency and asset management, Gradle Kotlin DSL for Android packaging, and GitHub Actions for continuous integration. There are no Makefiles, Dockerfiles, or custom build orchestrators — everything flows through Flutter's native commands.

Dependency and versioning
- pubspec.yaml pins SDK constraints (flutter >=3.19.0, Dart >=3.3.0 <4.0.0) and declares runtime dependencies (bloc, supabase_flutter, go_router, etc.) plus dev dependencies (bloc_test, mocktail, flutter_lints). Version is 0.1.0+1.
- Android Gradle (android/app/build.gradle.kts) reads flutter.versionCode / flutter.versionName so app versioning stays in sync with pubspec. Java/Kotlin target JVM 17; gradle.properties allocates 8 GB heap to avoid OOM during builds.

Android build
- Top-level android/build.gradle.kts redirects all Gradle output into the repo root build/ directory via rootProject.layout.buildDirectory, keeping generated artifacts out of per-module .gradle/ trees.
- android/app/build.gradle.kts applies the Flutter Gradle plugin after the Android/Kotlin plugins, uses compileSdk/ndkVersion from the Flutter toolchain, and currently signs release builds with debug keys (a TODO).

CI pipeline (GitHub Actions)
- .github/workflows/ci.yml defines three jobs running on ubuntu-latest:
  - analyze-and-test: checks out code, sets up Flutter 3.24.x stable, runs dart format --set-exit-if-changed ., flutter analyze --no-pub, and flutter test --no-pub.
  - secret-scan: rejects tracked .env files (except .env.example) and scans source for Paymob/Supabase secret patterns using ripgrep.
  - deploy-check: enforces that deprecated Supabase functions (paymob-order, paymob-auth, paymob-payment-key, vodafone-cash-payment, vodafone-cash-verify) are removed and that active functions (checkout, paymob-initiate, paymob-callback, cancel-expired-orders, send-order-notification) exist, then verifies migration files are present.
- Triggers on push to main/develop and PRs against main.

Staging deployment
- scripts/deploy-staging.sh (with .bat/.ps1 aliases) drives Supabase CLI: links to a project, pushes migrations in filename order, deploys only the whitelisted active Edge Functions, and prints the required secrets to set manually. It explicitly documents which functions were removed for security reasons.
- Migration SQL lives under supabase/migrations/ and is applied sequentially by glob order.

Static analysis and linting
- analysis_options.yaml extends package:flutter_lints/flutter.yaml and adds prefer_single_quotes: true. Linting runs both locally via flutter analyze and in CI as a gate.

Conventions developers should follow
- Keep Flutter/Dart versions within the constraints declared in pubspec.yaml; CI will fail otherwise.
- Do not commit any .env file other than .env.example — the secret-scan job will block the build.
- When adding Supabase Edge Functions, update both scripts/deploy-staging.sh and .github/workflows/ci.yml deploy-check to include the new function name in the active list.
- Remove old/insecure functions from supabase/functions/ rather than leaving them undeleted; the CI deploy-check validates this.
- Place database changes as new numbered SQL files under supabase/migrations/; they are applied in lexicographic order by the staging script.