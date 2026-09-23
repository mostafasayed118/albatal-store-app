import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_coupon.dart';
import '../domain/repositories/admin_coupons_port.dart';

/// Coupon reads/writes for [SupabaseAdminRepository].
///
/// Implements [AdminCouponsPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminCoupons implements AdminCouponsPort {
  SupabaseAdminCoupons({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() => Result.guard(() async {
        final rows = await _client
            .from('coupons')
            .select('id, code, discount_minor, description, active')
            .order('created_at', ascending: false);
        final list = rows as List<dynamic>;
        return list
            .map((row) => _couponFromRow(row as Map<String, dynamic>))
            .toList();
      }, 'Failed to fetch coupons', code: kAdminCouponsLoadFailed);

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) =>
      Result.guard(() async {
        final row = await _client
            .from('coupons')
            .upsert({
              'code': code.trim().toUpperCase(),
              'discount_minor': discountMinor,
              if (description != null && description.isNotEmpty)
                'description': description,
            })
            .select('id, code, discount_minor, description, active')
            .single();
        return _couponFromRow(row);
      }, 'Failed to create coupon', code: kAdminCouponCreateFailed);

  @override
  Future<Result<void>> setCouponActive(String id, bool active) =>
      Result.guard<void>(() async {
        await _client.from('coupons').update({'active': active}).eq('id', id);
      }, 'Failed to update coupon', code: kAdminCouponUpdateFailed);
}

/// Maps one `coupons` row into an [AdminCoupon].
AdminCoupon _couponFromRow(Map<String, dynamic> row) => AdminCoupon(
      id: row['id'] as String,
      code: (row['code'] as String?)?.toUpperCase() ?? '',
      discountMinor: (row['discount_minor'] as num?)?.toInt() ?? 0,
      active: row['active'] as bool? ?? false,
      description: row['description'] as String?,
    );
