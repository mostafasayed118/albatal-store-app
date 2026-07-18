import 'package:flutter/material.dart';

/// Al Batal Elite's tactile, textile-inspired visual system.
abstract final class AppTheme {
  static const emerald = Color(0xFF064E3B);
  static const gold = Color(0xFFD97706);
  static const offWhite = Color(0xFFFAFAFA);
  static const charcoal = Color(0xFF121212);
  static const slate = Color(0xFF1E293B);
  static const terracotta = Color(0xFFBA1A1A);

  static const cardRadius = BorderRadius.all(Radius.circular(16));
  static const controlRadius = BorderRadius.all(Radius.circular(8));

  static ThemeData light() => _theme(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: emerald,
          onPrimary: Colors.white,
          secondary: gold,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF17201C),
          error: terracotta,
          outline: Color(0xFFB7C1BB),
        ),
        scaffold: offWhite,
        card: Colors.white,
      );

  static ThemeData dark() => _theme(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: Color(0xFF95D3BA),
          onPrimary: Color(0xFF002117),
          secondary: Color(0xFFFFB77D),
          onSecondary: Color(0xFF2F1500),
          surface: slate,
          onSurface: Color(0xFFF0F4F1),
          error: Color(0xFFFFB4AB),
          outline: Color(0xFFBFC9C3),
        ),
        scaffold: charcoal,
        card: slate,
      );

  static ThemeData _theme({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['sans-serif'],
      splashFactory: InkSparkle.splashFactory,
    );
    final text = base.textTheme.copyWith(
      displayLarge: _montserrat(
          base.textTheme.displayLarge, 48, FontWeight.w700, -0.96, 56 / 48),
      headlineLarge: _montserrat(
          base.textTheme.headlineLarge, 32, FontWeight.w700, -0.64, 40 / 32),
      headlineMedium: _montserrat(
          base.textTheme.headlineMedium, 24, FontWeight.w700, -0.32, 32 / 24),
      titleLarge: _montserrat(
          base.textTheme.titleLarge, 20, FontWeight.w600, -0.2, 28 / 20),
      titleMedium: _montserrat(
          base.textTheme.titleMedium, 16, FontWeight.w600, 0, 24 / 16),
      bodyLarge:
          base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 28 / 18),
      bodyMedium:
          base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 24 / 16),
      labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: .14),
      labelSmall: base.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: .6),
    );
    final subtleShadow = BoxShadow(
        color: scheme.primary
            .withValues(alpha: brightness == Brightness.light ? .035 : .12),
        blurRadius: 8,
        offset: const Offset(0, 3));
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
          backgroundColor: scaffold,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: text.titleLarge),
      cardTheme: CardThemeData(
          color: card,
          margin: EdgeInsets.zero,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: cardRadius)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .55)),
        border: const OutlineInputBorder(
            borderRadius: controlRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: controlRadius,
            borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: text.labelLarge,
        minimumSize: const Size.fromHeight(50),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        elevation: 0,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: text.labelLarge,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.primary, width: 1.25),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      )),
      chipTheme: base.chipTheme.copyWith(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
          labelStyle: text.labelSmall),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: .12),
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        elevation: 0,
        shadowColor: subtleShadow.color,
      ),
      dividerTheme: DividerThemeData(
          color: scheme.outline.withValues(alpha: .35), space: 1),
    );
  }

  static TextStyle? _montserrat(TextStyle? style, double size,
          FontWeight weight, double spacing, double height) =>
      style?.copyWith(
          fontFamily: 'Montserrat',
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height);
}
