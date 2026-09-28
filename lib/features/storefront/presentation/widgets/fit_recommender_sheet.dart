import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../domain/fit/fit_recommendation.dart';
import '../cubit/product_details_cubit.dart';

/// Fit recommender bottom sheet (Batch 3 #2 tailor): "how much fabric
/// do I need?" Garment + height in, recommended meters out, with Apply
/// writing the recommendation straight into the details selection —
/// a metered cut via [ProductDetailsCubit.setCutLength], the nearest
/// fixed size via [ProductDetailsCubit.length]. Client-only; the
/// yardage table lives in [fit_recommendation.dart].
Future<void> showFitRecommender(BuildContext context, Product product) {
  // The sheet opens on a modal route above the PDP subtree, so the
  // page-level ProductDetailsCubit would be invisible inside it.
  // Capture the cubit up front and re-provide it below the modal.
  final cubit = context.read<ProductDetailsCubit>();
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: FitRecommenderSheet(product: product),
    ),
  );
}

class FitRecommenderSheet extends StatefulWidget {
  const FitRecommenderSheet({super.key, required this.product});
  final Product product;

  @override
  State<FitRecommenderSheet> createState() => _FitRecommenderSheetState();
}

class _FitRecommenderSheetState extends State<FitRecommenderSheet> {
  FitGarment _garment = FitGarment.thobe;
  double _heightCm = kFitReferenceHeightCm;

  String _garmentLabel(AppLocalizations l, FitGarment garment) => switch (
        garment) {
        FitGarment.trousers => l.garmentTrousers,
        FitGarment.shirt => l.garmentShirt,
        FitGarment.abaya => l.garmentAbaya,
        FitGarment.thobe => l.garmentThobe,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final meters = recommendedMeters(
      _garment,
      heightCm: _heightCm,
      widthCm: widget.product.widthCm,
    );
    final applyLength = fitApplyLength(widget.product, meters);
    final metersText = '${meters.toStringAsFixed(1)} m';
    return SingleChildScrollView(
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
          Text(l.fitFinder, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(l.fitGarment, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FitGarment.values
                .map((g) => ChoiceChip(
                      label: Text(_garmentLabel(l, g)),
                      selected: _garment == g,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _garment = g),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(l.fitHeight, style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              IconButton(
                tooltip: l.fitHeight,
                onPressed: () => setState(() => _heightCm =
                    (_heightCm - kFitHeightStepCm)
                        .clamp(kFitMinHeightCm, kFitMaxHeightCm)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${_heightCm.toStringAsFixed(0)} cm'),
              IconButton(
                tooltip: l.fitHeight,
                onPressed: () => setState(() => _heightCm =
                    (_heightCm + kFitHeightStepCm)
                        .clamp(kFitMinHeightCm, kFitMaxHeightCm)),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.fitYouNeed(metersText),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (isNarrowRoll(widget.product.widthCm))
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Text(
                l.fitNarrowNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: applyLength == null
                  ? null
                  : () {
                      final cubit = context.read<ProductDetailsCubit>();
                      if (widget.product.sellByLength) {
                        cubit.setCutLength(meters);
                      } else {
                        cubit.length(applyLength);
                      }
                      Navigator.pop(context);
                    },
              child: Text(l.fitApply(metersText)),
            ),
          ),
        ],
      ),
    );
  }
}
