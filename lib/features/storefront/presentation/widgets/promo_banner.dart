import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// Gradient promotional banner for the new silk collection.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      // Stitch hero contract: 180dp (spec §4 StitchHeroCarousel).
      height: 180,
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.secondaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.05),
          ),
          const SizedBox(height: 8),
          Text(
            l.wovenForDistinction,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: scheme.onPrimary, height: 1.15),
          ),
          const Spacer(),
          AppButton(
            label: l.exploreCollection,
            style: AppButtonStyle.accent,
            onPressed: () => context.go('/categories'),
          ),
        ],
      ),
    );
  }
}
