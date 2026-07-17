import 'package:flutter/material.dart';

enum AppButtonStyle { primary, accent, outline }

final class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed, this.style = AppButtonStyle.primary, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null ? Text(label) : Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [Text(label), const SizedBox(width: 8), Icon(icon)],
    );
    return switch (style) {
      AppButtonStyle.primary => FilledButton(onPressed: onPressed, child: child),
      AppButtonStyle.accent => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary),
        onPressed: onPressed, child: child,
      ),
      AppButtonStyle.outline => OutlinedButton(onPressed: onPressed, child: child),
    };
  }
}
