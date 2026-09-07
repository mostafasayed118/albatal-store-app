/// Sensory-feedback helpers shared across surfaces (UX polish pass).
///
/// The app previously had zero haptic feedback anywhere; these wrappers
/// give every surface one vocabulary for "the UI heard you":
///   * [hapticTap]        — selection chips, steppers, toggles (light)
///   * [hapticSuccess]    — an action completed: added to cart, order placed
///   * [hapticWarning]    — destructive or disabled affordances (medium)
///   * [showConfirmation] — one floating "it happened" snackbar
///
/// Pure system calls — no UI scaffold required — so tests can pump any
/// widget without platform channels beyond the default TestWidgetsFlutter
/// binding mocks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void hapticTap() => HapticFeedback.selectionClick();

void hapticSuccess() => HapticFeedback.mediumImpact();

void hapticWarning() => HapticFeedback.heavyImpact();

/// Show a floating "action acknowledged" snackbar and confirm it
/// physically. Kept tiny on purpose: one message, no actions —
/// anything that needs actions (undo, view) builds its own [SnackBar]
/// with the same floating behavior.
void showConfirmation(BuildContext context, String message) {
  hapticSuccess();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
}

/// Floating error twin of [showConfirmation]: same shape, warning haptic.
/// For failures that surface inline (a save that bounced, a link that
/// would not open) rather than as a full-screen error state. The message
/// must already be user-facing — raw exceptions stay in logs.
void showFloatingError(BuildContext context, String message) {
  hapticWarning();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
}
