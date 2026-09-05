import 'package:flutter/material.dart';

import '../../generated/l10n/app_localizations.dart';

extension BuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

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
