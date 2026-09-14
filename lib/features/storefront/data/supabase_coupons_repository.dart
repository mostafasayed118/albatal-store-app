import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../domain/entities/coupon_discount.dart';
import '../domain/repositories/coupons_repository.dart';
import 'coupon_mapper.dart';

/// Supabase-backed coupon validation (feature-batch §8).
///
/// Talks to the review-gated `validate_coupon` RPC (proposal 049).
/// Before that migration is applied the RPC is absent — the PostgREST
/// error is mapped to a `coupon_unavailable` failure so the checkout
/// proceeds normally without a coupon.
final class SupabaseCouponsRepository implements CouponsRepository {
  SupabaseCouponsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<CouponDiscount>> validate(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Failure(AppError(kCouponInvalid));
    }
    final rows = await Result.guard(
      () => _client.rpc(
        'validate_coupon',
        params: {'p_code': trimmed},
      ),
      kCouponInvalid,
      onError: _couponError,
    );
    return rows.when(
      success: (value) {
        final list = value as List<dynamic>? ?? const [];
        if (list.isEmpty) {
          return const Failure<CouponDiscount>(AppError(kCouponInvalid));
        }
        final row = list.first as Map<String, dynamic>;
        final coupon = couponFromRow(row);
        if (coupon == null) {
          return const Failure<CouponDiscount>(AppError(kCouponInvalid));
        }
        return Success<CouponDiscount>(coupon);
      },
      failure: (error) => Failure<CouponDiscount>(error),
    );
  }

  /// [Result.guard] error-mapper: 42883 = undefined_function /
  /// PGRST202 = schema cache miss — the proposal migration has not
  /// been applied yet, so the RPC absence degrades to
  /// [kCouponUnavailable]; everything else is an invalid coupon.
  AppError _couponError(Object e, StackTrace st) {
    if (e is PostgrestException) {
      final unavailable = e.code == '42883' ||
          e.code == 'PGRST202' ||
          e.message.contains('schema cache');
      Log.w('validate_coupon failed: ${e.code} ${e.message}',
          category: LogCategory.network);
      return AppError(
        unavailable ? kCouponUnavailable : kCouponInvalid,
        cause: e,
        stackTrace: st,
      );
    }
    Log.e('validate_coupon unexpected error', error: e, stackTrace: st);
    return AppError(kCouponInvalid, cause: e, stackTrace: st);
  }
}
