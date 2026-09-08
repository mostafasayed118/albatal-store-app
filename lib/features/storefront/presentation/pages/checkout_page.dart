import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/money.dart';
import '../../../../generated/l10n/app_localizations.dart';
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
import '../../../../shared/components/step_indicator.dart';

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
          // Server-authored messages (e.g. a Postgrest rejection) are kept
          // verbatim (P1 ruling); generic scrubbed messages map to the
          // localized retry copy so Arabic users never see English (audit
          // code-quality finding).
          final raw = s.errorMessage!;
          final localized = (raw == 'Checkout failed' ||
                  raw == 'Failed to create order. Please try again.')
              ? l.checkoutFailedRetry
              : raw;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating, content: Text(localized)));
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
                steps: [l.shippingAddress, l.payment, l.reviewOrder],
                currentStep: s.hasAddress ? 1 : 0,
                scheme: scheme,
              ),
              const SizedBox(height: 24),
              // Stitch Shipping Address card: surface + outlineVariant 1dp radius 16 clipAntiAlias.
              _ShippingAddressCard(
                l: l,
                scheme: scheme,
                selectedAddress: s.selectedAddress,
                hasError: addressError,
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
                _ServerTotalsCard(
                  l: l,
                  scheme: scheme,
                  subtotal: s.serverSubtotal,
                  shipping: s.serverShipping,
                  total: s.serverTotal,
                ),
              ],
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(color: scheme.surface),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                // 72dp bar − 2×16dp padding = 40dp slot; keep the 50px
                // DESIGN CTA contract by letting the bar grow.
                minimumSize: const Size.fromHeight(50),
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
                        // Extension flips under RTL; the previous raw
                        // IconData(0xe5cc) literal pointed backwards in
                        // Arabic layouts.
                        Icon(context.directionalForwardIcon, size: 18),
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

/// Shipping Address card — extracted from [CheckoutPage]'s build (audit
/// Task 8b) verbatim: same tokens, same children, same behavior.
class _ShippingAddressCard extends StatelessWidget {
  const _ShippingAddressCard({
    required this.l,
    required this.scheme,
    required this.selectedAddress,
    required this.hasError,
  });

  final AppLocalizations l;
  final ColorScheme scheme;
  final Address? selectedAddress;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              selectedAddress: selectedAddress,
              onSelect: (a) => context.read<CheckoutCubit>().selectAddress(a),
              onAddNew: () async {
                final address = await AddressForm.show(context);
                if (address != null && context.mounted) {
                  context.read<CheckoutCubit>().selectAddress(address);
                  // Persist to the address book too: previously the new
                  // address was only selected and vanished on restart
                  // (live-found 2026-09-03).
                  context.read<AddressesCubit>().upsert(address);
                }
              },
              l: l,
              scheme: scheme,
              hasError: hasError,
            ),
            if (hasError) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l.validationSelectAddress,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Server-confirmed totals card — extracted verbatim from
/// [CheckoutPage]'s build (audit Task 8b).
class _ServerTotalsCard extends StatelessWidget {
  const _ServerTotalsCard({
    required this.l,
    required this.scheme,
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  final AppLocalizations l;
  final ColorScheme scheme;
  final Money? subtotal;
  final Money? shipping;
  final Money? total;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            _ServerTotalRow(label: l.subtotal, value: subtotal),
            _ServerTotalRow(label: l.shipping, value: shipping),
            _ServerTotalRow(label: l.total, value: total),
          ],
        ),
      ),
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
