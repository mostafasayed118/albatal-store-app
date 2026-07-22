import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/flash_sale_card.dart';

/// Flash sale section with countdown timer and product card.
///
/// Manages its own 1-second timer for the countdown instead of driving
/// the catalog cubit's state. This prevents the entire catalog list from
/// rebuilding every second — only this widget rebuilds on each tick.
class FlashSaleSection extends StatefulWidget {
  const FlashSaleSection({super.key, required this.state});
  final CatalogState state;

  @override
  State<FlashSaleSection> createState() => _FlashSaleSectionState();
}

class _FlashSaleSectionState extends State<FlashSaleSection> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.state.saleSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining = (_secondsRemaining - 1).clamp(0, 999999);
      });
    });
  }

  @override
  void didUpdateWidget(covariant FlashSaleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if the parent provides a completely different state (e.g. after
    // a full catalog reload). Only reset if the new state is fresher.
    if (widget.state.saleSeconds > _secondsRemaining) {
      _secondsRemaining = widget.state.saleSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hours = _secondsRemaining ~/ 3600;
    final minutes = (_secondsRemaining % 3600) ~/ 60;
    final seconds = _secondsRemaining % 60;
    final flashProduct = widget.state.allProducts.isNotEmpty
        ? widget.state.allProducts.first
        : null;
    return Column(
      children: [
        Row(
          children: [
            Text(l.flashSale, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Text(
              '${hours.toString().padLeft(2, '0')}:'
              '${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: scheme.secondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (flashProduct != null) FlashSaleCard(product: flashProduct),
      ],
    );
  }
}
