import 'package:flutter/material.dart';

/// Central color tokens for Al Batal Elite — single source of truth.
///
/// Mirrors DESIGN.md exactly (Stitch-exact light palette, hand-tuned dark
/// palette). [AppTheme] builds both ThemeData variants from these values;
/// call sites must reference this file instead of hardcoding hex literals
/// or Material palette colors.
abstract final class AppColors {
  // Brand & accent (light mode).
  static const primary = Color(0xFF003527);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF064E3B);
  static const secondary = Color(0xFF904D00);
  static const secondaryContainer = Color(0xFFFE932C);
  static const tertiary = Color(0xFF531E00);

  // Semantic — light mode surfaces & content.
  static const background = Color(0xFFF9F9F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F3F3);
  static const surfaceContainer = Color(0xFFEEEEEE);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const textPrimary = Color(0xFF1A1C1C);
  static const outline = Color(0xFF707974);
  static const outlineVariant = Color(0xFFBFC9C3);

  // Semantic — status colors.
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF064E3B); // brand emerald = positive
  static const warning = Color(0xFF7C2D12); // env banner umber

  // Dark mode (hand-tuned, never an inversion of light).
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E293B);
  static const darkPrimary = Color(0xFF95D3BA);
  static const darkOnPrimary = Color(0xFF002117);
  static const darkSecondary = Color(0xFFFFB77D);
  static const darkOnSecondary = Color(0xFF2F1500);
  static const darkText = Color(0xFFF0F4F1);
  static const darkOutline = Color(0xFFBFC9C3);
  static const darkError = Color(0xFFFFB4AB);

  // Structural (scrims, blends, on-image content).
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const scrim = Color(0x8A000000); // == Colors.black54
  static const transparent = Color(0x00000000);

  // Legacy warm accent (DESIGN.md alias; prefer secondary/secondaryContainer).
  static const gold = Color(0xFFD97706);
}
