import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/category_chips.dart';
import '../widgets/flash_sale_section.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/popular_products_section.dart';
import '../widgets/promo_banner.dart';

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
              HomeSearchBar(controller: _searchController, state: state),
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const PromoBanner(),
              const SizedBox(height: 24),
              CategoryChips(state: state),
              const SizedBox(height: 24),
              FlashSaleSection(state: state),
              const SizedBox(height: 24),
              PopularProductsSection(
                state: state,
                onClearFilters: () {
                  _searchController.clear();
                  catalog.clearFilters();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
