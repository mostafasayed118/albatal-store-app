import 'package:al_batal_elite/features/storefront/presentation/widgets/name_and_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../cubit/product_details_cubit.dart';
import '../widgets/add_to_cart_button.dart';
import '../widgets/delivery_info.dart';
import '../widgets/image_gallery.dart';
import '../widgets/product_details_section.dart';
import '../widgets/rating_stars.dart';
import '../widgets/related_card.dart';
import '../widgets/size_guide_sheet.dart';
import '../widgets/variant_selector.dart';
import '../widgets/wishlist_toggle_icon.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.id, CatalogRepository? catalogRepository})
      : _catalogRepository = catalogRepository;

  final String id;
  final CatalogRepository? _catalogRepository;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider(
      create: (_) => ProductDetailsCubit(_catalogRepository ?? getIt<CatalogRepository>())..loadProduct(id),
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        builder: (context, s) {
          final p = s.product;
          if (p == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(p.category),
              actions: [
                WishlistToggleIcon(productId: p.id),
                IconButton(
                  tooltip: l.shareProduct,
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.shareLinkCopied))),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ImageGallery(product: p),
                const SizedBox(height: 20),
                NameAndPrice(product: p),
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 8),
                  RatingStars(product: p),
                ],
                const SizedBox(height: 20),
                VariantSelector(product: p, state: s),
                const SizedBox(height: 20),
                DeliveryInfo(l: l, scheme: scheme),
                if (p.description != null) ...[
                  const SizedBox(height: 20),
                  Text(l.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(p.description!),
                ],
                ProductDetailsSection(product: p, l: l),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => showSizeGuide(context),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: Text(l.sizeGuide),
                ),
                if (s.relatedProducts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(l.relatedProducts,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: s.relatedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => RelatedCard(
                        product: s.relatedProducts[i],
                        onTap: () =>
                            context.push('/product/${s.relatedProducts[i].id}'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
            bottomNavigationBar:
                AddToCartButton(state: s, l: l, scheme: scheme),
          );
        },
      ),
    );
  }
}
