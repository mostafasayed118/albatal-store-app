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
    await tester.pump();
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
