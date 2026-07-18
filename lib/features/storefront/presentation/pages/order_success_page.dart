import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: scheme.primary,
                child: Icon(Icons.check, size: 60, color: scheme.onPrimary),
              ),
              const SizedBox(height: 24),
              Text(l.successTitle,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(l.orderPlacedBody, textAlign: TextAlign.center),
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
