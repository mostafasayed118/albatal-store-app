import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:al_batal_elite/app.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
    );
    await configureDependencies();
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('App boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const AlBatalApp());
    await tester.pump(); // splash builds
    // First-run boot lands on /splash (1100ms logo animation) then routes to
    // /onboarding. Drive the animation out and settle the router so no
    // ticker/timer is pending at invariant-check time.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink()); // explicit unmount
  });
}
