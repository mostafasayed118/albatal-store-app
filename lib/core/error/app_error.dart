/// A user-safe error emitted at a repository boundary.
final class AppError {
  const AppError(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}
