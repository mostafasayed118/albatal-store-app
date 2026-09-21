import '../../../../core/error/result.dart';
import '../entities/admin_customer.dart';

/// Rows per customer-directory page when a caller does not choose a size.
///
/// Shared by the repository default and the directory cubit so the paging
/// contract has a single number: the cubit decides *when* to ask for the next
/// page, this decides how much arrives.
const defaultCustomersPageSize = 50;

/// Where a reader has got to in the newest-first customer directory: the
/// `(createdAt, id)` of the last row it has seen.
///
/// Shared between the repository that hands one back and the cubit that hands
/// it straight back in when asking for more, so it lives on the port rather
/// than in the data layer. [createdAt] is canonical UTC ISO-8601 — the form
/// the server compares against `timestamptz` directly.
typedef CustomerCursor = ({String createdAt, String id});

/// Narrow port for the admin customer directory (ISP).
///
/// Split out of [AdminRepository] (audit). [AdminCustomersCubit] depends
/// on this instead of the ~20-method facade.
abstract interface class AdminCustomersPort {
  /// One bounded page of customer profiles, newest first (admin-only by
  /// RLS), plus what a caller needs to reach the next page.
  ///
  /// [query] is applied on the **server** — a case-insensitive substring of
  /// the name — so a search covers the whole table rather than only the pages
  /// already loaded. Blank means no filter.
  ///
  /// Paging is **keyset**: [cursor] names the last row already seen and the
  /// server answers with only what follows it in `(createdAt DESC, id DESC)`
  /// order. [nextCursor] is null exactly when the page just read is the last
  /// one. [total] is the exact match count, reported **only on the first
  /// page** (a null [cursor]).
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
  });

  /// Set a customer's membership tier via the admin-gated RPC
  /// (migration 046). The tier drives the Premium badge customers see.
  Future<Result<void>> setMembershipTier(String profileId, String tier);
}
