import 'app_error.dart';

sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(AppError error) failure,
  }) =>
      switch (this) {
        Success<T>(:final value) => success(value),
        Failure<T>(:final error) => failure(error),
      };

  /// Runs [action] and maps any throw into a [Failure] with the fixed,
  /// user-safe [failureMessage] (the raw exception rides along as
  /// [AppError.cause] for diagnostics, never for display).
  ///
  /// When [onError] is provided it fully owns the [AppError] construction
  /// — use it for boundaries that map different exception types to
  /// different user-safe messages (Postgrest vs transport failures).
  /// The fixed [failureMessage] then only applies when no mapper is given.
  ///
  /// Repositories delegate their try/catch boundaries here so the
  /// fail-soft message text stays byte-identical in one place per call
  /// site instead of hand-written in every method.
  static Future<Result<T>> guard<T>(
    Future<T> Function() action,
    String failureMessage, {
    AppError Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Success(await action());
    } catch (e, st) {
      final error = onError?.call(e, st) ??
          AppError(failureMessage, cause: e, stackTrace: st);
      return Failure(error);
    }
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}
