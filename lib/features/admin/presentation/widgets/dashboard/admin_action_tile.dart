import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';

/// Admin dashboard quick-action tile — extracted from
/// `admin_dashboard_page.dart` verbatim (was private `_ActionTile`).
///
/// Public so other admin surfaces can reuse the exact action treatment.
class AdminActionTile extends StatelessWidget {
  const AdminActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
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
