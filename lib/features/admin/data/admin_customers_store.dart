import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/services/logger.dart';
import '../domain/entities/admin_customer.dart';
import '../domain/repositories/admin_customers_port.dart';
import 'admin_customer_search.dart';

/// Customer directory reads and tier writes for [SupabaseAdminRepository].
///
/// Implements [AdminCustomersPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminCustomers implements AdminCustomersPort {
  SupabaseAdminCustomers({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Columns that exist on `public.profiles`.
  ///
  /// `email` is deliberately ABSENT: the column does not exist on
  /// `profiles` (the address lives in `auth.users`, which PostgREST does not
  /// expose), and requesting it made PostgREST answer with
  /// `42703 column profiles.email does not exist`. Because the failure was
  /// mapped to a `Failure`, the whole Customers screen rendered an error and
  /// no customer could ever be listed. `phone` is the real contact column.
  ///
  /// `created_at` is requested for **position, not display**: it is half of
  /// the keyset bookmark (see [customerKeysetFilter]) and no caller renders
  /// it.
  ///
  /// Paged (audit follow-up): one bounded page plus an exact `count`, reached
  /// by keyset cursor. The read stays bounded, but the 501st customer is now
  /// reachable and the UI can say how many it is not showing — the previous
  /// `.limit(500)` truncated the directory silently.
  @override
  Future<
      Result<
          ({
            List<AdminCustomer> customers,
            int? total,
            CustomerCursor? nextCursor,
          })>> fetchCustomers({
    String? query,
    CustomerCursor? cursor,
    int limit = defaultCustomersPageSize,
  }) async {
    // Deliberately hand-written rather than `Result.guard`: this boundary
    // logs the cause before mapping it (see below) and the guard helper has
    // no logging hook. Every other method in this repository delegates to
    // the shared boundary.
    try {
      final term = query?.trim() ?? '';
      var request = _client
          .from('profiles')
          .select('id, full_name, phone, membership_tier, created_at');
      if (term.isNotEmpty) {
        // Name *or* phone — see [customerSearchFilter]. ANDed with the cursor
        // filter below as a second `or` parameter, which PostgREST conjoins.
        request = request.or(customerSearchFilter(term));
      }
      if (cursor != null) {
        request = request.or(customerKeysetFilter(cursor));
      }
      // One row past the page is requested so "is there another page?" is
      // answered by the data itself instead of by comparing a running count
      // against `total`. The extra row is dropped before returning.
      final response = await request
          // `id` is the tiebreaker, not decoration: `created_at` is not
          // unique (a seed, a bulk import, or two signups in the same tick all
          // share it) and a non-total sort key lets Postgres order those ties
          // differently per query — which is how a row lands on two
          // consecutive pages, or on neither. Matches [customerKeysetFilter].
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit + 1)
          // `.count()` sets `Prefer: count=exact`, so one round trip carries
          // both the page and the total matching the same filter. It is asked
          // for on every page because a single response carries both, but is
          // only *reported* on the first: a cursor narrows the counted filter,
          // so a continuation page's count is the rows remaining rather than
          // the rows that match.
          .count(CountOption.exact);
      // Total decode parity with the orders queue: mistyped rows degrade to
      // skips (audit 2026-09-14 P0-3) — previously `rows as List` threw on
      // a malformed payload and `row as Map` threw per-row.
      //
      // Rows without a usable string id are dropped *before* the page is cut
      // to size: they cannot be navigated to, and a bookmark taken past them
      // is what keeps `nextCursor` describing a row that was actually
      // returned.
      final rows = (response.data as List)
          .whereType<Map<String, dynamic>>()
          .where((row) {
        final id = row['id'];
        return id is String && id.isNotEmpty;
      }).toList();
      final hasMore = rows.length > limit;
      final page = hasMore ? rows.sublist(0, limit) : rows;
      final nextCursor = hasMore ? customerCursorForRow(page.last) : null;
      final list = page
          .map((row) => AdminCustomer(
                id: safeString(row, 'id'),
                name: safeString(row, 'full_name'),
                phone: safeString(row, 'phone'),
                tier: safeString(row, 'membership_tier', fallback: 'standard'),
                isBlocked:
                    false, // no suspension flag in profiles (§14 read-only)
              ))
          .toList();
      return Success((
        customers: list,
        // Only the first page can report a total (see the port's doc comment
        // and `AdminCustomersCubit`, which preserves the value it already
        // has).
        total: cursor == null ? response.count : null,
        nextCursor: nextCursor,
      ));
    } catch (e) {
      // NOTE: this endpoint needs an admin SELECT policy on `profiles`
      // (see supabase/migrations/061_admin_profiles_read.sql).
      // Without it RLS limits the result to the caller's own row; the call
      // still succeeds, so the directory is simply short.
      Log.w('fetchCustomers failed', category: LogCategory.network, error: e);
      return Failure(AppError('Failed to fetch customers',
          cause: e, code: kAdminCustomersLoadFailed));
    }
  }

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) =>
      Result.guard<void>(() async {
        await _client.rpc('admin_set_membership_tier', params: {
          'p_profile_id': profileId,
          'p_tier': tier,
        });
      }, 'Failed to update membership tier',
          code: kAdminMembershipUpdateFailed);
}
