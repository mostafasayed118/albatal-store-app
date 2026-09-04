import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/supabase_config.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../../addresses/presentation/cubit/addresses_cubit.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/address_picker.dart';
import '../widgets/cart_summary.dart';
import '../widgets/order_review.dart';
import '../widgets/step_indicator.dart';

/// Checkout page — Stitch 3528 flow reskin.
///
/// Tokens: ListView EdgeInsetsDirectional.all(16), Shipping Address Card
/// surface / outlineVariant 1dp / cardRadius 16 clipAntiAlias,
/// Server-confirmed totals Card surface/outlineVariant 16 titleSmall 8dp rows,
/// bottomNavigationBar Container height 72 EdgeInsetsDirectional.all(16) surface
/// with FilledButton secondary #904D00 controlRadius 8 labelLarge.
///
/// The idempotency key is managed by [CheckoutCubit] — generated once per
/// checkout attempt and reused on retry, so the server returns the original
/// order instead of creating a duplicate.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage(
      {super.key,
      CheckoutRepository? checkoutRepository,
      CheckoutCubit? checkoutCubit})
      : _checkoutRepository = checkoutRepository,
        _checkoutCubit = checkoutCubit;

  final CheckoutRepository? _checkoutRepository;
  final CheckoutCubit? _checkoutCubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final consumer = BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, s) {
        if (s.status == CheckoutStatus.placing && s.hasPendingOrder) {
          // Empty (never fake) when the session lapsed — PaymentMethodPage
          // blocks with a sign-in error instead of charging a dead address.
          final email = SupabaseConfig.currentUser?.email?.trim() ?? '';
          context.push('/payment-method', extra: {
            'total': s.serverTotal,
            'subtotal': s.serverSubtotal,
            'shipping': s.serverShipping,
            'address': s.selectedAddress,
            'orderId': s.pendingOrderId,
            'customerEmail': email,
          });
        } else if (s.status == CheckoutStatus.error && s.errorMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.errorMessage!)));
        }
      },
      builder: (context, s) {
        final addressError = s.status == CheckoutStatus.error && !s.hasAddress;
        final isCreating = s.status == CheckoutStatus.creatingOrder;
        return Scaffold(
          appBar: AppBar(title: Text(l.checkout)),
          body: ListView(
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              StepIndicator(
                steps: [l.shippingAddress, l.reviewOrder],
                currentStep: s.hasAddress ? 1 : 0,
                scheme: scheme,
              ),
              const SizedBox(height: 24),
              // Stitch Shipping Address card: surface + outlineVariant 1dp radius 16 clipAntiAlias.
              Card(
                color: scheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.cardRadius,
                  side: BorderSide(color: scheme.outlineVariant, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.shippingAddress,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      AddressPicker(
                        selectedAddress: s.selectedAddress,
                        onSelect: (a) =>
                            context.read<CheckoutCubit>().selectAddress(a),
                        onAddNew: () async {
                          final address = await AddressForm.show(context);
                          if (address != null && context.mounted) {
                            context
                                .read<CheckoutCubit>()
                                .selectAddress(address);
                            // Persist to the address book too: previously
                            // the new address was only selected and vanished
                            // on restart (live-found 2026-09-03).
                            context.read<AddressesCubit>().upsert(address);
                          }
                        },
                        l: l,
                        scheme: scheme,
                        hasError: addressError,
                      ),
                      if (addressError) ...[
                        const SizedBox(height: 4),
                        Text(l.validationSelectAddress,
                            style:
                                TextStyle(color: scheme.error, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (s.hasAddress) ...[
                Text(l.reviewOrder,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                OrderReview(address: s.selectedAddress!, l: l),
                const SizedBox(height: 16),
              ],
              BlocBuilder<CartCubit, CartState>(
                  builder: (_, cart) => CartSummary(cart)),
              // Local math is an estimate: the server computes the final
              // total (live-found 2026-09-04: review showed 1365 while
              // the server charged 1290).
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(l.estimatedTotalsNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              // Show server-returned totals once the order is created — Stitch summary card.
              if (s.hasPendingOrder) ...[
                const SizedBox(height: 16),
                Card(
                  color: scheme.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.cardRadius,
                    side: BorderSide(color: scheme.outlineVariant, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.serverConfirmedTotals,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        _ServerTotalRow(
                            label: l.subtotal, value: s.serverSubtotal),
                        _ServerTotalRow(
                            label: l.shipping, value: s.serverShipping),
                        _ServerTotalRow(label: l.total, value: s.serverTotal),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: Container(
            height: 72,
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(color: scheme.surface),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                minimumSize: const Size.fromHeight(40),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.controlRadius),
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              onPressed: s.hasAddress && !isCreating
                  ? () {
                      final cart = context.read<CartCubit>().state;
                      context
                          .read<CheckoutCubit>()
                          .createPendingOrder(cartItems: cart.items);
                    }
                  : null,
              child: isCreating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.onSecondary),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.proceedToPayment),
                        const SizedBox(width: 8),
                        const Icon(
                            IconData(0xe5cc,
                                fontFamily: 'MaterialIcons',
                                matchTextDirection: true),
                            size: 18),
                      ],
                    ),
            ),
          ),
        );
      },
    );
    final page = BlocListener<AddressesCubit, AddressesState>(
      // Auto-select the default address once, when the address book
      // arrives and the user hasn't picked one yet (UX: a 'افتراضي'
      // address that still requires a manual tap reads as broken).
      listenWhen: (previous, current) =>
          current.addresses.isNotEmpty &&
          previous.addresses != current.addresses,
      listener: (context, addressesState) {
        final checkout = context.read<CheckoutCubit>();
        if (checkout.state.selectedAddress != null) return;
        final addresses = addressesState.addresses;
        final chosen = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        context.read<CheckoutCubit>().selectAddress(chosen);
      },
      child: consumer,
    );
    if (_checkoutCubit != null) {
      return BlocProvider<CheckoutCubit>.value(
          value: _checkoutCubit, child: page);
    }
    return BlocProvider<CheckoutCubit>(
      create: (_) => CheckoutCubit(
        _checkoutRepository ?? getIt<CheckoutRepository>(),
        // GetIt always carries SharedPreferences in the real app;
        // widget tests pump this page without the locator.
        prefs: getIt.isRegistered<SharedPreferences>()
            ? getIt<SharedPreferences>()
            : null,
      ),
      child: page,
    );
  }
}

class _ServerTotalRow extends StatelessWidget {
  const _ServerTotalRow({required this.label, required this.value});
  final String label;
  final Money? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value?.format() ?? '--',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
