import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_batal_elite/app.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';

void main() {
  testWidgets('App boots without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    await tester.pumpWidget(const AlBatalApp());
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
