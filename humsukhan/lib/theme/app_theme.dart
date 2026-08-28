import 'package:flutter/material.dart';

enum ThemeModeType { light, dark, highContrast }

class AppTheme {
  static const String _fontFamily = 'sans-serif';

  // Color Palette
  static const Color primaryLight = Color(0xFF2E5B88);
  static const Color primaryDark = Color(0xFF6BA4D9);
  static const Color primaryHighContrast = Color(0xFF000000);
  static const Color secondaryLight = Color(0xFF4CAF50);
  static const Color secondaryDark = Color(0xFF81C784);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundHighContrast = Color(0xFF000000);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceHighContrast = Color(0xFF1A1A1A);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textPrimaryHighContrast = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textSecondaryHighContrast = Color(0xFFCCCCCC);
  static const Color errorLight = Color(0xFFD32F2F);
  static const Color errorDark = Color(0xFFEF5350);
  static const Color warningLight = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF81C784);
  static const Color captionBubbleOwn = Color(0xFFE3F2FD);
  static const Color captionBubbleOther = Color(0xFFF5F5F5);
  static const Color captionBubbleOwnDark = Color(0xFF1A3A5C);
  static const Color captionBubbleOtherDark = Color(0xFF2A2A2A);
  static const Color alertCritical = Color(0xFFD32F2F);
  static const Color alertWarning = Color(0xFFFF9800);
  static const Color alertInfo = Color(0xFF2196F3);

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Text Sizes
  static const double textCaption = 14.0;
  static const double textBody = 16.0;
  static const double textBodyLarge = 18.0;
  static const double textTitle = 20.0;
  static const double textHeadline = 24.0;
  static const double textDisplay = 32.0;
  static const double textCaptionLive = 24.0;

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: surfaceLight,
        error: errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onSurfaceVariant: textSecondaryLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      fontFamily: _fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: textDisplay, fontWeight: FontWeight.bold, color: textPrimaryLight),
        headlineMedium: TextStyle(fontSize: textHeadline, fontWeight: FontWeight.bold, color: textPrimaryLight),
        titleLarge: TextStyle(fontSize: textTitle, fontWeight: FontWeight.w600, color: textPrimaryLight),
        titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: textPrimaryLight),
        bodyLarge: TextStyle(fontSize: textBodyLarge, color: textPrimaryLight),
        bodyMedium: TextStyle(fontSize: textBody, color: textPrimaryLight),
        bodySmall: TextStyle(fontSize: textCaption, color: textSecondaryLight),
        labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        elevation: elevationLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMD)),
        color: surfaceLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMD)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: elevationNone,
        centerTitle: true,
        backgroundColor: backgroundLight,
        foregroundColor: textPrimaryLight,
        titleTextStyle: TextStyle(
          fontSize: textTitle,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: surfaceDark,
        error: errorDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
        onSurfaceVariant: textSecondaryDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: _fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: textDisplay, fontWeight: FontWeight.bold, color: textPrimaryDark),
        headlineMedium: TextStyle(fontSize: textHeadline, fontWeight: FontWeight.bold, color: textPrimaryDark),
        titleLarge: TextStyle(fontSize: textTitle, fontWeight: FontWeight.w600, color: textPrimaryDark),
        titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: textPrimaryDark),
        bodyLarge: TextStyle(fontSize: textBodyLarge, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: textBody, color: textPrimaryDark),
        bodySmall: TextStyle(fontSize: textCaption, color: textSecondaryDark),
        labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        elevation: elevationLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMD)),
        color: surfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMD)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: elevationNone,
        centerTitle: true,
        backgroundColor: backgroundDark,
        foregroundColor: textPrimaryDark,
        titleTextStyle: TextStyle(
          fontSize: textTitle,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
    );
  }

  static ThemeData highContrastTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.white,
        secondary: Colors.yellow,
        surface: surfaceHighContrast,
        error: Colors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryHighContrast,
        onSurfaceVariant: textSecondaryHighContrast,
      ),
      scaffoldBackgroundColor: backgroundHighContrast,
      fontFamily: _fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: textDisplay, fontWeight: FontWeight.bold, color: textPrimaryHighContrast),
        headlineMedium: TextStyle(fontSize: textHeadline, fontWeight: FontWeight.bold, color: textPrimaryHighContrast),
        titleLarge: TextStyle(fontSize: textTitle, fontWeight: FontWeight.bold, color: textPrimaryHighContrast),
        titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: textPrimaryHighContrast),
        bodyLarge: TextStyle(fontSize: textBodyLarge, color: textPrimaryHighContrast),
        bodyMedium: TextStyle(fontSize: textBody, color: textPrimaryHighContrast),
        bodySmall: TextStyle(fontSize: textCaption, color: textSecondaryHighContrast),
        labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: textPrimaryHighContrast),
      ),
      cardTheme: CardThemeData(
        elevation: elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        color: surfaceHighContrast,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationNone,
          padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: elevationNone,
        centerTitle: true,
        backgroundColor: backgroundHighContrast,
        foregroundColor: textPrimaryHighContrast,
        titleTextStyle: TextStyle(
          fontSize: textTitle,
          fontWeight: FontWeight.bold,
          color: textPrimaryHighContrast,
        ),
      ),
    );
  }

  static Color captionBubbleColor({required bool isOwn, required bool isDarkMode, required bool isHighContrast}) {
    if (isHighContrast) return Colors.black;
    if (isOwn) return isDarkMode ? captionBubbleOwnDark : captionBubbleOwn;
    return isDarkMode ? captionBubbleOtherDark : captionBubbleOther;
  }

  static Color alertColor(String severity) {
    switch (severity) {
      case 'critical':
        return alertCritical;
      case 'warning':
        return alertWarning;
      default:
        return alertInfo;
    }
  }
}
