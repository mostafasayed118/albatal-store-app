import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > min ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$quantity'),
          IconButton(
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
}
