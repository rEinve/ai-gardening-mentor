import 'package:flutter/material.dart';

/// Google Material Design 3 Botanical Emerald theme
/// Mirrors src/styles/m3-tokens.css across Flutter mobile, web, and desktop.
class AppTheme {
  static const Color primaryLight = Color(0xFF1E6B37);
  static const Color primaryContainerLight = Color(0xFFA6F5B1);
  static const Color secondaryLight = Color(0xFF526350);
  static const Color tertiaryLight = Color(0xFF386568);
  static const Color surfaceLight = Color(0xFFF7FBF2);

  static const Color primaryDark = Color(0xFF8BD897);
  static const Color surfaceDark = Color(0xFF101510);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryLight,
      brightness: Brightness.light,
      primary: primaryLight,
      primaryContainer: primaryContainerLight,
      secondary: secondaryLight,
      tertiary: tertiaryLight,
      surface: surfaceLight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceLight,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.dark,
      primary: primaryDark,
      surface: surfaceDark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceDark,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
