import 'package:flutter/widgets.dart';

import 'app.dart';
import 'shared/services/service_locator.dart';
import 'shared/services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await configureDependencies();
  runApp(const AlBatalApp());
}
