import 'package:supabase_flutter/supabase_flutter.dart';

import '../../storefront/domain/repositories/auth_session_port.dart';

/// [AuthSessionPort] backed by the Supabase session.
///
/// Lives in the auth data layer (the only place that knows about
/// Supabase auth) and implements the storefront domain port so the
/// checkout page resolves the customer email without importing
/// Supabase into the presentation layer.
final class SupabaseAuthSessionPort implements AuthSessionPort {
  SupabaseAuthSessionPort({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String? currentUserEmail() => _client.auth.currentUser?.email;
}
