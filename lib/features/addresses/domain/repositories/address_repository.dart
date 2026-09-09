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

/// Narrow wipe capability for the on-device address book.
///
/// Kept OFF the base [AddressRepository] contract on purpose: clearing
/// is a device-lifecycle concern for sign-out and account deletion
/// (audit S9), not part of the address-book API. Consumers that only
/// need the wipe (e.g. [AuthCubit]) depend on the base abstraction and
/// narrow to this interface with `is` — a repository without the
/// capability is skipped safely instead of crashing.
abstract interface class ClearableAddressRepository extends AddressRepository {
  /// Removes the whole on-device address book.
  Future<Result<void>> clearAddresses();
}
