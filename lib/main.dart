import 'package:flutter/widgets.dart';

import 'app.dart';
import 'shared/services/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const AlBatalApp());
}
