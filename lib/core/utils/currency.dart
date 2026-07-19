import '../entities/money.dart';

/// Formats [Money] as a currency string with the EGY suffix.
///
/// Convenience helper kept for ergonomic call sites: `money(state.total)`
/// reads better than `state.total.format()` in dense widget trees.
String money(Money n) => n.format();
