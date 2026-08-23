import 'dart:async';

/// Isolated ticker for the flash-sale countdown (SRP extraction from [CatalogCubit]).
///
/// Owns the periodic [Timer] that ticks once per second and computes the
/// remaining duration from an injectable clock. The owner (Cubit) stays
/// responsible for `flashEnd` / `flashRemaining` state but receives updates
/// via [onTick] / [onDone] callbacks:
///
///   `onTick: (remaining) => emit(state.copyWith(flashRemaining: remaining))`
final class FlashSaleTicker {
  FlashSaleTicker({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Injectable clock so the countdown is testable deterministically.
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _end;

  /// Remaining time until [_end], clamped at zero. Null when not started.
  Duration? get remaining {
    final end = _end;
    if (end == null) return null;
    final diff = end.difference(_now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Starts the countdown ending at [end].
  ///
  /// Emits the initial remaining value via [onTick] immediately, then ticks
  /// once per second. Clamps at zero and calls [onDone] once [end] passes.
  void start(
    DateTime end, {
    required void Function(Duration remaining) onTick,
    void Function()? onDone,
  }) {
    cancel();
    _end = end;
    final diff = end.difference(_now());
    final clamped = diff.isNegative ? Duration.zero : diff;
    onTick(clamped);
    if (clamped == Duration.zero) {
      onDone?.call();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _end;
      if (current == null) return;
      final rem = current.difference(_now());
      if (rem.isNegative) {
        _timer?.cancel();
        _timer = null;
        onTick(Duration.zero);
        onDone?.call();
      } else {
        onTick(rem);
      }
    });
  }

  /// Cancels the active ticker, if any.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
