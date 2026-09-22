import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/components/app_card.dart';
import '../../../domain/entities/coupon_discount.dart';
import '../../cubit/checkout_cubit.dart';

/// Coupon entry card — extracted verbatim from `checkout_page.dart`
/// (was private `_CouponCard`).
///
/// Validation goes through [CheckoutCubit.applyCoupon]
/// (server `validate_coupon` RPC); server-confirmed discounts appear on
/// the order summary after creation, never computed here.
final class CheckoutCouponCard extends StatefulWidget {
  const CheckoutCouponCard({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  State<CheckoutCouponCard> createState() => CheckoutCouponCardState();
}

/// Public state so widget tests can drive the controller if needed.
/// Not part of the public API contract — prefer pumping [CheckoutCouponCard].
final class CheckoutCouponCardState extends State<CheckoutCouponCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _messageText(AppLocalizations l10n, String? code) {
    switch (code) {
      case kCouponInvalid:
        return l10n.couponInvalid;
      case kCouponUnavailable:
        return l10n.couponUnavailable;
      default:
        return l10n.couponApplied;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: BlocBuilder<CheckoutCubit, CheckoutState>(
          buildWhen: (a, b) =>
              a.appliedCoupon != b.appliedCoupon ||
              a.couponMessage != b.couponMessage,
          builder: (context, s) {
            final coupon = s.appliedCoupon;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.couponFieldLabel,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  enabled: coupon == null,
                  decoration: InputDecoration(
                    hintText: l10n.couponFieldLabel,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: coupon == null
                      ? FilledButton(
                          onPressed: () => context
                              .read<CheckoutCubit>()
                              .applyCoupon(_controller.text),
                          child: Text(l10n.couponApply))
                      : IconButton(
                          tooltip: l10n.couponRemove,
                          onPressed: () {
                            _controller.clear();
                            context.read<CheckoutCubit>().clearCoupon();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                if (coupon != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8),
                    child: Text(l10n.couponApplied,
                        style: TextStyle(color: scheme.primary)),
                  ),
                if (coupon == null && s.couponMessage != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8),
                    child: Text(_messageText(l10n, s.couponMessage),
                        style: TextStyle(color: scheme.error)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
