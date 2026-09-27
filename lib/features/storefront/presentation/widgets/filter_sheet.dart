import 'package:flutter/material.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/money_copy.dart';
import '../../domain/entities/catalog_filters.dart';
import '../catalog_color_label.dart';
import '../catalog_fabric_label.dart';
import '../cubit/catalog_cubit.dart';
import 'color_swatches.dart';

/// Bottom sheet with category, color, price range, and fabric filters.
///
/// The price range slider operates in major units (EGP) because
/// [RangeSlider] requires `double` values. Conversion to [Money]
/// happens at the boundary when [onApply] fires.
///
/// Fabric facets (weight / width / fabric / availability / rating) commit
/// through the same [onApply] call as named parameters so the sheet keeps
/// one draft → one commit, like category/color/price.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.state,
    required this.onApply,
  });

  final CatalogState state;
  final void Function({
    required String category,
    required String color,
    required Money priceMin,
    required Money priceMax,
    required FabricWeight weight,
    required FabricWidth width,
    required String fabricKeyword,
    required bool inStockOnly,
    required bool sellByLengthOnly,
    required double minRating,
  }) onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String _selectedCategory;
  late String _selectedColor;
  late RangeValues _priceRange;
  late FabricWeight _weight;
  late FabricWidth _width;
  late String _fabricKeyword;
  late bool _inStockOnly;
  late bool _sellByLengthOnly;
  late double _minRating;

  /// Rating chips offered in the sheet. Numerals need no localization
  /// (ratings render as digits everywhere, including product cards).
  static const _ratingOptions = [0.0, 3.0, 4.0, 4.5];

  @override
  void initState() {
    super.initState();
    final filters = widget.state.filters;
    _selectedCategory = filters.category;
    _selectedColor = filters.colorFilter;
    final min = widget.state.catalogPriceMin.majorUnits;
    final max = widget.state.catalogPriceMax.majorUnits;
    _priceRange = RangeValues(
      widget.state.filters.priceMin.majorUnits.clamp(min, max),
      widget.state.filters.priceMax.majorUnits.clamp(min, max),
    );
    // `unspecified` means "unknown data", never a shopper choice — seed
    // the draft as Any so reopening the sheet shows a clean facet row.
    _weight = filters.weight == FabricWeight.unspecified
        ? FabricWeight.any
        : filters.weight;
    _width = filters.width == FabricWidth.unspecified
        ? FabricWidth.any
        : filters.width;
    _fabricKeyword = filters.fabricKeyword;
    _inStockOnly = filters.inStockOnly;
    _sellByLengthOnly = filters.sellByLengthOnly;
    _minRating = filters.minRating;
  }

  void _resetDraft(double min, double max) {
    setState(() {
      _selectedCategory = 'All';
      _selectedColor = '';
      _priceRange = RangeValues(min, max);
      _weight = FabricWeight.any;
      _width = FabricWidth.any;
      _fabricKeyword = '';
      _inStockOnly = false;
      _sellByLengthOnly = false;
      _minRating = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final min = state.catalogPriceMin.majorUnits;
    final max = state.catalogPriceMax.majorUnits;

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
                  onPressed: () => _resetDraft(min, max),
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
                    // Category/fabric-family names stay in their source
                    // spelling — data-driven proper nouns (audit 2026-09-21
                    // M-03: translate-or-document; this is the documented
                    // decision). Colors DO translate below.
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
                      // Same fabric-color dot as the PDP variant chips, so
                      // the filter sheet and product page speak one visual
                      // language for colors.
                      avatar: ColorSwatchDot(name: color),
                      label: Text(catalogColorLabel(l, color)),
                      selected: _selectedColor == color,
                      onSelected: (_) => setState(() {
                        _selectedColor = _selectedColor == color ? '' : color;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l.fabricWeight,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in FabricWeight.values)
                  if (w != FabricWeight.unspecified)
                    ChoiceChip(
                      label: Text(fabricWeightLabel(l, w)),
                      selected: _weight == w,
                      onSelected: (_) => setState(() {
                        _weight = _weight == w ? FabricWeight.any : w;
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.fabricWidth, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in FabricWidth.values)
                  if (w != FabricWidth.unspecified)
                    ChoiceChip(
                      label: Text(fabricWidthLabel(l, w)),
                      selected: _width == w,
                      onSelected: (_) => setState(() {
                        _width = _width == w ? FabricWidth.any : w;
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.fabricType, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                // Curated keyword vocabulary (FabricFinder.keywords) matched
                // against product compositions. Source spelling, like
                // category names — data-driven, documented, not ARB keys.
                for (final keyword in FabricFinder.keywords)
                  ChoiceChip(
                    label: Text(keyword),
                    selected:
                        _fabricKeyword.toLowerCase() == keyword.toLowerCase(),
                    onSelected: (_) => setState(() {
                      _fabricKeyword =
                          _fabricKeyword.toLowerCase() == keyword.toLowerCase()
                              ? ''
                              : keyword;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text(l.inStockOnly),
                  selected: _inStockOnly,
                  onSelected: (v) => setState(() => _inStockOnly = v),
                ),
                FilterChip(
                  label: Text(l.sellByLengthOnly),
                  selected: _sellByLengthOnly,
                  onSelected: (v) => setState(() => _sellByLengthOnly = v),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.minRating, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final rating in _ratingOptions)
                  ChoiceChip(
                    label: Text(rating == 0
                        ? l.filterAny
                        : '${rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 1)}+'),
                    selected: _minRating == rating,
                    onSelected: (_) => setState(() => _minRating = rating),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.priceRange, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Degenerate catalog (single price or empty): RangeSlider
            // asserts min < max, so show the fixed price instead of a
            // slider that can never move.
            if (max <= min)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  moneyText(l, Money.egp(min.round())),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              RangeSlider(
                values: _priceRange,
                min: min,
                max: max,
                divisions: 20,
                labels: RangeLabels(
                  moneyText(l, Money.egp(_priceRange.start.round())),
                  moneyText(l, Money.egp(_priceRange.end.round())),
                ),
                onChanged: (v) => setState(() => _priceRange = v),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(moneyText(l, Money.egp(_priceRange.start.round())),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(moneyText(l, Money.egp(_priceRange.end.round())),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                widget.onApply(
                  category: _selectedCategory,
                  color: _selectedColor,
                  priceMin: Money.egp(_priceRange.start.round()),
                  priceMax: Money.egp(_priceRange.end.round()),
                  weight: _weight,
                  width: _width,
                  fabricKeyword: _fabricKeyword,
                  inStockOnly: _inStockOnly,
                  sellByLengthOnly: _sellByLengthOnly,
                  minRating: _minRating,
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
