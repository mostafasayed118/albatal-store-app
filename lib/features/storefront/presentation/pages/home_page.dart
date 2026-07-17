import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Good morning, Ahmed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                'AL BATAL ELITE',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.15),
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.dark_mode_outlined)),
          ],
        ),
        body: BlocBuilder<CatalogCubit, CatalogState>(
          builder: (context, state) {
            final catalog = context.read<CatalogCubit>();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: catalog.updateQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search exquisite fabrics',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.query.isEmpty
                        ? const Icon(Icons.mic)
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              catalog.updateQuery('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 170,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF16735B)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW SILK COLLECTION',
                        style: TextStyle(color: Color(0xFFFFD58E), fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.05),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Woven for distinction',
                        style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w700, height: 1.15),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                        onPressed: () => context.go('/categories'),
                        child: const Text('Explore collection'),
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
                    Text('Flash Sale', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text(
                      '${(state.saleSeconds ~/ 3600).toString().padLeft(2, '0')}:'
                      '${((state.saleSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
                      '${(state.saleSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FlashSaleCard(product: products.first),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('Popular products', style: Theme.of(context).textTheme.titleLarge)),
                    PopupMenuButton<CatalogSort>(
                      tooltip: 'Sort products',
                      initialValue: state.sort,
                      onSelected: catalog.selectSort,
                      itemBuilder: (_) => CatalogSort.values
                          .map((sort) => PopupMenuItem(value: sort, child: Text(sort.label)))
                          .toList(),
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 18),
                        label: Text(state.sort.label),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${state.visible.length} fabric${state.visible.length == 1 ? '' : 's'} found'),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (_, index) => ProductTile(state.visible[index]),
                  ),
              ],
            );
          },
        ),
      );
}
