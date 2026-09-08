import 'package:flutter/material.dart';

/// Dialog field-controller lifecycle shared by the admin pages.
///
/// Dialogs are separate routes: their [TextField]s must not be disposed
/// while the exit animation is still mounted, so controllers are
/// registered here and freed together when the owning page disposes —
/// never synchronously when `showDialog` returns. Previously copy-pasted
/// across the inventory, variant-editor, and order-detail pages.
mixin DialogControllers<T extends StatefulWidget> on State<T> {
  final List<TextEditingController> _dialogControllers = [];

  /// Creates a controller owned by this page. The optional [text]
  /// seeds edit dialogs; created dialogs pass nothing.
  @protected
  TextEditingController newDialogController([String? text]) {
    final controller = TextEditingController(text: text);
    _dialogControllers.add(controller);
    return controller;
  }

  /// Frees every controller created via [newDialogController]. Callers
  /// invoke this from their own [State.dispose] alongside any other
  /// disposables, before `super.dispose()`.
  @protected
  void disposeDialogControllers() {
    for (final controller in _dialogControllers) {
      controller.dispose();
    }
  }
}
