import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../storefront/presentation/cubit/cart_cubit.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_service.dart';
import '../../domain/paymob_url_guard.dart';
import '../cubit/payment_cubit.dart';

/// Payment method selection page.
///
/// SECURITY NOTE: on payment success this page navigates to
/// the order-success screen and clears the local cart. It
/// does NOT call `OrdersCubit.place()` — the canonical order
/// was already created server-side by the `create_checkout_order`
/// RPC before payment initiation, and the customer's order
/// history is read from the server, not from a local
/// SharedPreferences duplicate.
class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({
    super.key,
    required this.args,
    this.paymentCubit,
    this.paymentService,
  });
  final Map<String, dynamic> args;

  /// Optional injected cubit — used by widget tests to drive
  /// deterministic state transitions. When null (production),
  /// the page creates its own cubit from [paymentService] or
  /// the GetIt-registered [PaymentService]. This mirrors the
  /// optional-dependency convention used by [CheckoutPage].
  final PaymentCubit? paymentCubit;

  /// Optional [PaymentService] for production dependency
  /// injection. Defaults to the GetIt-registered instance.
  /// Ignored when [paymentCubit] is provided.
  final PaymentService? paymentService;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  bool _checkoutOpened = false;
  bool _successNavigated = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final total = (widget.args['total'] as Money?) ?? Money.zero;
    final orderId = (widget.args['orderId'] as String?)?.trim() ?? '';
    final customerEmail =
        (widget.args['customerEmail'] as String?) ?? 'customer@example.com';

    // Production: create a PaymentCubit from the registered
    // [PaymentService] (or an injected [paymentService]) and
    // initialize it for this order. Tests: inject a preconfigured
    // cubit via [widget.paymentCubit] so they can drive state
    // transitions deterministically — the page must not shadow
    // it with its own GetIt lookup.
    final consumer = BlocConsumer<PaymentCubit, PaymentState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.checkoutUrl != current.checkoutUrl,
      listener: (context, state) {
        if (state.status == PaymentStatus.awaitingVerification &&
            !_checkoutOpened) {
          final checkoutUrl = state.checkoutUrl;
          if (checkoutUrl == null ||
              !PaymobUrlGuard.isSafePaymobCheckoutUrl(checkoutUrl)) {
            context.read<PaymentCubit>().cancel();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.invalidCheckoutLink),
            ));
            return;
          }
          _checkoutOpened = true;
          context.push('/paymob-checkout', extra: checkoutUrl);
        } else if (state.status == PaymentStatus.success &&
            !_successNavigated) {
          final successOrderId = state.orderId.trim();
          if (successOrderId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.paymentSuccessOrderMissing),
            ));
            return;
          }
          _successNavigated = true;
          // Clear the local cart only. The canonical order
          // lives on the server; order history is fetched
          // from there, not duplicated locally.
          context.read<CartCubit>().clear();
          context.go('/order-success', extra: successOrderId);
        } else if (state.status == PaymentStatus.failed ||
            state.status == PaymentStatus.cancelled ||
            state.status == PaymentStatus.expired ||
            state.status == PaymentStatus.timedOut) {
          // Pop the hosted-checkout WebView if it is still on top so
          // the user lands back on this page and can read the
          // recoverable error + retry. Only pop when we actually
          // opened the checkout, so a failure that happens before
          // navigation (e.g. initiation error) does not pop an
          // unrelated route.
          final checkoutWasOpen = _checkoutOpened;
          _checkoutOpened = false;
          if (checkoutWasOpen && context.canPop()) context.pop();
          final message = state.errorMessage ??
              switch (state.status) {
                PaymentStatus.cancelled => l.paymentCancelledRetry,
                PaymentStatus.expired => l.paymentExpiredRetry,
                PaymentStatus.timedOut => l.paymentTimedOut,
                _ => l.paymentFailedRetry,
              };
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        if (orderId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(l.selectPaymentMethod)),
            body: Center(
              child: Text(l.unableToContinueOrderMissing),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(l.selectPaymentMethod)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.selectPaymentMethod,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  '${l.total}: ${state.amount.format(locale: Localizations.localeOf(context).toString(), symbol: l.currencyCode)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary)),
              const SizedBox(height: 24),
              _PaymentOption(
                icon: Icons.credit_card,
                title: l.payWithCard,
                subtitle: l.payWithCardDescription,
                isSelected: state.selectedMethod == PaymentMethod.paymobCard,
                onTap: () => context
                    .read<PaymentCubit>()
                    .selectMethod(PaymentMethod.paymobCard),
              ),
              const SizedBox(height: 12),
              _PaymentOption(
                icon: Icons.money,
                title: l.cashOnDelivery,
                subtitle: l.cashOnDeliveryDescription,
                isSelected:
                    state.selectedMethod == PaymentMethod.cashOnDelivery,
                onTap: () => context
                    .read<PaymentCubit>()
                    .selectMethod(PaymentMethod.cashOnDelivery),
              ),
              const SizedBox(height: 32),
              BlocBuilder<PaymentCubit, PaymentState>(
                builder: (context, state) {
                  return FilledButton(
                    onPressed: state.canProceed &&
                            state.status != PaymentStatus.processing
                        ? () => context.read<PaymentCubit>().processPayment(
                              customerEmail: customerEmail,
                            )
                        : null,
                    child: state.status == PaymentStatus.processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.payNow),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (widget.paymentCubit != null) {
      // Test path: the caller owns the cubit's lifecycle.
      return BlocProvider<PaymentCubit>.value(
        value: widget.paymentCubit!,
        child: consumer,
      );
    }
    // Production path: BlocProvider owns and disposes the cubit.
    return BlocProvider<PaymentCubit>(
      create: (_) => PaymentCubit(
        widget.paymentService ?? getIt<PaymentService>(),
      )..initPayment(
          amount: total,
          orderId: orderId,
        ),
      child: consumer,
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? scheme.primaryContainer.withValues(alpha: .3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: .3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.radio_button_unchecked, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
