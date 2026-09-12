/// Shared extension for [Iterable] convenience methods.
///
/// Note: [IterableX.firstOrNull] duplicates the identical extension member
/// in `package:collection` (`IterableExtensions.firstOrNull`). It is kept
/// here deliberately — the app does not depend on `package:collection`
/// and adding it is out of scope for this slice — but prefer the
/// package version if that dependency is ever introduced.
extension IterableX<T> on Iterable<T> {
  /// Returns the first element, or `null` if the iterable is empty.
  ///
  /// Duplicates `package:collection`'s `firstOrNull`; see the class dartdoc.
  T? get firstOrNull => isEmpty ? null : first;
}
