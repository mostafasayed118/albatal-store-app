import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/products_data.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/flash_sale_card.dart';
import '../widgets/product_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.goodMorning('Ahmed'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: .6))),
            Text(
              l.brandName,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                  color: scheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.openSettings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          final catalog = context.read<CatalogCubit>();
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                onChanged: catalog.updateQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchFabrics,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.query.isEmpty
                      ? IconButton(
                          tooltip: l.voiceSearch,
                          onPressed: () {},
                          icon: const Icon(Icons.mic),
                        )
                      : IconButton(
                          tooltip: l.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            catalog.updateQuery('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
              ),
              if (state.query.isEmpty && state.recentQueries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final q in state.recentQueries)
                      Chip(
                        label: Text(q),
                        avatar: const Icon(Icons.history, size: 16),
                        onDeleted: () => catalog.deleteRecentQuery(q),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                height: 170,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: .75),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.newSilkCollection,
                      style: TextStyle(
                          color: scheme.secondary.withValues(alpha: .9),
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.05),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.wovenForDistinction,
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontFamily: 'Montserrat',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.15),
                    ),
                    const Spacer(),
                    AppButton(
                      label: l.exploreCollection,
                      style: AppButtonStyle.accent,
                      onPressed: () => context.go('/categories'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories
                      .map((category) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: state.category == category,
                              onSelected: (_) => catalog.select(category),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(l.flashSale,
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '${(state.saleSeconds ~/ 3600).toString().padLeft(2, '0')}:'
                    '${((state.saleSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
                    '${(state.saleSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                        color: scheme.secondary,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FlashSaleCard(product: products.first),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: Text(l.popularProducts,
                          style: Theme.of(context).textTheme.titleLarge)),
                  PopupMenuButton<CatalogSort>(
                    tooltip: l.sortProducts,
                    initialValue: state.sort,
                    onSelected: catalog.selectSort,
                    itemBuilder: (_) => CatalogSort.values
                        .map((sort) => PopupMenuItem(
                            value: sort, child: Text(sort.label)))
                        .toList(),
                    child: Chip(
                      avatar: const Icon(Icons.sort, size: 18),
                      label: Text(state.sort.label),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.fabricsFound(state.visible.length)),
              const SizedBox(height: 12),
              if (state.visible.isEmpty)
                CatalogEmptyState(
                  onClear: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.visible.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, index) =>
                      ProductTile(state.visible[index]),
                ),
            ],
          );
        },
      ),
    );
  }
}
