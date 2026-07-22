import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback_view.dart';
import '../cubit/catalog_cubit.dart';
import '../localization/category_labels.dart';

/// Grid of category tiles with image backgrounds.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final l = l10n;
    final scheme = Theme.of(context).colorScheme;
    final catalog = context.watch<CatalogCubit>();
    final state = catalog.state;

    if (state.status == CatalogStatus.loading ||
        state.status == CatalogStatus.initial) {
      return const FeedbackView(type: FeedbackViewType.loading);
    }
    if (state.status == CatalogStatus.error) {
      return FeedbackView(
        type: FeedbackViewType.error,
        onAction: catalog.load,
      );
    }

    final cats = state.categories.length > 1
        ? state.categories.sublist(1)
        : const <String>['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];
    final catCounts = state.categoryProductCount;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (_, i) {
        final c = cats[i];
        final matching = state.allProducts.where((x) => x.category == c);
        if (matching.isEmpty) return const SizedBox.shrink();
        final p = matching.first;
        final count = catCounts[c] ?? 0;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            catalog.select(c);
            context.go('/catalog');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(color: Color(p.imageColor)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (p.imageAsset != null)
                    Image.asset(p.imageAsset!, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: .15),
                          Colors.black.withValues(alpha: .55),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(localizedCategory(c, l),
                            style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Text(l.curatedFabrics(count),
                            style: TextStyle(
                                color: scheme.onPrimary.withValues(alpha: .7))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
