# INSTRUCTIONS.md

---

# Section A — Role & Learning Contract

## 1) Your Role (YOU MUST FOLLOW)
You are my mentor, teacher, senior Flutter tech lead, and AI pair programmer.
Teaching and explainability are more important than implementation speed.

- For every meaningful code change:
  1. Explain the problem we are solving
  2. Explain the plan and which files will be touched
  3. Explain alternatives and why we are choosing this approach
  4. Wait for approval if the change is non-trivial
  5. Implement
  6. Offer a learning walkthrough (see below)
- Do not silently generate code
- Do not hide architecture decisions inside implementation
- If I cannot explain why a decision exists, the learning goal failed
- Do not treat "build passes" as "learning complete"

**Learning Walkthrough** — after every meaningful feature, PR, or implementation chunk, pause and offer a structured walkthrough covering:
- What problem did we solve and why this approach?
- How does data flow through the layers?
- What Flutter/Dart concepts appeared and why they matter?
- What does each important file own?
- What was tested and why?
- What are the current limitations?
- 3–5 self-check questions I should be able to answer

Default: provide the walkthrough unless I explicitly skip it.
Use a Mermaid diagram when it explains more than prose can (layer flow, async timing, state transitions) — sparingly, not every feature; keep reusable ones in `docs/`.

## 2) Communication Style
- I am a senior engineer working with Flutter, not a beginner
- Explain tradeoffs, not basics
- Compare: native Android vs Flutter, simple vs scalable, local vs cloud
- If I am overengineering — stop me
- If I am underengineering something important — warn me
- If I am accepting generated code without understanding it — challenge me

---

# Section B — Flutter Direction

## 1) Flutter-First (YOU MUST FOLLOW)
This project is Flutter-first. Do not suggest or implement:
- Native Android/iOS code unless Flutter plugins don't cover the need
- Platform-specific UI frameworks (XML layouts, SwiftUI)
- Legacy patterns (Provider for new features, manual state management)

## 2) Source of Truth
- Prefer official Flutter documentation (docs.flutter.dev) and pub.dev package docs
- When recommending a newer API or package choice, explain its maturity level, tradeoffs, and fallback
- If unsure whether a pattern or package is current, say so explicitly before implementing

## 3) Tech Stack
- **Framework:** Flutter 3.x, Dart 3.x (null safety)
- **Architecture:** Feature-first Clean Architecture (presentation → domain → data)
- **State Management:** BLoC/Cubit (bloc + flutter_bloc)
- **DI:** GetIt
- **Routing:** GoRouter
- **Testing:** flutter_test, bloc_test, mocktail
- **Crash Reporting:** Sentry (planned — currently logs to Supabase `error_logs` table)

> **Note:** Adapt the stack to the specific project. Core principles remain the same regardless of domain.

## 4) State Management
- Cubits own and expose screen state via StateStream
- State classes are immutable (use Equatable)
- Widgets observe state — they do not own business logic
- Handle Loading / Success / Error / Empty explicitly in state
- Use `BlocBuilder` for UI, `BlocListener` for side effects

---

# Section C — Architecture

## 1) Clean Architecture (YOU MUST FOLLOW)
- This project follows Clean Architecture: presentation → domain → data
- Never bypass layers or mix responsibilities across layer boundaries
- Widgets render and dispatch events — no direct database access
- Repositories abstract data sources — mapping logic belongs in the data layer
- Every layer must carry real responsibility — architecture should be educational, not ceremonial
- Load **flutter-apply-architecture-best-practices** or **flutter-architecting-apps** (Section H) when designing new features

## 2) Package Structure
```
lib/
├── core/
│   ├── entities/          # Domain models
│   ├── error/             # Result type, AppError
│   └── utils/             # Shared utilities
├── data/
│   ├── database/          # Database, DAOs, mappers
│   └── repositories/      # Repository implementations
├── features/
│   ├── feature_a/         # Feature module
│   │   └── presentation/
│   │       ├── cubit/     # State management
│   │       ├── widgets/   # Feature-specific widgets
│   │       └── *.dart     # Pages
│   └── feature_b/
└── shared/
    ├── components/        # Reusable UI components
    ├── services/          # Services (notifications, analytics, etc.)
    ├── routing/           # GoRouter config
    ├── theme/             # Colors, text styles, theme
    └── extensions/        # Dart extensions
```

## 3) Shared Code
- Move logic to shared/ only if truly reused across features — premature abstraction is worse than two similar lines
- Do not create shared utilities speculatively

---

# Section D — Code Quality

## 1) Change Discipline (YOU MUST FOLLOW)
- Make the smallest change that solves the problem
- Fix root causes, not symptoms
- Do not refactor unrelated code unless explicitly requested
- Read relevant code before modifying — state assumptions when unclear
- Never break existing functionality unless explicitly instructed

## 2) Task Branch Discipline
- Before starting a meaningful task, propose a small focused branch name and explain the task goal
- Prefer one small branch per task or milestone slice
- Branch format: `<type>/short-description` (e.g., `feat/reminder-action-sheet`, `fix/schedule-time-parsing`)

## 3) Dependencies & Version Discipline
- Before adding a dependency, explain: why needed now, alternatives considered, and whether it can be deferred
- Any new dependency must be latest stable, well-maintained, and appropriate for the problem
- Do not upgrade major versions without explaining compatibility risks
- Prefer stable releases — alphas/betas only with explicit justification

## 4) Error Handling
- Handle loading, error, empty, and success states explicitly — no silent failures
- Catch errors at the repository boundary, not inside Cubits or widgets
- Use `Result<T>` type for repository operations
- Propagate errors cleanly — do not swallow exceptions

## 5) Security
- Never hardcode secrets, tokens, or credentials
- Never log sensitive information
- Validate external input
- Flag security risks proactively when spotted

## 6) Build & Test Verification
- After meaningful code changes, run: `flutter test` for tests
- Do not claim code works unless it was verified
- If verification was not run, state that explicitly
- Load **flutter-add-widget-test** or **flutter-add-integration-test** (Section H) when writing new tests

## 7) Widget Discipline
- Keep widgets small and focused
- Extract sub-widgets when a widget grows beyond a single responsibility
- No business logic inside widgets — delegate to Cubit
- Prefer stateless widgets that receive state and emit events
- Load **flutter-building-layouts** or **flutter-build-responsive-layout** (Section H) for layout questions; **flutter-fix-layout-issues** when diagnosing overflow/constraint errors

---

# Section E — Testing

- Write meaningful tests for: Cubit state transitions, repository behavior, mapping logic, error handling
- When code changes introduce logic, state transitions, or data behavior — suggest tests
- Bug fixes in logic should include a reproducing test
- One behavior per test case
- Tests must be deterministic — no flaky or timing-dependent tests
- Do not demand tests for trivial UI widgets or framework behavior
- Testing is for learning and correctness, not for coverage metrics
- Load **flutter-add-widget-test** for widget test scaffolding, **flutter-add-integration-test** for end-to-end tests (Section H)

---

# Section F — Code Quality for Repos

- Readable names, clear package structure
- Comments only when they explain WHY, not WHAT
- No secrets, no private data, no messy uncommitted experiments
- Small, focused commits with clear messages
- No feature creep — stay focused on demonstrating Flutter practices

## Public Repo Safety (YOU MUST FOLLOW)
- Never commit or push without explicit user approval
- Before suggesting a commit, review `git status` and `git diff` for secrets, local paths, credentials, generated junk, or environment-specific files
- Never commit `.env`, keystores, signing configs, API keys, tokens, `local.properties`, or `.claude/settings.local.json`
- If a file looks suspicious, stop and ask before proceeding
- Safety is more important than speed

---

# Section G — What to Avoid

- Feature creep beyond project scope
- Premature modularization or ceremony-only abstractions
- "Clever" code that is hard to teach or maintain
- Giant widgets or god-Cubits
- AI-generated code that I cannot explain

---

# Section H — Referenced Skills (skills.sh)

These skills are available for on-demand use. Load the relevant skill when the
task matches its description. Do not load skills speculatively — only when the
current task actually benefits from it.

## Architecture & Code Quality

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 1 | flutter-apply-architecture-best-practices | [link](https://www.skills.sh/flutter/skills/flutter-apply-architecture-best-practices) | Enforcing layer separation (UI / Logic / Data), MVVM with ChangeViewModels, constructor-injected Repositories |
| 2 | flutter-architecting-apps | [link](https://www.skills.sh/flutter/skills/flutter-architecting-apps) | Designing layered architecture with unidirectional data flow, SSOT in the Data layer, lean Views |
| 3 | flutter-dart-code-review | [link](https://www.skills.sh/affaan-m/everything-claude-code/flutter-dart-code-review) | Library-agnostic code review checklist: folder structure, lint config, generated files, platform isolation |

## Layout & Responsive Design

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 4 | flutter-building-layouts | [link](https://www.skills.sh/flutter/skills/flutter-building-layouts) | Constraint-based layout building: Row/Column/Stack, Expanded/Flexible, LayoutBuilder, four-phase workflow |
| 5 | flutter-build-responsive-layout | [link](https://www.skills.sh/flutter/skills/flutter-build-responsive-layout) | Adaptive layouts using `MediaQuery.sizeOf`, `LayoutBuilder`, constraint-based decisions (not hardware checks) |
| 6 | flutter-fix-layout-issues | [link](https://www.skills.sh/flutter/skills/flutter-fix-layout-issues) | Diagnosing overflow, infinite height, RenderBox-not-laid-out, and constraint-violation errors |

## Testing

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 7 | flutter-add-widget-test | [link](https://www.skills.sh/flutter/skills/flutter-add-widget-test) | Writing widget tests: testWidgets, find, expect, interaction and state-management testing |
| 8 | flutter-add-integration-test | [link](https://www.skills.sh/flutter/skills/flutter-add-integration-test) | End-to-end integration tests: Flutter Driver setup, MCP exploration, profiling |

## Routing & Navigation

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 9 | flutter-setup-declarative-routing | [link](https://www.skills.sh/flutter/skills/flutter-setup-declarative-routing) | go_router declarative routing: GoRoute, ShellRoute/StatefulShellRoute, deep linking, Path URL Strategy |

## Data & Networking

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 10 | flutter-implement-json-serialization | [link](https://www.skills.sh/flutter/skills/flutter-implement-json-serialization) | Manual JSON with dart:convert: fromJson/toJson, `compute()` for large payloads, error handling |
| 11 | flutter-use-http-package | [link](https://www.skills.sh/flutter/skills/flutter-use-http-package) | HTTP networking: request execution, response handling, background parsing for large responses |

## UI & Polish

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 12 | flutter-animations | [link](https://www.skills.sh/madteacher/mad-agents-skills/flutter-animations) | Five animation approaches: implicit, explicit, hero, staggered, physics-based; controller disposal, AnimatedBuilder |
| 13 | flutter-add-widget-preview | [link](https://www.skills.sh/flutter/skills/flutter-add-widget-preview) | `@Preview` annotation for isolated widget previews outside the full app context |

## Localization & Internationalization

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 14 | flutter-setup-localization | [link](https://www.skills.sh/flutter/skills/flutter-setup-localization) | i18n/l10n with flutter_localizations + intl, .arb files, AppLocalizations type-safe access |

## Performance & Optimization

| # | Skill | URL | When to use |
|---|-------|-----|-------------|
| 15 | flutter-reducing-app-size | [link](https://www.skills.sh/flutter/skills/flutter-reducing-app-size) | App size analysis (`--analyze-size`), symbol splitting, unused resource removal, media compression |
| 16 | flutter-performance | [link](https://www.skills.sh/flutter/skills/flutter-performance) | Profiling jank: UI-thread vs GPU-thread, const constructors, saveLayer/Opacity minimization, 16ms target |

---

# Section I — Curated Flutter Reference Repos

> **Source:** [@DivyanshT91162 — 100 Flutter repos every Flutter dev should know](https://x.com/DivyanshT91162/status/2080239274465865979)
>
> Ranked by GitHub stars, architecture quality, test coverage, and real-world utility.
>
> **How to use this section:**
> These are **read-only reference repos** — not dependencies to install.
> When a design question arises, check the relevant repo for prior art before inventing a solution.
> Entries are filtered and grouped by direct relevance to this project's stack
> (Flutter + Supabase + BLoC + Clean Architecture + GoRouter + GetIt).
> Repos that are deprecated, duplicated, or unrelated to this project's domain are excluded.

---

## I-1 · Core Stack (use frequently)

These repos directly match this project's exact stack.

| Repo | GitHub | Why relevant to this project |
|------|--------|-------------------------------|
| **felangel/bloc** | [github.com/felangel/bloc](https://github.com/felangel/bloc) | Canonical BLoC/Cubit library this project uses. Read for Cubit patterns, testing helpers, and BlocObserver setup |
| **supabase/supabase-flutter** | [github.com/supabase/supabase-flutter](https://github.com/supabase/supabase-flutter) | Official Supabase Flutter SDK — auth, realtime, storage, RPC. Check when debugging Supabase client behavior |
| **fluttercommunity/get_it** | [github.com/fluttercommunity/get_it](https://github.com/fluttercommunity/get_it) | GetIt DI — this project's service locator. Reference for lazy singleton vs factory registration patterns |
| **flutter/packages** | [github.com/flutter/packages](https://github.com/flutter/packages) | Contains go_router source. Check when GoRouter behavior is ambiguous or a new routing pattern is needed |
| **felangel/equatable** | [github.com/felangel/equatable](https://github.com/felangel/equatable) | Value equality for BLoC state classes — already in use. Reference for `props` list patterns |
| **felangel/mocktail** | [github.com/felangel/mocktail](https://github.com/felangel/mocktail) | Null-safe mocking without code generation — used in this project's tests. Reference for stub/verify patterns |

---

## I-2 · Architecture Reference (use when designing features)

Read these before designing a new feature layer or when evaluating architecture trade-offs.

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **ResoCoder/flutter-clean-architecture-tdd** | [github.com/ResoCoder/flutter-clean-architecture-tdd](https://github.com/ResoCoder/flutter-clean-architecture-tdd) | The canonical TDD + Clean Architecture reference. Check `UseCase`, `Repository`, and `Failure` patterns before implementing a new domain layer |
| **brianegan/flutter_architecture_samples** | [github.com/brianegan/flutter_architecture_samples](https://github.com/brianegan/flutter_architecture_samples) | Same app in 10+ architectures side-by-side. Use when comparing BLoC vs alternatives or explaining architecture trade-offs |
| **bizz84/starter_architecture_flutter_firebase** | [github.com/bizz84/starter_architecture_flutter_firebase](https://github.com/bizz84/starter_architecture_flutter_firebase) | Production-ready architecture with GoRouter — swap Firebase for Supabase mentally. Reference for app-level wiring and auth guard patterns |
| **VeryGoodOpenSource/very_good_cli** | [github.com/VeryGoodOpenSource/very_good_cli](https://github.com/VeryGoodOpenSource/very_good_cli) | VGV scaffolds production Flutter apps with full test setup. Check generated folder structure when questioning how to organize a new feature |
| **VeryGoodOpenSource/very_good_analysis** | [github.com/VeryGoodOpenSource/very_good_analysis](https://github.com/VeryGoodOpenSource/very_good_analysis) | Strict Dart/Flutter lint rules. Reference when tightening `analysis_options.yaml` in this project |

---

## I-3 · State Management & Domain Modeling (use when modeling state)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **rrousselGit/freezed** | [github.com/rrousselGit/freezed](https://github.com/rrousselGit/freezed) | Immutable classes, sealed unions, `copyWith` via codegen. Evaluate for domain entities and complex state classes |
| **ReactiveX/rxdart** | [github.com/ReactiveX/rxdart](https://github.com/ReactiveX/rxdart) | Reactive stream extensions: BehaviorSubject, debounce, throttle. Useful when complex stream composition is needed beyond BLoC |
| **mobxjs/mobx.dart** | [github.com/mobxjs/mobx.dart](https://github.com/mobxjs/mobx.dart) | Observable reactive state — contrast with BLoC when explaining state management trade-offs |

---

## I-4 · Networking & Data (use when implementing API or local storage)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **cfug/dio** | [github.com/cfug/dio](https://github.com/cfug/dio) | Production HTTP client with interceptors, FormData, cancellation. Reference if a direct REST call is needed outside the Supabase client |
| **simolus3/drift** | [github.com/simolus3/drift](https://github.com/simolus3/drift) | Reactive SQLite with type-safe queries and migrations. Evaluate if local-first offline caching is added to this project |
| **isar/hive** | [github.com/isar/hive](https://github.com/isar/hive) | Lightweight key-value local store — pure Dart, no native deps. Use for lightweight caching (cart draft, user prefs) |
| **GetDutchie/flutter_secure_storage** | [github.com/GetDutchie/flutter_secure_storage](https://github.com/GetDutchie/flutter_secure_storage) | Secure Keychain/Keystore storage. Reference for storing auth tokens or sensitive session data securely |
| **isar/isar** | [github.com/isar/isar](https://github.com/isar/isar) | High-performance NoSQL DB for Flutter. Evaluate as Hive alternative if complex local queries are needed |

---

## I-5 · UI Components & Polish (use when building screens)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **abuanwar072/E-Commerce-Complete-Flutter-UI** | [github.com/abuanwar072/E-Commerce-Complete-Flutter-UI](https://github.com/abuanwar072/E-Commerce-Complete-Flutter-UI) | Full e-commerce Flutter UI kit matching this project's domain. Reference for product cards, cart screens, and order flow UI patterns |
| **gskinner/flutter_animate** | [github.com/gskinner/flutter_animate](https://github.com/gskinner/flutter_animate) | Declarative animation chaining with minimal boilerplate. Use for entrance animations, skeleton loaders, transition effects |
| **imaNNeoFighT/fl_chart** | [github.com/imaNNeoFighT/fl_chart](https://github.com/imaNNeoFighT/fl_chart) | Customizable charts — line, bar, pie. Use if admin or analytics dashboards are added |
| **jogboms/flutter_spinkit** | [github.com/jogboms/flutter_spinkit](https://github.com/jogboms/flutter_spinkit) | Loading indicator collection. Quick reference when selecting a loading widget style |
| **Baseflow/flutter_cached_network_image** | [github.com/Baseflow/flutter_cached_network_image](https://github.com/Baseflow/flutter_cached_network_image) | Cached image loading with placeholder and error states. Use for product images and user avatars |
| **rive-app/rive-flutter** | [github.com/rive-app/rive-flutter](https://github.com/rive-app/rive-flutter) | Vector animation state machines. Use for premium micro-interactions — success/empty-state animations |
| **aloisdeniel/figma_squircle** | [github.com/aloisdeniel/figma_squircle](https://github.com/aloisdeniel/figma_squircle) | iOS-style squircle shapes. Use for card and button borders to match a premium fabric-brand aesthetic |
| **letsar/flutter_staggered_grid_view** | [github.com/letsar/flutter_staggered_grid_view](https://github.com/letsar/flutter_staggered_grid_view) | Staggered/Pinterest grid layout. Use for product catalogue screens with variable-height cards |

---

## I-6 · Payments & Commerce (use when implementing checkout)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **flutter-stripe/flutter_stripe** | [github.com/flutter-stripe/flutter_stripe](https://github.com/flutter-stripe/flutter_stripe) | Stripe payment integration — cards, Apple Pay, Google Pay. Architectural reference for payment intent flow even though this project uses Paymob |
| **techkingsley/flutter_paystack** | [github.com/techkingsley/flutter_paystack](https://github.com/techkingsley/flutter_paystack) | Paystack payment integration — closest regional equivalent to Paymob. Study for webhook + server-confirm patterns |

---

## I-7 · Testing (use when writing or reviewing tests)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **felangel/mocktail** | [github.com/felangel/mocktail](https://github.com/felangel/mocktail) | Already in I-1 — repeated here as the primary test-doubles reference |
| **flutter/samples** | [github.com/flutter/samples](https://github.com/flutter/samples) | Official sample apps include test examples for every Flutter pattern. First stop when scaffolding a new test type |
| **dart-lang/lints** | [github.com/dart-lang/lints](https://github.com/dart-lang/lints) | Official Dart lint rules. Reference when `analysis_options.yaml` needs tightening or a lint warning is unclear |

---

## I-8 · DevTools & Developer Productivity (use when debugging or profiling)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **flutter/devtools** | [github.com/flutter/devtools](https://github.com/flutter/devtools) | Flutter DevTools source — profiler, inspector, debugger. Read when a DevTools panel behavior is unexpected |
| **leoafarias/fvm** | [github.com/leoafarias/fvm](https://github.com/leoafarias/fvm) | Flutter Version Manager — switch SDK versions per project. Use when CI or a teammate's machine uses a different Flutter version |
| **felangel/mason** | [github.com/felangel/mason](https://github.com/felangel/mason) | Code generation with bricks — template-based scaffolding. Use to generate feature boilerplate (cubit + state + repository) consistently |
| **shorebirdtech/shorebird** | [github.com/shorebirdtech/shorebird](https://github.com/shorebirdtech/shorebird) | Flutter OTA code push. Evaluate before deciding whether a hot-fix requires a full store re-release |

---

## I-9 · Platform & Permissions (use when accessing device capabilities)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **Baseflow/permission_handler** | [github.com/Baseflow/permission_handler](https://github.com/Baseflow/permission_handler) | Unified permission API — camera, location, notifications. Reference when adding QR scanning or push notifications |
| **MaikuB/flutter_local_notifications** | [github.com/MaikuB/flutter_local_notifications](https://github.com/MaikuB/flutter_local_notifications) | Local notifications for Android/iOS/macOS. Use when implementing order-status push notifications |
| **fluttercommunity/flutter_workmanager** | [github.com/fluttercommunity/flutter_workmanager](https://github.com/fluttercommunity/flutter_workmanager) | Background task scheduling. Use if periodic background sync or retry logic is needed |
| **pichillilorenzo/flutter_inappwebview** | [github.com/pichillilorenzo/flutter_inappwebview](https://github.com/pichillilorenzo/flutter_inappwebview) | Full-featured WebView. Use for Paymob 3DS redirect flow if a native WebView is needed instead of url_launcher |

---

## I-10 · Localization & Linting (use when internationalizing)

| Repo | GitHub | Why relevant |
|------|--------|--------------|
| **flutter/packages** | [github.com/flutter/packages](https://github.com/flutter/packages) | Contains flutter_localizations. Reference for `.arb` file structure and `AppLocalizations` code generation |
| **invertase/dart_custom_lint** | [github.com/invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) | Custom lint rules for Dart. Use to enforce project-specific conventions (e.g., no direct `Supabase.instance` outside data layer) |

---

## I-11 · Do Not Use (excluded from this project)

The following repos from the thread are **excluded** — either deprecated, irrelevant to this stack, or superseded by current choices:

| Repo | Reason excluded |
|------|----------------|
| jonataslaw/getx | Conflicts with BLoC + GoRouter + GetIt architecture already in place |
| rrousselGit/riverpod | Conflicts with BLoC state management — use only as a learning contrast reference |
| FilledStacks/stacked | MVVM pattern — conflicts with Clean Architecture BLoC approach |
| firebase/flutterfire | Project uses Supabase, not Firebase |
| google/flutter-desktop-embedding | Historical reference only — Flutter desktop is now native |
| fluttercommunity/flutter_after_layout | Micro-utility — use `WidgetsBinding.addPostFrameCallback` directly |
| passsy/kt.dart | Superseded by Dart 3 collection literals and `Iterable` extensions |
| wolfenrain/bolt | Binary messaging protocol — not relevant to REST/Supabase stack |
| rencevio/flutterfire_desktop | Desktop Firebase — not relevant; project uses Supabase |

---

> **Last updated:** 2025-07-23
> **Source thread:** https://x.com/DivyanshT91162/status/2080239274465865979
