---
kind: error_handling
name: Result<T> + AppError — repository-boundary error translation
category: error_handling
scope:
    - '**'
source_files:
    - lib/core/error/app_error.dart
    - lib/core/error/result.dart
    - lib/features/auth/data/supabase_auth_repository.dart
    - lib/features/addresses/data/local_address_repository.dart
    - lib/features/storefront/data/checkout_service.dart
---

The Al Batal Elite Flutter app uses a clean, repository-boundary error model built around two core types in `lib/core/error/`:

- `AppError` (`lib/core/error/app_error.dart`) — a simple, user-safe value object holding a displayable `message` and an optional `cause`. It is the only error type that crosses into presentation.
- `Result<T>` (`lib/core/error/result.dart`) — a sealed `Result<T>` with `Success<T>` and `Failure<T>` subtypes. Every repository method returns `Future<Result<T>>`, so callers handle errors via the `when(success:, failure:)` combinator rather than exceptions.

**Propagation pattern**
Data-layer repositories (e.g. `SupabaseAuthRepository`, `LocalAddressRepository`, `CheckoutService`) wrap all external calls in `try / on <FrameworkException> catch` blocks. Known framework exceptions (Supabase `AuthException`, `PostgrestException`) are caught first and translated into an `AppError` whose message has been mapped to user-friendly text; unknown exceptions fall through to a generic `"An unexpected error occurred"` message while preserving the original exception as `cause`. The repository then returns `Failure(AppError(...))` instead of throwing.

**Presentation layer**
Cubits and UI code never see raw framework exceptions or Supabase strings. They consume `Result<T>` via `when(...)`, branch on `Success`/`Failure`, and surface `error.message` to the user. This keeps domain logic free of I/O concerns and makes every error path explicit.

**Key files**
- `lib/core/error/app_error.dart` — user-safe error value object
- `lib/core/error/result.dart` — sealed Result monad with `when` combinator
- `lib/features/auth/data/supabase_auth_repository.dart` — canonical example of catching `AuthException`, mapping messages via `_mapAuthError`, and returning `Result`
- `lib/features/addresses/data/local_address_repository.dart` — local-storage error translation to `AppError`
- `lib/features/storefront/data/checkout_service.dart` — catches `PostgrestException` from Supabase RPCs

**Conventions developers should follow**
1. Never throw exceptions across the repository boundary — always return `Result<T>`.
2. Catch known framework exceptions (`AuthException`, `PostgrestException`, etc.) before the bare `catch` and map their messages to user-safe text.
3. Put any domain-specific error-mapping logic inside the data layer (per Clean Architecture C.1), not in cubits or widgets.
4. Use `Result.when(success:, failure:)` to exhaustively handle both branches at call sites.