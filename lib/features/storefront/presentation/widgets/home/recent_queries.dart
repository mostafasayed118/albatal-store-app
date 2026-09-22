import 'package:flutter/material.dart';

/// Recent-search chips shown under the home search bar.
///
/// Extracted from `home_page.dart` verbatim — renders nothing when the
/// query is non-empty or there is no history (the caller guards both).
final class HomeRecentQueries extends StatelessWidget {
  const HomeRecentQueries({
    super.key,
    required this.queries,
    required this.onDelete,
  });

  final List<String> queries;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final q in queries)
          Chip(
            label: Text(q),
            avatar: const Icon(Icons.history, size: 16),
            onDeleted: () => onDelete(q),
            deleteIcon: const Icon(Icons.close, size: 14),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
