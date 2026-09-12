/// A user-safe error emitted at a repository boundary.
final class AppError {
  const AppError(this.message, {this.cause, this.stackTrace, this.code});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Machine-readable classification for UI localization, so pages map
  /// failures by code instead of matching English message literals
  /// (audit 2026-09-13). Null = no code assigned; legacy literal
  /// matching stays as a fallback where tests/paths predate the code.
  final String? code;
}
