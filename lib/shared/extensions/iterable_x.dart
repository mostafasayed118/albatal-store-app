/// Shared extension for [Iterable] convenience methods.
extension IterableX<T> on Iterable<T> {
  /// Returns the first element, or `null` if the iterable is empty.
  T? get firstOrNull => isEmpty ? null : first;
}
