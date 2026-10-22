import 'package:al_batal_elite/shared/services/env_config.dart';
import 'package:al_batal_elite/shared/services/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Covers the missing-env guard and the authenticated-user getters. The
/// success leg of `initialize()` (non-empty URL + key) cannot run in the
/// default test build because both values are compile-time constants that are
/// empty unless the tests are started with `--dart-define`.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  test('initialize rejects a missing SUPABASE_URL before any network call',
      () async {
    if (EnvConfig.supabaseUrl.isNotEmpty) {
      // Started with --dart-define; the empty-URL branch is unreachable.
      return;
    }

    await expectLater(
      SupabaseConfig.initialize(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('currentUser is null and isAuthenticated is false without a session',
      () {
    expect(SupabaseConfig.currentUser, isNull);
    expect(SupabaseConfig.isAuthenticated, isFalse);
  });
}
