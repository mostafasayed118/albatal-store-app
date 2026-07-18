import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/products_data.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fabricCategories)),
      body: _CategoryGrid(l10n: l),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.l10n});
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
        : categories.sublist(1);
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
        final p = products.firstWhere(
          (x) => x.category == c,
          orElse: () => products.first,
        );
        final count = products.where((x) => x.category == c).length;
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
                        Text(c,
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
