import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for dev/staging/production.
class EnvConfig {
  const EnvConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get paymobApiKey => dotenv.env['PAYMOB_API_KEY'] ?? '';
  static String get paymobIntegrationId => dotenv.env['PAYMOB_INTEGRATION_ID'] ?? '';
  static String get vodafoneCashMerchantCode => dotenv.env['VODAFONE_CASH_MERCHANT_CODE'] ?? '';

  /// Current environment name.
  static String get environment => kDebugMode ? 'development' : 'production';

  /// Whether we're in development mode.
  static bool get isDevelopment => kDebugMode;

  /// Validate that all required env vars are present.
  static List<String> validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }
}
