import 'package:al_batal_elite/shared/services/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validate reports both missing compile-time Supabase values', () {
    final missing = EnvConfig.validate();

    expect(EnvConfig.supabaseUrl, isEmpty);
    expect(EnvConfig.supabaseAnonKey, isEmpty);
    expect(missing, contains('SUPABASE_URL'));
    expect(missing, contains('SUPABASE_ANON_KEY'));
  });
}
