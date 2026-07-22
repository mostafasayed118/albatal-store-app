import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../localization/category_labels.dart';

/// Horizontal scrollable chips showing active filters with "Clear all".
class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({
    super.key,
    required this.state,
    required this.onClearAll,
  });

  final CatalogState state;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    final chips = <Widget>[];

    final locale = Localizations.localeOf(context).toString();
    if (state.category != 'All') {
      chips.add(_filterChip(
        label: localizedCategory(state.category, l),
        onDeleted: () => catalog.select('All'),
      ));
    }
    if (state.colorFilter.isNotEmpty) {
      chips.add(_filterChip(
        label: state.colorFilter,
        onDeleted: () => catalog.setColorFilter(state.colorFilter),
      ));
    }
    if (state.priceMin > Money.zero ||
        state.priceMax < const Money.egp(999999)) {
      chips.add(_filterChip(
        label:
            '${state.priceMin.format(locale: locale, symbol: l.currencyCode)} – ${state.priceMax.format(locale: locale, symbol: l.currencyCode)}',
        onDeleted: () =>
            catalog.setPriceRange(Money.zero, const Money.egp(999999)),
      ));
    }

    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          ...chips,
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: ActionChip(
                label: Text(l.clearAll),
                onPressed: onClearAll,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required VoidCallback onDeleted}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
