import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/money_copy.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/services/connectivity_gate.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/services/product_share_service.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/services/whatsapp_share_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/recently_viewed_store.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import '../widgets/add_to_cart_button.dart';
import '../widgets/back_in_stock_toggle.dart';
import '../widgets/delivery_info.dart';
import '../widgets/image_gallery.dart';
import '../widgets/name_and_price.dart';
import '../widgets/offline_catalog_view.dart';
import '../widgets/product_details_section.dart';
import '../widgets/rating_stars.dart';
import '../widgets/related_card.dart';
import '../widgets/reviews_section.dart';
import '../widgets/size_guide_sheet.dart';
import '../widgets/variant_selector.dart';
import '../widgets/wishlist_toggle_icon.dart';

/// Product details. All dependencies are constructor-injected (audit
/// P1): the router resolves them at the composition root, widget tests
/// pass fakes directly. The optional [gate] (Task #8) lets the cubit
/// tag offline loads so a network-miss while offline shows the
/// friendly notice instead of a hard error.
class DetailsPage extends StatelessWidget {
  const DetailsPage({
    super.key,
    required this.id,
    required CatalogRepository catalogRepository,
    required this.whatsappShareService,
    required this.shareService,
    this.reviewsRepository,
    this.recentlyViewed,
    this.imageCompressor,
    ConnectivityGate? gate,
  })  : _catalogRepository = catalogRepository,
        _gate = gate;

  final String id;
  final CatalogRepository _catalogRepository;
  final ConnectivityGate? _gate;

  /// #13: WhatsApp-first share service (wa.me universal link), resolved
  /// at the composition root — the page never service-locates.
  final WhatsAppShareService whatsappShareService;

  /// §5: generic platform share sheet, the fallback next to the
  /// WhatsApp-first option. Required, resolved at the composition root —
  /// the view never service-locates (audit DIP: no getIt in views);
  /// widget tests pass a no-op fake.
  final ShareService shareService;

  /// §9: approved customer reviews. Null (pre-DI widget tests, or the
  /// 050 migration not yet registered) hides the reviews section —
  /// the page never breaks.
  final ReviewsRepository? reviewsRepository;

  /// §4 review-photo compression, resolved at the composition root.
  /// Null (pre-DI widget tests) falls back to the uncompressed bytes.
  final ImageCompressor? imageCompressor;

  /// #3: app-scoped recently-viewed store. Null in widget tests that
  /// pump the page pre-DI (fail-soft).
  final RecentlyViewedStore? recentlyViewed;

  /// #13: WhatsApp-first share — localized prefill (name + price + deep
  /// link) handed to the wa.me universal link. A launch that no external
  /// app takes must still acknowledge the tap: the shared floating-error
  /// helper (never a raw snackbar), mirroring the Support page pattern.
  Future<void> _shareOnWhatsApp(BuildContext context, Product p) async {
    final launched = await whatsappShareService.share(context.l10n
        .whatsappShareProductMessage(
            p.name, moneyText(context.l10n, p.price), productUrl(p.id)));
    if (!launched && context.mounted) {
      showFloatingError(context, context.l10n.couldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider(
      // #3: record the view into the app-scoped store injected at the
      // composition root; null in widget tests that pump pre-DI.
      create: (_) => ProductDetailsCubit(
        _catalogRepository,
        gate: _gate,
        recentlyViewed: recentlyViewed,
      )..loadProduct(id),
      // Outer builder covers status/product/related only: color/length/
      // quantity ticks rebuild the selector + CTA below, never the
      // gallery or the related strip.
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.product != current.product ||
            previous.relatedProducts != current.relatedProducts,
        builder: (context, s) {
          final p = s.product;
          if (s.status == DetailsStatus.loading ||
              s.status == DetailsStatus.initial) {
            return const Scaffold(
              body: FeedbackView(type: FeedbackViewType.loading),
            );
          }
          if (s.status == DetailsStatus.notFound) {
            return Scaffold(
              appBar: AppBar(),
              body: FeedbackView(
                type: FeedbackViewType.empty,
                // Deep links can point at retired products; say so and
                // offer the way back (was a bare "no results" text).
                icon: Icons.search_off,
                title: l.noResultsFound,
                body: l.emptyBody,
                actionLabel: l.returnHome,
                onAction: () => context.go(Routes.home),
              ),
            );
          }
          if (s.status == DetailsStatus.error) {
            return Scaffold(
              appBar: AppBar(),
              // Task #8: a failed probe while offline is a cache miss,
              // not a product error — offer the offline notice + retry.
              body: s.isOffline
                  ? OfflineCatalogView(
                      onRetry: () =>
                          context.read<ProductDetailsCubit>().loadProduct(id))
                  : FeedbackView(
                      type: FeedbackViewType.error,
                      onAction: () =>
                          context.read<ProductDetailsCubit>().loadProduct(id),
                    ),
            );
          }
          if (p == null) {
            return const Scaffold(
              body: FeedbackView(type: FeedbackViewType.error),
            );
          }
          return Scaffold(
            appBar: AppBar(
              // Product name beats a category label for in-page context
              // (UX-047); long names ellipsize instead of wrapping.
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                WishlistToggleIcon(productId: p.id),
                // #13: WhatsApp-first — the direct option leads, generic
                // share sheet stays as the fallback.
                IconButton(
                  tooltip: l.whatsappShareProduct,
                  onPressed: () => unawaited(_shareOnWhatsApp(context, p)),
                  icon: const Icon(Icons.chat_outlined),
                ),
                IconButton(
                  tooltip: l.shareProduct,
                  onPressed: () => unawaited(shareService.shareText(
                      l.shareProductMessage(p.name, productUrl(p.id)))),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                // Stitch gallery card (spec §4): media clipped to the 16dp
                // card radius so page-view edges never escape the card.
                ClipRRect(
                  borderRadius: AppTheme.cardRadius,
                  child: ImageGallery(product: p),
                ),
                const SizedBox(height: 20),
                NameAndPrice(product: p),
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 8),
                  RatingStars(product: p),
                ],
                // §9: approved customer reviews + submit affordance.
                const SizedBox(height: 8),
                ReviewsSection(
                  productId: p.id,
                  repository: reviewsRepository,
                  imageCompressor: imageCompressor,
                ),
                const SizedBox(height: 20),
                // Selection-only rebuild: variant/quantity ticks must not
                // replay the gallery or related builders above.
                BlocBuilder<ProductDetailsCubit, DetailsState>(
                  buildWhen: (previous, current) =>
                      previous.product != current.product ||
                      previous.color != current.color ||
                      previous.length != current.length ||
                      previous.quantity != current.quantity,
                  builder: (context, vs) =>
                      VariantSelector(product: p, state: vs),
                ),
                // Task #5: when the selected variant is out of stock, offer
                // the back-in-stock alert toggle (product-level opt-in).
                BlocBuilder<ProductDetailsCubit, DetailsState>(
                  buildWhen: (previous, current) =>
                      previous.product != current.product ||
                      previous.stock != current.stock,
                  builder: (context, vs) => vs.product != null && vs.stock <= 0
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(top: 8),
                          child: BackInStockToggle(product: p),
                        )
                      : const SizedBox.shrink(),
                ),
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
                const SizedBox(height: 12),
                // Wave C: swatch/sample ordering — adds a flagged sample
                // line to the cart; the checkout flow prices it (server
                // enforcement pending in supabase/).
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<CartCubit>().addSample(p, color: s.color);
                    showConfirmation(context, l.sampleAdded);
                  },
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: Text(l.orderSample),
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
                        onTap: () => context
                            .push(Routes.product(s.relatedProducts[i].id)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
            bottomNavigationBar: BlocBuilder<ProductDetailsCubit, DetailsState>(
              buildWhen: (previous, current) =>
                  previous.product != current.product ||
                  previous.color != current.color ||
                  previous.length != current.length ||
                  previous.quantity != current.quantity,
              builder: (context, cs) =>
                  AddToCartButton(state: cs, l: l, scheme: scheme),
            ),
          );
        },
      ),
    );
  }
}
