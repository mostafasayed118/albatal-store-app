import 'package:flutter/material.dart';

import '../../../../shared/components/feedback.dart';

/// The success check-mark: a quick ease-out-back pop plus a single
/// success haptic on entry. Motion here is earned — it marks the one
/// moment the whole flow was aiming at.
///
/// Extracted from `order_success_page.dart` (was private `_SuccessBurst`).
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({super.key});

  @override
  State<SuccessBurst> createState() => SuccessBurstState();
}

/// Public state so widget tests can drive the burst if needed.
/// Not part of the public API contract — prefer pumping [SuccessBurst].
class SuccessBurstState extends State<SuccessBurst> {
  @override
  void initState() {
    super.initState();
    hapticSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: CircleAvatar(
        radius: 48,
        backgroundColor: scheme.primary,
        child: Icon(Icons.check, size: 60, color: scheme.onPrimary),
      ),
    );
  }
}
