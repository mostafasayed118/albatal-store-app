import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/responsive_scaffold.dart';
import '../../../../shared/components/scrollable_center.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// Guard-rejection body for an unsafe checkout URL.
///
/// Extracted from `paymob_checkout_page.dart` (was private
/// `_InvalidCheckoutBody`).
class InvalidCheckoutBody extends StatelessWidget {
  const InvalidCheckoutBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(title: Text(context.l10n.completePayment)),
      body: ScrollableCenter(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(
              context.l10n.invalidCheckoutLink,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: Text(context.l10n.returnToPayment),
            ),
          ],
        ),
      ),
    );
  }
}
