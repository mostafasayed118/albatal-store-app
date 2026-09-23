import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/step_indicator.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../addresses/addresses.dart';
import '../../domain/repositories/auth_session_port.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/repositories/coupons_repository.dart';
import '../../domain/usecases/place_checkout_order_usecase.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/cart_summary.dart';
import '../widgets/checkout/coupon_card.dart';
import '../widgets/checkout/server_totals_card.dart';
import '../widgets/checkout/shipping_address_card.dart';
import '../widgets/order_review.dart';

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
///
/// Dependencies are constructor-injected (audit P1): the router resolves
/// them at the composition root. [authSession] is optional — an absent
/// port (widget tests) yields an empty customer email.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({
    super.key,
    required CheckoutRepository checkoutRepository,
    CheckoutCubit? checkoutCubit,
    PlaceCheckoutOrderUseCase? placeOrder,
    AuthSessionPort? authSession,
    CouponsRepository? couponsRepository,
  })  : _checkoutRepository = checkoutRepository,
        _checkoutCubit = checkoutCubit,
        _placeOrder = placeOrder,
        _authSession = authSession,
        _couponsRepository = couponsRepository;

  final CheckoutRepository _checkoutRepository;
  final CheckoutCubit? _checkoutCubit;
  final PlaceCheckoutOrderUseCase? _placeOrder;
  final AuthSessionPort? _authSession;
  final CouponsRepository? _couponsRepository;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final consumer = BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, s) {
        if (s.status == CheckoutStatus.placing && s.hasPendingOrder) {
          // Empty (never fake) when the session lapsed — PaymentMethodPage
          // blocks with a sign-in error instead of charging a dead address.
          final email = _resolveCustomerEmail();
          context.push(Routes.paymentMethod, extra: {
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
          // Code-based localization (audit 2026-09-13), with the English-literal
          // matching removed (audit 2026-09-19, sweep part 32): comparing
          // `raw == 'Checkout failed'` meant any copy edit silently reverted this
          // screen to English. Coded failures localize; uncoded ones are
          // server-authored and pass through verbatim (P1 ruling); the last
          // resort is localized rather than the raw string. The empty-cart
          // guard is app-authored (audit 2026-09-21), so it localizes here
          // like `checkout_failed` instead of leaking its English diagnosis.
          final localized = switch (s.errorCode) {
            kCheckoutFailedCode => l10n.checkoutFailedRetry,
            kCheckoutCartEmpty => l10n.checkoutCartEmpty,
            _ => failureText(l10n,
                code: s.errorCode, message: raw, fallback: l10n.errorTitle),
          };
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating, content: Text(localized)));
        }
      },
      builder: (context, s) {
        final addressError = s.status == CheckoutStatus.error && !s.hasAddress;
        final isCreating = s.status == CheckoutStatus.creatingOrder;
        // A phone-less address (saved before the field shipped) cannot
        // complete a COD order: the courier has no number to call. Blocked
        // here rather than at the server, so the customer sees the reason
        // and can fix it in place.
        final needsPhone = s.selectedAddress?.hasPhone == false;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.checkout)),
          body: ListView(
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              StepIndicator(
                steps: [l10n.shippingAddress, l10n.payment, l10n.reviewOrder],
                currentStep: s.hasAddress ? 1 : 0,
                scheme: scheme,
              ),
              const SizedBox(height: 24),
              // Stitch Shipping Address card: surface + outlineVariant 1dp radius 16 clipAntiAlias.
              CheckoutShippingAddressCard(
                l10n: l10n,
                scheme: scheme,
                selectedAddress: s.selectedAddress,
                hasError: addressError,
                needsPhone: needsPhone,
              ),
              const SizedBox(height: 24),
              if (s.hasAddress) ...[
                Text(l10n.reviewOrder,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                OrderReview(address: s.selectedAddress!, l: l10n),
                const SizedBox(height: 16),
              ],
              BlocBuilder<CartCubit, CartState>(
                  builder: (_, cart) => CartSummary(cart)),
              // Local math is an estimate: the server computes the final
              // total (live-found 2026-09-04: review showed 1365 while
              // the server charged 1290).
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(l10n.estimatedTotalsNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              // §8: coupon attach/remove before order creation — the
              // discount itself is computed server-side only.
              if (!s.hasPendingOrder) ...[
                const SizedBox(height: 16),
                CheckoutCouponCard(l10n: l10n),
              ],
              // Show server-returned totals once the order is created — Stitch summary card.
              if (s.hasPendingOrder) ...[
                const SizedBox(height: 16),
                CheckoutServerTotalsCard(
                  l10n: l10n,
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
              onPressed: s.hasAddress && !needsPhone && !isCreating
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
                        // Flexible + ellipsis: at large text scales (1.4×)
                        // the label shrinks instead of overflowing the CTA
                        // row; unchanged at the default scale.
                        Flexible(
                          child: Text(
                            l10n.proceedToPayment,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
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
      // Widget tests pump this page with a fake repository (or a
      // pre-built cubit via the .value branch above) instead of the
      // locator — no getIt fallback.
      create: (_) => CheckoutCubit(
        _checkoutRepository,
        placeOrder: _placeOrder,
        coupons: _couponsRepository,
      ),
      child: page,
    );
  }

  /// Resolves the signed-in email via the injected [AuthSessionPort]
  /// without importing Supabase into the presentation layer. Empty
  /// (never fake) when the port is absent (widget tests) or the session
  /// lapsed.
  String _resolveCustomerEmail() {
    return _authSession?.currentUserEmail()?.trim() ?? '';
  }
}
