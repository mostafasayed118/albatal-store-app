import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';

/// Tappable action row for fulfillment status transitions.
final class FulfillmentActionTile extends StatelessWidget {
  const FulfillmentActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(context.directionalTrailingIcon),
      onTap: onTap,
    );
  }
}
