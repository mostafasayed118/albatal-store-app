import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/data/local_settings_repository.dart';
import '../../features/addresses/data/local_address_repository.dart';
import '../../features/addresses/domain/repositories/address_repository.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerLazySingleton<SettingsRepository>(() => LocalSettingsRepository(getIt<SharedPreferences>()))
    ..registerLazySingleton<AddressRepository>(() => LocalAddressRepository(getIt<SharedPreferences>()));
}
