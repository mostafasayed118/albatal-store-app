import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/entities/money.dart';
import '../../../../../shared/components/app_card.dart';
import '../../../../../shared/components/feedback_view.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../cubit/admin_coupons_cubit.dart';
import '../admin_error_feedback.dart';

/// Admin coupon list + create sheet — extracted from
/// `admin_coupons_page.dart` verbatim (was private `_AdminCouponsView`).
final class AdminCouponsView extends StatelessWidget {
  const AdminCouponsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminCoupons)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l.adminAddCoupon),
      ),
      body: BlocBuilder<AdminCouponsCubit, AdminCouponsState>(
        builder: (context, state) {
          if (state.status == AdminCouponsStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == AdminCouponsStatus.error) {
            return AdminErrorFeedback(
              errorCode: state.errorCode,
              errorMessage: state.errorMessage,
              fallback: l.couponInvalid,
              onRetry: () => context.read<AdminCouponsCubit>().load(),
            );
          }
          if (state.coupons.isEmpty) {
            // Bare empty state: the create-coupon FAB carries the action, so
            // no CTA renders here.
            return FeedbackView(
              type: FeedbackViewType.empty,
              icon: Icons.local_offer_outlined,
              body: l.adminAddCoupon,
            );
          }
          return ListView.separated(
            padding: const EdgeInsetsDirectional.all(16),
            itemCount: state.coupons.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final coupon = state.coupons[i];
              return AppCard(
                child: SwitchListTile(
                  title: Text(coupon.code),
                  subtitle: Text(safeMinorToEgpLabel(coupon.discountMinor)),
                  value: coupon.active,
                  onChanged: (active) => context
                      .read<AdminCouponsCubit>()
                      .setActive(coupon.id, active),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    InputDecoration(labelText: sheetContext.l10n.couponCode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: sheetContext.l10n.couponDiscountEgp),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final code = codeController.text.trim();
                  final egp = int.tryParse(discountController.text.trim());
                  if (code.isEmpty || egp == null || egp <= 0) return;
                  context.read<AdminCouponsCubit>().createCoupon(
                        code: code,
                        discountMinor: egp * 100,
                      );
                  Navigator.of(sheetContext).pop();
                },
                child: Text(sheetContext.l10n.adminAddCoupon),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Disposed after the sheet is fully popped (covers confirm,
      // cancel, and barrier dismissal) — same contract as the admin
      // dialog controllers (PR #34 sweep).
      codeController.dispose();
      discountController.dispose();
    }
  }
}

/// Minor-units → "EGP x.yy" display label (display-only; money math
/// stays server-side). The digits come from [Money.formatExact] so every
/// money string in the app is produced by one formatter.
String safeMinorToEgpLabel(int minor) =>
    'EGP ${Money(minor).formatExact(symbol: '')}';
