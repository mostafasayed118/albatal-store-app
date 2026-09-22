import 'package:flutter/material.dart';

/// Terminal row for cancelled/refunded/expired orders: no progress track,
/// error-colored marker. No timestamp — the backend has no per-state
/// timestamps, so nothing here may pretend to be a cancellation time.
///
/// Extracted from `order_status_timeline.dart` verbatim (was private
/// `_CancelledTerminal`).
class CancelledTerminal extends StatelessWidget {
  const CancelledTerminal({super.key, required this.scheme, required this.label});

  final ColorScheme scheme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cancel, size: 20, color: scheme.error),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
