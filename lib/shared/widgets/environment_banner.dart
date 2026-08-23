import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Shows a colored banner at the top in development builds.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    // Surface the connected Supabase project ref so a developer can never
    // mistake staging for production while testing against live data.
    const url = String.fromEnvironment('SUPABASE_URL');
    final host = Uri.tryParse(url)?.host ?? '';
    final parts = host.split('.');
    final ref = parts.length > 2 ? parts[parts.length - 3] : '';
    final label = ref.isEmpty ? 'DEV' : 'DEV·$ref';
    return Banner(
      message: label,
      location: BannerLocation.topEnd,
      color: Colors.orange,
      textStyle: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      child: child,
    );
  }
}
