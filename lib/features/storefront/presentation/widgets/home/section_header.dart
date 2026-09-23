import 'package:flutter/material.dart';

/// Section header row shared by the home surfaces (title + optional
/// trailing widget). Extracted from `home_page.dart` verbatim (was
/// private `_SectionHeader`).
final class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
