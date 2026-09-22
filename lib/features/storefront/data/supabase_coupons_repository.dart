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
  SupabaseCouponsRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<CouponDiscount>> validate(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Failure(AppError(kCouponInvalid));
    }
    try {
      final rows = await _client.rpc(
        'validate_coupon',
        params: {'p_code': trimmed},
      );
      // Total payload handling (audit 2026-09-21): a mistyped RPC row must
      // fail soft into "invalid coupon", not throw — raw `as` casts throw
      // [TypeError], an [Error] the old `on Exception` clause structurally
      // could not catch, which escaped to checkout as an unhandled error.
      final coupon = couponFromRpcPayload(rows);
      if (coupon == null) {
        return const Failure(AppError(kCouponInvalid));
      }
      return Success(coupon);
    } on PostgrestException catch (e, st) {
      // 42883 = undefined_function / PGRST202 = schema cache miss:
      // the proposal migration has not been applied yet.
      final unavailable = e.code == '42883' ||
          e.code == 'PGRST202' ||
          e.message.contains('schema cache');
      Log.w('validate_coupon failed',
          error: e, category: LogCategory.network);
      return Failure(AppError(
        unavailable ? kCouponUnavailable : kCouponInvalid,
        cause: e,
        stackTrace: st,
      ));
    } catch (e, st) {
      // Bare catch (Result.guard convention): must also catch [Error]s,
      // e.g. the [TypeError] a malformed payload used to escape with.
      Log.e('validate_coupon unexpected error', error: e, stackTrace: st);
      return Failure(AppError(kCouponInvalid, cause: e, stackTrace: st));
    }
  }
}
