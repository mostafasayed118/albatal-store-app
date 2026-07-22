---
kind: logging_system
name: Custom Flutter Logger with Levels, Categories, and Observers
category: logging_system
scope:
    - '**'
source_files:
    - lib/shared/services/logger.dart
    - lib/main.dart
    - lib/shared/services/app_bloc_observer.dart
    - lib/shared/services/navigation_observer.dart
---

The app uses a lightweight, in-house logging system built around a single `Log` class rather than an external logging package. It provides level-based filtering, named categories, structured helper methods, and integration with BLoC/Cubit and navigation observers.

### What is used
- **No third-party logging library** — the project defines its own logger in `lib/shared/services/logger.dart`.
- Output goes through Flutter's `debugPrint`, so logs appear in the console during debug/profile builds and are suppressed in release mode.
- A global minimum log level (`LogLevel.debug` in debug, `LogLevel.warning` in production) controls verbosity.

### Key files
- `lib/shared/services/logger.dart` — core `Log` class, `LogLevel` and `LogCategory` enums, formatting, timestamping, and category-specific helpers (`auth`, `nav`, `cubit`, `api`, `payment`).
- `lib/main.dart` — sets the initial log level and emits bootstrap lifecycle logs; wires up the Bloc observer.
- `lib/shared/services/app_bloc_observer.dart` — `BlocObserver` that routes every Cubit/Bloc event, transition, error, create/close to `Log.cubit` / `Log.e`.
- `lib/shared/services/navigation_observer.dart` — `NavigatorObserver` that logs push/pop/replace/remove/back-gesture via `Log.nav`.

### Architecture and conventions
- **Static API**: `Log.d/i/w/e(...)` plus domain helpers like `Log.auth(...)`, `Log.cubit(name, msg)`, `Log.api(method, url, statusCode, body)`, `Log.payment(...)`. Callers pick the helper that matches their concern instead of passing a category manually.
- **Categories**: `app`, `navigation`, `auth`, `cubit`, `network`, `payment`, `analytics`, `error` — each maps to a `[CATEGORY]` tag in output.
- **Structured fields**: `Log.e` accepts optional `error` and `stackTrace`; `Log.api` includes method, URL, status code, and (debug-only) request/response body. The formatter prefixes warning/error lines with emoji markers (`⚠️`, `🔴`).
- **Level gating**: `_log` short-circuits when `level.index < _minLevel.index` and always returns early in `kReleaseMode`, so no logging overhead ships to production.
- **Observability hooks**: Global `Bloc.observer = AppBlocObserver()` and a `NavigationObserver` provide automatic, cross-cutting logging for state changes and route transitions without polluting feature code.

### Rules developers should follow
1. **Use `Log.*` helpers**, never bare `print`/`debugPrint` — prefer `Log.auth`, `Log.cubit`, `Log.api`, `Log.payment`, or `Log.nav` so messages carry a category automatically.
2. **Attach errors and stack traces** via `Log.e(message, error: e, stackTrace: st)` instead of stringifying them yourself.
3. **Keep sensitive data out of logs** — `Log.api` only prints bodies in `kDebugMode`; do not pass secrets even there.
4. **Do not call `Log.setLevel` from feature code** — it is intended for bootstrap/configuration layers only.
5. **Rely on the observers** for Cubit/Bloc and navigation events; avoid duplicating those logs inside individual cubits/pages.