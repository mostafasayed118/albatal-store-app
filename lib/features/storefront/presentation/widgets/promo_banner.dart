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
    );
  }
}
