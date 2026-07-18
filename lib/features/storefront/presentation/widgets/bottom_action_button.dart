import 'package:flutter/material.dart';

class BottomActionButton extends StatelessWidget {
  const BottomActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: label,
          button: true,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: isLoading ? null : onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon),
                        const SizedBox(width: 8)
                      ],
                      Text(label),
                    ],
                  ),
          ),
        ),
      );
}
