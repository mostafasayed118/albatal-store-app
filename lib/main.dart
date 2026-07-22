import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'shared/services/app_bloc_observer.dart';
import 'shared/services/logger.dart';
import 'shared/services/service_locator.dart';
import 'shared/services/supabase_config.dart';

import 'core/services/crash_reporting_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logger
  Log.setLevel(LogLevel.debug);
  Log.i('App starting...', category: LogCategory.app);

  // Set up Bloc observer for state change logging
  Bloc.observer = AppBlocObserver();

  // Bootstrap Supabase + DI. Either can throw if .env is missing, env
  // vars are blank, or SharedPreferences fails. Without a guard the app
  // crashes to a red error screen before runApp. Catch and show a clear
  // fallback UI so the user sees a message instead of a framework crash.
  try {
    Log.i('Initializing Supabase...', category: LogCategory.network);
    await SupabaseConfig.initialize();
    Log.i('Supabase ready', category: LogCategory.network);

    Log.i('Configuring dependencies...', category: LogCategory.app);
    await configureDependencies();
    Log.i('Dependencies ready', category: LogCategory.app);

    // Initialize crash reporting after DI is ready so Sentry is
    // configured before runApp. If no DSN is configured the service
    // silently degrades to a no-op.
    final crashReporter = getIt<CrashReportingService>();
    crashReporter.init();

    // Capture Flutter framework errors.
    FlutterError.onError = (details) {
      Log.e('Flutter error',
          error: details.exception, stackTrace: details.stack);
      crashReporter.captureError(
        details.exception,
        details.stack,
        context: {'library': details.library},
      );
    };

    // Capture uncaught async errors.
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      Log.e('Uncaught async error', error: error, stackTrace: stackTrace);
      crashReporter.captureError(error, stackTrace);
      return true;
    };
  } catch (error, stackTrace) {
    Log.e('Bootstrap failed', error: error, stackTrace: stackTrace);
    runApp(_BootstrapErrorApp(error: error));
    return;
  }

  Log.i('Launching app', category: LogCategory.app);
  runApp(const AlBatalApp());
}

/// Minimal fallback shown when Supabase/DI initialization fails.
///
/// Deliberately depends on nothing from Supabase, GetIt, or localization,
/// since any of those may be in an inconsistent state after a failed init.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Unable to start the app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode
                      ? '$error'
                      : 'Please check your configuration and try again.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
