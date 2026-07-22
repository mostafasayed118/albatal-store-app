---
kind: dependency_management
name: Flutter pub.dev Dependency Management with Human-Gated Upgrade Policy
category: dependency_management
scope:
    - '**'
source_files:
    - pubspec.yaml
    - pubspec.lock
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - skills/dependency-sweeper/SKILL.md
    - AGENTS.md
    - loop-constraints.md
    - STATE.md
---

This Flutter monorepo manages third-party dependencies exclusively through the standard Dart/Flutter toolchain — `pubspec.yaml` for declarations, `pubspec.lock` for deterministic resolution, and `flutter pub get` / `flutter pub outdated` / `dart pub audit` for lifecycle operations. There is no vendoring, private registry, or custom package source configured; all packages are resolved from the public https://pub.dev hosted repository.

Core files
- `pubspec.yaml` — single source of truth for direct dependencies (bloc, flutter_bloc, supabase_flutter, go_router, webview_flutter, etc.) and dev_dependencies (bloc_test, mocktail, flutter_lints). SDK constraints pin Dart >=3.3.0 <4.0.0 and Flutter >=3.19.0.
- `pubspec.lock` — generated lockfile that pins every transitive dependency to a specific version and sha256 checksum from https://pub.dev, ensuring reproducible builds across machines and CI.
- `android/build.gradle.kts` — declares Maven repositories (google(), mavenCentral()) used by the Android Gradle plugin; Kotlin/JVM target is pinned to JVM_17.
- `ios/Runner.xcodeproj/project.pbxproj` — references only Flutter-generated Swift packages; no CocoaPods or SPM manifests are present.

Architecture and conventions
- Single-package layout: despite being a multi-platform Flutter app (Android/iOS/Linux/macOS/Web/Windows), there is one top-level `pubspec.yaml`; platform shells do not declare their own Dart dependencies.
- Version ranges use caret (^) semantics in `pubspec.yaml`, while `pubspec.lock` captures exact versions — upgrades must be reviewed before committing the lockfile.
- No `.packages` file is committed; Flutter's internal `.dart_tool/package_config.json` is the runtime resolution cache.
- The repo contains no `pubspec_overrides.yaml`, `package_config.json`, or `packages/` vendored directory.

Human-gated upgrade policy (enforced by AI agent constraints)
- `AGENTS.md` and `loop-constraints.md` explicitly forbid modifying `pubspec.yaml` without human approval and forbid running `flutter pub upgrade` unattended.
- The `skills/dependency-sweeper/SKILL.md` codifies a weekly/bi-weekly workflow: run `flutter pub outdated` and `dart pub audit`, categorize findings as patch/minor/major/security/deprecated, report into `STATE.md` and `loop-run-log.md`, and never auto-apply changes. Major bumps require explicit human sign-off.
- `STATE.md` currently tracks 17 outdated packages and recommends suggesting `flutter pub upgrade` rather than executing it.

Rules developers should follow
1. Add new dependencies only via `pubspec.yaml`; never edit `pubspec.lock` directly.
2. After changing `pubspec.yaml`, run `flutter pub get` locally and commit both files together.
3. Before any release, run `flutter pub outdated` and `dart pub audit`; log results in `STATE.md` per the dependency-sweeper skill.
4. Major version bumps must be proposed as a separate change with a migration plan; they cannot be merged automatically.
5. Do not introduce private registries, `pubspec_overrides.yaml`, or vendored packages unless approved — the project relies on the public pub.dev ecosystem.