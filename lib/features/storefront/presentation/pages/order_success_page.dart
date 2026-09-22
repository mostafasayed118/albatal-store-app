import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/services/notification_service.dart';
import '../widgets/success_burst.dart';

class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage(
      {super.key, required this.orderId, this.notificationService});
  final String orderId;

  /// §12: local order confirmation, resolved at the composition root.
  /// Null (pre-DI widget tests) degrades to [NoOpNotificationService].
  final NotificationService? notificationService;

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

final class _OrderSuccessPageState extends State<OrderSuccessPage> {
  @override
  void initState() {
    super.initState();
    // §12: local order confirmation. The service itself is gated by the
    // user's notification opt-in and fails silently when unavailable.
    final notifications =
        widget.notificationService ?? const NoOpNotificationService();
    notifications.showOrderNotification(
      title: 'Al Batal Elite',
      body: 'Order #${widget.orderId} confirmed',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final id = widget.orderId.trim();
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
                  onPressed: () => context.go(Routes.orders),
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
              const SuccessBurst(),
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
                onPressed: () => context.go(Routes.orders),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: l.continueShopping,
                style: AppButtonStyle.outline,
                onPressed: () => context.go(Routes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
