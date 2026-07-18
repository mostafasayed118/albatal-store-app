import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';

/// Bottom sheet with category, color, and price range filters.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.state,
    required this.onApply,
  });

  final CatalogState state;
  final void Function(
      String category, String color, double priceMin, double priceMax) onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String _selectedCategory;
  late String _selectedColor;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.state.category;
    _selectedColor = widget.state.colorFilter;
    final min = widget.state.catalogPriceMin;
    final max = widget.state.catalogPriceMax;
    _priceRange = RangeValues(
      widget.state.priceMin.clamp(min, max),
      widget.state.priceMax.clamp(min, max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final min = state.catalogPriceMin;
    final max = state.catalogPriceMax;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Text(l.filter,
                        style: Theme.of(context).textTheme.titleLarge)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _selectedColor = '';
                      _priceRange = RangeValues(min, max);
                    });
                  },
                  child: Text(l.resetFilters),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.category, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in state.categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _selectedCategory == c,
                    onSelected: (_) => setState(() => _selectedCategory = c),
                  ),
              ],
            ),
            if (state.availableColors.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l.color, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final color in state.availableColors)
                    ChoiceChip(
                      label: Text(color),
                      selected: _selectedColor == color,
                      onSelected: (_) => setState(() {
                        _selectedColor = _selectedColor == color ? '' : color;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l.priceRange, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RangeSlider(
              values: _priceRange,
              min: min,
              max: max,
              divisions: 20,
              labels: RangeLabels(
                money(_priceRange.start.round().toDouble()),
                money(_priceRange.end.round().toDouble()),
              ),
              onChanged: (v) => setState(() => _priceRange = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(money(_priceRange.start.round().toDouble()),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(money(_priceRange.end.round().toDouble()),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                widget.onApply(
                  _selectedCategory,
                  _selectedColor,
                  _priceRange.start,
                  _priceRange.end,
                );
                Navigator.pop(context);
              },
              child: Text(l.applyFilters),
            ),
          ],
        ),
      ),
    );
  }
}
