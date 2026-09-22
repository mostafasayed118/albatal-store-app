import 'app_error.dart';

/// The single error boundary type of the app (audit 2026-09-21, P1 docs).
///
/// Every repository and use case returns `Result<T>` instead of throwing:
/// [Success] carries the value, [Failure] carries an [AppError] whose
/// `message` is diagnosis-only English and whose optional `code` drives
/// localized UI copy (see `failure_codes.dart`). Construct results through
/// [Result.guard] — never hand-write try/catch blocks in repositories —
/// and consume them with the `when`/switch pattern below so a new subtype
/// is a compile-time error, not a missed branch.
sealed class Result<T> {
  const Result();

  /// Exhaustively maps this result to [R]: [success] receives the value,
  /// [failure] the [AppError]. Because [Result] is sealed, the compiler
  /// flags any future subtype missing from the consumer's switch.
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
  /// Local repositories delegate their try/catch boundaries here so the
  /// fail-soft message text stays byte-identical in one place per call
  /// site instead of hand-written in every method.
  ///
  /// [code] is the machine-readable class of the failure (see
  /// `failure_codes.dart`). Supply it whenever the APP authored
  /// [failureMessage]: the UI then shows localized copy and [failureMessage]
  /// becomes diagnosis only. Omit it when the message carries server wording
  /// that must be shown verbatim (audit 2026-09-19, sweep part 32).
  static Future<Result<T>> guard<T>(
    Future<T> Function() action,
    String failureMessage, {
    String? code,
  }) async {
    try {
      return Success(await action());
    } catch (e, st) {
      return Failure(
          AppError(failureMessage, cause: e, stackTrace: st, code: code));
    }
  }
}

/// The ok branch of [Result]: carries the produced [value].
///
/// Constructed only inside [Result.guard]; repositories never wrap values
/// by hand, so every `Success` provably passed through the boundary.
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

/// The error branch of [Result]: carries the classified [AppError].
///
/// The `error.message` is fixed diagnosis copy (never rendered to shoppers
/// when a `code` is present); `cause`/`stackTrace` keep the original
/// exception for logging.
final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}
