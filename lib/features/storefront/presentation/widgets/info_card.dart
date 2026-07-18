import 'package:flutter/material.dart';

/// Card with icon, title, and subtitle for delivery/returns info.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: .08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
