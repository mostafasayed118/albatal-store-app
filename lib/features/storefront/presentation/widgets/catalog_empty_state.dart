import 'package:flutter/material.dart';

class CatalogEmptyState extends StatelessWidget {
  const CatalogEmptyState({super.key, required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.search_off_outlined,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('No fabrics found',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Try another search or clear your filters.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('View all fabrics')),
            ],
          ),
        ),
      );
}
