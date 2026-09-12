import 'package:flutter/material.dart';

/// 3-step progress indicator (Shipping → Payment → Confirm).
final class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.scheme,
  });
  final List<String> steps;
  final int currentStep;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: steps.asMap().entries.map((stepEntry) {
        final active = stepEntry.key <= currentStep;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    active ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor: active ? scheme.onPrimary : scheme.onSurface,
                child: Text('${stepEntry.key + 1}'),
              ),
              const SizedBox(height: 4),
              Text(stepEntry.value, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
