import 'package:flutter/foundation.dart';

/// One onboarding slide's content (was private `_OnboardingStep`).
@immutable
final class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.body,
    required this.imagePath,
  });

  final String title;
  final String body;
  final String imagePath;
}
