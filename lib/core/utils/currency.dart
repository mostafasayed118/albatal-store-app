import 'package:flutter/widgets.dart';

import '../../generated/l10n/app_localizations.dart';
import '../entities/money.dart';

/// Formats [Money] as a currency string with the localized currency code.
///
/// Convenience helper kept for ergonomic call sites: `money(state.total)`
/// reads better than `state.total.format()` in dense widget trees.
///
/// When [context] is provided the active locale and `currencyCode` are
/// resolved from the widget tree (e.g. `EGP` in English, `ج.م.` in Arabic).
String money(Money n, {BuildContext? context}) {
  final locale = context != null ? Localizations.maybeLocaleOf(context) : null;
  final l10n = context != null ? AppLocalizations.of(context) : null;
  return n.format(
    locale: locale?.toString(),
    symbol: l10n?.currencyCode ?? 'EGP',
  );
}
