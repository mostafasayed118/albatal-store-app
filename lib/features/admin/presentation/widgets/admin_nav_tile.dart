import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// The admin "go to screen" card used on the dashboard and the catalog
/// hub: icon, title, subtitle and the directional trailing chevron.
///
/// Extracted from two verbatim private copies (`_ActionTile` in the
/// dashboard, `_ManagementTile` in the catalog page — audit 2026-09-21,
/// P2 dedupe). The order-detail menu row is deliberately NOT this widget:
/// it is a bare colored ListTile without subtitle, a different construct.
final class AdminNavTile extends StatelessWidget {
  const AdminNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(context.directionalTrailingIcon),
        onTap: onTap,
      ),
    );
  }
}
