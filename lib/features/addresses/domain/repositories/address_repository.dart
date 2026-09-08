import '../../../../core/error/result.dart';
import '../address.dart';

/// Abstraction for the on-device address book.
///
/// The device-local store (SharedPreferences) is the only persistence
/// for saved addresses: the storefront selects a shipping address from
/// here and checkout snapshots it onto the order, so the repository is
/// read/write by design. Lives in the domain layer so pages and cubits
/// never import the data layer; implementations return [Result] so
/// callers receive errors at this boundary instead of exceptions.
abstract interface class AddressRepository {
  /// Reads all saved addresses, newest edits preserved by the
  /// implementation's storage order.
  Future<Result<List<Address>>> read();

  /// Replaces the whole address book with [addresses]. Whole-list
  /// writes keep the persistence trivially consistent — callers own
  /// the list (add/edit/remove/default flows) and the store is small.
  Future<Result<void>> save(List<Address> addresses);
}
