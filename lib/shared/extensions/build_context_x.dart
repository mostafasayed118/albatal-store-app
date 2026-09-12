import 'package:flutter/material.dart';

import '../../generated/l10n/app_localizations.dart';

extension BuildContextX on BuildContext {
  /// Localizations for this context. The `!` is guarded by the assert in
  /// debug builds: a null here means the widget is pumped outside a
  /// [MaterialApp] wired with [AppLocalizations] (see `lib/app.dart`) —
  /// in widget tests, wrap the subject with those delegates.
  AppLocalizations get l10n {
    final loc = AppLocalizations.of(this);
    assert(
      loc != null,
      'AppLocalizations not found above this BuildContext. '
      'Pump the widget under a MaterialApp (or mock) configured with '
      'AppLocalizations.localizationsDelegates + supportedLocales.',
    );
    return loc!;
  }

  /// A "proceed / go forward" arrow that points in the reading direction.
  ///
  /// `Icons.arrow_forward` does not mirror under RTL (its IconData has
  /// `matchTextDirection: false`), so call sites pick the real glyph that
  /// matches [Directionality]: forward = right in LTR, left in RTL.
  IconData get directionalForwardIcon =>
      Directionality.of(this) == TextDirection.rtl
          ? Icons.arrow_back
          : Icons.arrow_forward;

  /// A trailing chevron for list rows that open another screen, flipping in
  /// RTL like [directionalForwardIcon].
  IconData get directionalTrailingIcon =>
      Directionality.of(this) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right;
}
