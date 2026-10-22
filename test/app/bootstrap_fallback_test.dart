import 'package:al_batal_elite/bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bootstrap is the composition root: it reads the compile-time config and
/// wires DI before the app runs.
///
/// In a test build there is no `SUPABASE_URL` (the value comes from
/// `String.fromEnvironment`), so `SupabaseConfig.initialize()` throws and
/// bootstrap must fall back to the "unable to start" screen instead of
/// crashing into a red error screen. This pins that guard — the one path
/// a user can hit on a misconfigured build.
void main() {
  testWidgets('a missing Supabase config falls back to the bootstrap error app',
      (tester) async {
    await bootstrap();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unable to start the app'), findsOneWidget);
  });
}
