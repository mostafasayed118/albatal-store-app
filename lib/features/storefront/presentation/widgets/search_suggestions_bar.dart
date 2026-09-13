import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// Pure client-side suggestion matcher (feature-batch §7): case-
/// insensitive substring over product names, best (earliest) match
/// first, exact matches dropped, capped at [limit]. Server-side
/// fuzzy suggestions land via the `search_suggestions` RPC proposal;
/// this fallback keeps the feature alive before migrations apply.
List<String> suggestProductNames(
  List<Product> products,
  String query, {
  int limit = 5,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final scored = <({String name, int index})>[];
  for (final p in products) {
    final name = p.name;
    final lower = name.toLowerCase();
    if (lower == q) continue; // an exact match IS the search result
    final index = lower.indexOf(q);
    if (index != -1) scored.add((name: name, index: index));
  }
  scored.sort(((a, b) {
    final byIndex = a.index.compareTo(b.index);
    return byIndex != 0 ? byIndex : a.name.compareTo(b.name);
  }));
  return scored.take(limit).map((s) => s.name).toList();
}

/// Chip row shown under the catalog search bar: recent searches when
/// the query is empty, live name suggestions while typing.
class SearchSuggestionsBar extends StatelessWidget {
  const SearchSuggestionsBar({
    super.key,
    required this.label,
    required this.terms,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final List<String> terms;
  final ValueChanged<String> onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ),
              if (onClear != null)
                TextButton(
                  onPressed: onClear,
                  child: Text(l.clearRecent),
                ),
            ],
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: terms.length,
              itemBuilder: (context, i) => ActionChip(
                label: Text(terms[i]),
                onPressed: () => onPick(terms[i]),
              ),
              separatorBuilder: (context, i) => const SizedBox(width: 8),
            ),
          ),
        ],
      ),
    );
  }
}
