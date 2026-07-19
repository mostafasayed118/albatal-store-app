import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'shared/services/app_bloc_observer.dart';
import 'shared/services/logger.dart';
import 'shared/services/service_locator.dart';
import 'shared/services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logger
  Log.setLevel(LogLevel.debug);
  Log.i('App starting...', category: LogCategory.app);

  // Set up Bloc observer for state change logging
  Bloc.observer = AppBlocObserver();

  // Initialize Supabase
  Log.i('Initializing Supabase...', category: LogCategory.network);
  await SupabaseConfig.initialize();
  Log.i('Supabase ready', category: LogCategory.network);

  // Initialize service locator
  Log.i('Configuring dependencies...', category: LogCategory.app);
  await configureDependencies();
  Log.i('Dependencies ready', category: LogCategory.app);

  Log.i('Launching app', category: LogCategory.app);
  runApp(const AlBatalApp());
}
