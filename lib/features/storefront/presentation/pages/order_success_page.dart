import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final id = orderId.trim();
    if (id.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 60, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  // Localized (was a hardcoded English string) and says
                  // what to do next: check the order history.
                  l.orderReferenceMissing,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: l.trackMyOrder,
                  onPressed: () => context.go('/profile/orders'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // One physical tick at the finish line — the only moment a purchase
    // app should physically congratulate the user. [_SuccessBurst] fires
    // it once on entry and plays the check-mark pop.
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _SuccessBurst(),
              const SizedBox(height: 24),
              Text(l.successTitle,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(l.orderPlacedBody, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('#$id',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: scheme.primary)),
              const SizedBox(height: 32),
              AppButton(
                label: l.trackMyOrder,
                onPressed: () => context.go('/profile/orders'),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: l.continueShopping,
                style: AppButtonStyle.outline,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The success check-mark: a quick ease-out-back pop plus a single
/// success haptic on entry. Motion here is earned — it marks the one
/// moment the whole flow was aiming at.
class _SuccessBurst extends StatefulWidget {
  const _SuccessBurst();

  @override
  State<_SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<_SuccessBurst> {
  @override
  void initState() {
    super.initState();
    hapticSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: CircleAvatar(
        radius: 48,
        backgroundColor: scheme.primary,
        child: Icon(Icons.check, size: 60, color: scheme.onPrimary),
      ),
    );
  }
}
