import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
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
        // `rows` is statically List via the typed Postgrest builder.
        return rows
            .whereType<Map<String, dynamic>>()
            .map(_couponFromRow)
            .whereType<AdminCoupon>()
            .toList();
      }, 'Failed to fetch coupons', code: kAdminCouponsLoadFailed);

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) =>
      Result.guard(() async {
        final res = await _client
            .from('coupons')
            .upsert({
              'code': code.trim().toUpperCase(),
              'discount_minor': discountMinor,
              if (description != null && description.isNotEmpty)
                'description': description,
            })
            .select('id, code, discount_minor, description, active')
            .single();
        // `.single()` is statically Map via the typed Postgrest builder.
        final row = safeMap(res);
        final coupon = _couponFromRow(row);
        if (coupon == null) {
          throw StateError('createCoupon returned no coupon id');
        }
        return coupon;
      }, 'Failed to create coupon', code: kAdminCouponCreateFailed);

  @override
  Future<Result<void>> setCouponActive(String id, bool active) =>
      Result.guard<void>(() async {
        await _client.from('coupons').update({'active': active}).eq('id', id);
      }, 'Failed to update coupon', code: kAdminCouponUpdateFailed);
}

/// Maps one `coupons` row into an [AdminCoupon].
/// Returns null for id-less rows (cannot be toggled) — the list skips them
/// instead of one malformed row failing the whole fetch.
AdminCoupon? _couponFromRow(Map<String, dynamic> row) {
  final id = optString(row, 'id');
  if (id == null || id.isEmpty) return null;
  return AdminCoupon(
    id: id,
    code: (optString(row, 'code') ?? '').toUpperCase(),
    discountMinor: optInt(row, 'discount_minor') ?? 0,
    active: safeBool(row, 'active'),
    description: optString(row, 'description'),
  );
}
