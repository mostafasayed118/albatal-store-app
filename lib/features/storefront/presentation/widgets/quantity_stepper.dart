import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // §17: exposed to screen readers as one adjustable value with
    // increment/decrement actions instead of three anonymous widgets.
    return Semantics(
      container: true,
      label: l.quantity,
      value: '$quantity',
      increasedValue: '${quantity < max ? quantity + 1 : quantity}',
      decreasedValue: '${quantity > min ? quantity - 1 : quantity}',
      // The action labels are what TalkBack/VoiceOver *speak*, so they follow the
      // locale like the visible tooltips below — hardcoded English here announced
      // "Increase"/"Decrease" to an Arabic shopper (audit 2026-09-19, sweep part 32).
      customSemanticsActions: {
        if (quantity < max)
          CustomSemanticsAction(label: l.increaseQuantity): () =>
              onChanged(quantity + 1),
        if (quantity > min)
          CustomSemanticsAction(label: l.decreaseQuantity): () =>
              onChanged(quantity - 1),
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.decreaseQuantity,
            onPressed: quantity > min
                ? () {
                    hapticTap();
                    onChanged(quantity - 1);
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            tooltip: l.increaseQuantity,
            onPressed: quantity < max
                ? () {
                    hapticTap();
                    onChanged(quantity + 1);
                  }
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
