import '../../../../core/error/result.dart';
import '../address.dart';

abstract interface class AddressRepository {
  Future<Result<List<Address>>> read();
  Future<Result<void>> save(List<Address> addresses);
}
