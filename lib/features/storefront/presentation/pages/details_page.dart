import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import '../cubit/products_data.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/price_text.dart';
import '../widgets/product_image_placeholder.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/wishlist_toggle_icon.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final p =
        products.firstWhere((x) => x.id == id, orElse: () => products.first);
    final related = products
        .where((x) => x.category == p.category && x.id != p.id)
        .toList();

    return BlocProvider(
      create: (_) => ProductDetailsCubit(),
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        builder: (context, s) {
          final stock = p.stockFor(s.color, s.length);
          return Scaffold(
            appBar: AppBar(
              title: Text(p.category),
              actions: [
                WishlistToggleIcon(productId: p.id),
                IconButton(
                  tooltip: l.shareProduct,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.shareLinkCopied))),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Image Gallery ──
                _ImageGallery(product: p),
                const SizedBox(height: 20),

                // ── Name + Price ──
                Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PriceText(
                      p.price,
                      style: TextStyle(
                          fontSize: 22,
                          color: scheme.primary,
                          fontWeight: FontWeight.bold),
                      showStrikeThrough: p.oldPrice != null,
                      strikeThroughAmount: p.oldPrice,
                    ),
                    if (p.discountPercent != null) ...[
                      const SizedBox(width: 8),
                      Chip(label: Text(l.discountPercent(p.discountPercent!))),
                    ],
                  ],
                ),

                // ── Rating ──
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < p.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: scheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${p.rating}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                      Text(' (${p.reviewCount})',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // ── Color ──
                Text(l.color, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: p.colors
                      .map((x) => ChoiceChip(
                            label: Text(x),
                            selected: s.color == x,
                            onSelected: (_) =>
                                context.read<ProductDetailsCubit>().color(x),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // ── Length + Stock ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.length,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: p.sizes
                                .map((x) => ChoiceChip(
                                      label: Text(x),
                                      selected: s.length == x,
                                      onSelected: (_) => context
                                          .read<ProductDetailsCubit>()
                                          .length(x),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StockBadge(stock: stock, l: l),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Quantity ──
                Row(
                  children: [
                    Text(l.quantity,
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    QuantityStepper(
                      quantity: s.quantity,
                      onChanged: (v) =>
                          context.read<ProductDetailsCubit>().quantity(v),
                      max: stock,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Delivery info ──
                _InfoCard(
                  icon: Icons.local_shipping_outlined,
                  title: l.expressDelivery,
                  subtitle: l.expressDeliveryBody,
                  color: scheme.primary,
                ),
                const SizedBox(height: 8),
                _InfoCard(
                  icon: Icons.replay_outlined,
                  title: l.returns,
                  subtitle: l.returnsBody,
                  color: scheme.secondary,
                ),
                const SizedBox(height: 20),

                // ── Description ──
                if (p.description != null) ...[
                  Text(l.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(p.description!),
                ],

                // ── Details (composition, origin) ──
                if (p.composition != null || p.origin != null) ...[
                  const SizedBox(height: 20),
                  Text(l.details,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (p.composition != null)
                    _InfoRow(
                        icon: Icons.science_outlined,
                        label: l.composition,
                        value: p.composition!),
                  if (p.origin != null)
                    _InfoRow(
                        icon: Icons.place_outlined,
                        label: l.origin,
                        value: p.origin!),
                ],

                // ── Care ──
                if (p.care != null) ...[
                  const SizedBox(height: 20),
                  Text(l.care,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(p.care!),
                ],

                // ── Size Guide ──
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _showSizeGuide(context),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: Text(l.sizeGuide),
                ),

                // ── Related Products ──
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(l.relatedProducts,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: related.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _RelatedCard(
                        product: related[i],
                        onTap: () =>
                            context.push('/product/${related[i].id}'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: stock > 0 ? l.addToCart : l.outOfStock,
              icon: Icons.shopping_bag_outlined,
              backgroundColor: stock > 0 ? scheme.secondary : scheme.outline,
              onPressed: stock > 0
                  ? () {
                      context.read<CartCubit>().add(p,
                          color: s.color,
                          length: s.length,
                          quantity: s.quantity);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.addedToCart)));
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  void _showSizeGuide(BuildContext context) {
    final l = context.l10n;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.sizeGuide,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: .3)),
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2.5),
              },
              children: [
                _tableHeader(l.length, l.width, l.bestFor, context),
                _tableRow('1m', '110 cm', l.sizeGuide1m, context),
                _tableRow('2m', '110 cm', l.sizeGuide2m, context),
                _tableRow('5m', '110 cm', l.sizeGuide5m, context),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image Gallery ──────────────────────────────────────────────────

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.product});
  final Product product;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _current = 0;
  late final List<String> _allImages;

  @override
  void initState() {
    super.initState();
    _allImages = [
      if (widget.product.imageAsset != null) widget.product.imageAsset!,
      ...widget.product.images.where((i) => i != widget.product.imageAsset),
    ];
    if (_allImages.isEmpty) _allImages.add('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: _allImages.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _showZoomed(context, i),
              child: ProductImagePlaceholder(
                imageColor: widget.product.imageColor,
                imageAsset: _allImages[i].isEmpty ? null : _allImages[i],
                constraints: const BoxConstraints.expand(height: 300),
                size: 80,
              ),
            ),
          ),
        ),
        if (_allImages.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _allImages.length,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _current
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showZoomed(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ZoomGallery(
          images: _allImages,
          initialIndex: initialIndex,
          imageColor: widget.product.imageColor,
        ),
      ),
    );
  }
}

// ─── Zoom Gallery ───────────────────────────────────────────────────

class _ZoomGallery extends StatefulWidget {
  const _ZoomGallery({
    required this.images,
    required this.initialIndex,
    required this.imageColor,
  });
  final List<String> images;
  final int initialIndex;
  final int imageColor;

  @override
  State<_ZoomGallery> createState() => _ZoomGalleryState();
}

class _ZoomGalleryState extends State<_ZoomGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: widget.images[i].isEmpty
                ? Icon(Icons.texture,
                    color: Colors.white.withValues(alpha: .5), size: 120)
                : Image.asset(widget.images[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─── Stock Badge ────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock, required this.l});
  final int stock;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    String text;
    if (stock == 0) {
      color = scheme.error;
      text = l.outOfStock;
    } else if (stock <= 3) {
      color = scheme.error;
      text = l.onlyLeft(stock);
    } else if (stock <= 10) {
      color = scheme.secondary;
      text = l.inStock;
    } else {
      color = scheme.primary;
      text = l.inStock;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ─── Info Card ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: .08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

// ─── Info Row ───────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: '$label: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface),
                  children: [
                    TextSpan(
                      text: value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Related Card ───────────────────────────────────────────────────

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProductImagePlaceholder(
                  imageColor: product.imageColor,
                  imageAsset: product.imageAsset,
                  constraints: const BoxConstraints.expand(),
                  size: 36,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600)),
                    Text(money(product.price),
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.primary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Table Helpers ──────────────────────────────────────────────────

TableRow _tableHeader(String c1, String c2, String c3, BuildContext ctx) =>
    TableRow(
      decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: .3)),
      children: [_cell(c1, bold: true), _cell(c2, bold: true), _cell(c3, bold: true)],
    );

TableRow _tableRow(String c1, String c2, String c3, BuildContext ctx) =>
    TableRow(children: [_cell(c1), _cell(c2), _cell(c3)]);

Widget _cell(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text,
          style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
    );
