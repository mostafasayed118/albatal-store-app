import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_coupons_cubit.dart';

/// Admin coupon management (feature-batch §8): list, create, activate.
///
/// Reads the repository via the locator (admin routes are gated by
/// profile.isAdmin in the router) with an optional injected cubit for
/// widget tests.
class AdminCouponsPage extends StatelessWidget {
  const AdminCouponsPage({super.key, this.cubit});

  final AdminCouponsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCouponsCubit>(
      create: (_) => (cubit ??
          AdminCouponsCubit(repository: getIt<AdminRepository>()))
        ..load(),
      child: const _AdminCouponsView(),
    );
  }
}

final class _AdminCouponsView extends StatelessWidget {
  const _AdminCouponsView();

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
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == AdminCouponsStatus.error) {
            return Center(
              child: Text(state.errorMessage ?? l.couponInvalid),
            );
          }
          if (state.coupons.isEmpty) {
            return Center(child: Text(l.adminAddCoupon));
          }
          return ListView.separated(
            padding: const EdgeInsetsDirectional.all(16),
            itemCount: state.coupons.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final coupon = state.coupons[i];
              return Card(
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.cardRadius,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1),
                ),
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

  void _showCreateSheet(BuildContext context) {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    showModalBottomSheet<void>(
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
  }
}

/// Minor-units → "EGP x.yy" display label (display-only; money math
/// stays server-side).
String safeMinorToEgpLabel(int minor) {
  final egp = minor / 100;
  return 'EGP ${egp.toStringAsFixed(2)}';
}
