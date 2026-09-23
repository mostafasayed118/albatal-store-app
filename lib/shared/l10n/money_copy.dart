import 'package:intl/intl.dart';

import '../../core/entities/money.dart';
import '../../generated/l10n/app_localizations.dart';

/// The one place that turns a [Money] into locale-correct shopper-facing
/// copy (audit UX-019).
///
/// Why this exists rather than a `Money.format()` call per widget: the
/// entity's formatter is deterministic and locale-agnostic by design
/// (documents, admin tables, non-UI composition), so every price it
/// renders is Latin-digit and `EGP`-suffixed no matter who is reading.
/// The audit's complaint was exactly that on an Arabic-visible path —
/// "wrong currency code on every price; Arabic users see Latin-only
/// prices" — so the customer surfaces route through here:
///
/// - `en` → `1,290 EGP`
/// - `ar` → `١٬٢٩٠ ج.م.` (Arabic-Indic digits, Arabic group separator)
///
/// The symbol comes from the ARB (`currencySymbol`) so the copy stays
/// translatable. The PLACEMENT is pinned to the app's established suffix
/// convention (`#,##0 ¤`) rather than each locale's CLDR default: the
/// whole Stitch design system is built around "amount then currency"
/// (every mockup and screenshot), and CLDR's `en` default is a spaceless
/// prefix (`EGP1,290`), which is worse copy than either convention.
/// Digit SHAPING and grouping still follow the locale — that is the part
/// the audit actually asked for.
///
/// Decimals follow the app's convention, now applied per locale: whole
/// amounts print no decimals, fractional piasters keep two. The rule is
/// computed from [Money.minorUnits] — never from the formatted string —
/// so it cannot disagree with the amount the order records.
String moneyText(AppLocalizations l10n, Money amount) {
  final whole = amount.minorUnits % 100 == 0;
  return NumberFormat.currency(
    locale: _numberLocale(l10n.localeName),
    symbol: l10n.currencySymbol,
    customPattern: whole ? '#,##0 ¤' : '#,##0.00 ¤',
  ).format(amount.majorUnits);
}

/// The locale whose NUMBER data should format [localeName]'s amounts.
///
/// The app ships `ar` (the generated ARB locale), but intl's plain `ar`
/// number data is Latin-digit with `,` grouping — it would render
/// "1,290 ج.م." and leave the audit's Arabic-digit requirement unmet.
/// `ar_EG` carries the Egyptian conventions the audit specified:
/// Arabic-Indic digits (٠-٩), the Arabic group separator (٬) and the
/// Arabic decimal separator (٫). The store is Egypt-only by policy (EGP
/// pricing, Egyptian mobile numbers), so mapping the language to its
/// Egyptian locale is the honest interpretation of "Arabic" here rather
/// than an assumption about other Arabic-speaking markets.
String _numberLocale(String localeName) =>
    localeName.startsWith('ar') ? 'ar_EG' : localeName;
