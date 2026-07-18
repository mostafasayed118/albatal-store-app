import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Shows a colored banner at the top in development builds.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return Banner(
      message: 'DEV',
      location: BannerLocation.topEnd,
      color: Colors.orange,
      textStyle: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      child: child,
    );
  }
}
