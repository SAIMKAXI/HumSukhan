import 'package:flutter/material.dart';

enum ThemeModeType { light, dark, highContrast }

// ===== BRAND DESIGN TOKENS =====
// Derived directly from the HumSukhan logo color extraction
class AppTokens {
  // Primary Sage Greens (from logo dominant colors)
  static const Color deepSage = Color(0xFF506858);        // #506858 - Primary brand
  static const Color primarySage = Color(0xFF587060);     // #587060 - Primary variant
  static const Color mediumSage = Color(0xFF607868);      // #607868 - Medium sage
  static const Color lightSage = Color(0xFF688070);       // #688070 - Light sage
  static const Color softSage = Color(0xFF789080);        // #789080 - Soft sage

  // Dark Forest (darker extensions)
  static const Color darkForest = Color(0xFF3A4F42);      // Dark forest for dark mode
  static const Color deepForest = Color(0xFF2D3E34);      // Deepest green-black
  static const Color forestBlack = Color(0xFF1E2B22);     // Near-black green

  // Warm Ivory (from logo light areas)
  static const Color warmIvory = Color(0xFFF8F0E8);       // #F8F0E8 - Primary light
  static const Color creamWhite = Color(0xFFF0E8E0);      // #F0E8E0 - Card surface
  static const Color softCream = Color(0xFFF0F0E0);       // #F0F0E0 - Secondary surface
  static const Color pureWhite = Color(0xFFFFFFFF);       // Elevated surfaces

  // Muted Sage Gray (supporting neutral)
  static const Color mutedSageGray = Color(0xFFB8C4BC);   // Borders, dividers
  static const Color borderSage = Color(0xFFD0D8D4);      // Light borders
  static const Color disabledSage = Color(0xFFC8D0CC);    // Disabled controls

  // Text Colors
  static const Color textOnDark = Color(0xFFF8F0E8);      // Text on dark sage
  static const Color textDeepForest = Color(0xFF2D3E34);  // Primary text light mode
  static const Color textSecondary = Color(0xFF607868);    // Secondary text
  static const Color textMuted = Color(0xFF90A898);       // Muted text

  // Status Colors (accessible, harmonious with sage palette)
  static const Color success = Color(0xFF506858);         // Uses brand sage
  static const Color successLight = Color(0xFF6B8F6B);
  static const Color warning = Color(0xFFB8943C);         // Warm amber
  static const Color warningLight = Color(0xFFD4B85C);
  static const Color error = Color(0xFFB85450);           // Accessible red
  static const Color errorLight = Color(0xFFD4706C);
  static const Color info = Color(0xFF587060);            // Sage info

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border Radius (organic, inspired by logo curves)
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Text Sizes
  static const double captionSmall = 11.0;
  static const double caption = 13.0;
  static const double body = 15.0;
  static const double bodyLarge = 17.0;
  static const double title = 20.0;
  static const double headline = 24.0;
  static const double display = 32.0;
  static const double captionLive = 24.0;
}

// ===== LIGHT THEME =====
class AppTheme {
  static ThemeData lightTheme() {
    // Using AppTokens directly

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppTokens.deepSage,
        primaryContainer: AppTokens.softSage,
        secondary: AppTokens.mediumSage,
        secondaryContainer: AppTokens.softCream,
        surface: AppTokens.pureWhite,
        surfaceContainer: AppTokens.warmIvory,
        error: AppTokens.error,
        onPrimary: AppTokens.textOnDark,
        onSecondary: AppTokens.textOnDark,
        onSurface: AppTokens.textDeepForest,
        onSurfaceVariant: AppTokens.textSecondary,
        outline: AppTokens.borderSage,
        outlineVariant: AppTokens.mutedSageGray,
      ),
      scaffoldBackgroundColor: AppTokens.warmIvory,
      appBarTheme: AppBarTheme(
        elevation: AppTokens.elevationNone,
        scrolledUnderElevation: AppTokens.elevationLow,
        centerTitle: true,
        backgroundColor: AppTokens.warmIvory,
        foregroundColor: AppTokens.textDeepForest,
        titleTextStyle: TextStyle(
          fontSize: AppTokens.title,
          fontWeight: FontWeight.w600,
          color: AppTokens.textDeepForest,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.elevationLow,
        color: AppTokens.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: AppTokens.borderSage.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.deepSage,
          foregroundColor: AppTokens.textOnDark,
          elevation: AppTokens.elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: AppTokens.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.deepSage,
          side: const BorderSide(color: AppTokens.deepSage),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.deepSage,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.borderSage),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.borderSage),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.deepSage, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.pureWhite,
        indicatorColor: AppTokens.deepSage.withValues(alpha: 0.15),
        elevation: AppTokens.elevationMedium,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTokens.deepSage,
            );
          }
          return TextStyle(fontSize: 12, color: AppTokens.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppTokens.deepSage, size: 24);
          }
          return IconThemeData(color: AppTokens.textMuted, size: 24);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSage,
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.darkForest,
        contentTextStyle: const TextStyle(color: AppTokens.textOnDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.softCream,
        selectedColor: AppTokens.deepSage.withValues(alpha: 0.15),
        side: const BorderSide(color: AppTokens.borderSage),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        labelStyle: TextStyle(color: AppTokens.textDeepForest, fontSize: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.deepSage,
        foregroundColor: AppTokens.textOnDark,
        elevation: AppTokens.elevationMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.deepSage;
          return AppTokens.mutedSageGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.deepSage.withValues(alpha: 0.3);
          return AppTokens.disabledSage;
        }),
      ),
    );
  }

  // ===== DARK THEME =====
  static ThemeData darkTheme() {
    // Using AppTokens directly

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppTokens.softSage,
        primaryContainer: AppTokens.deepSage,
        secondary: AppTokens.mediumSage,
        secondaryContainer: AppTokens.darkForest,
        surface: AppTokens.deepForest,
        surfaceContainer: AppTokens.forestBlack,
        error: AppTokens.errorLight,
        onPrimary: AppTokens.forestBlack,
        onSecondary: AppTokens.forestBlack,
        onSurface: AppTokens.warmIvory,
        onSurfaceVariant: AppTokens.mutedSageGray,
        outline: AppTokens.mutedSageGray,
        outlineVariant: AppTokens.darkForest,
      ),
      scaffoldBackgroundColor: AppTokens.forestBlack,
      appBarTheme: AppBarTheme(
        elevation: AppTokens.elevationNone,
        scrolledUnderElevation: AppTokens.elevationLow,
        centerTitle: true,
        backgroundColor: AppTokens.forestBlack,
        foregroundColor: AppTokens.warmIvory,
        titleTextStyle: TextStyle(
          fontSize: AppTokens.title,
          fontWeight: FontWeight.w600,
          color: AppTokens.warmIvory,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.elevationLow,
        color: AppTokens.darkForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: AppTokens.mutedSageGray.withValues(alpha: 0.2)),
        ),
        margin: EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.deepSage,
          foregroundColor: AppTokens.warmIvory,
          elevation: AppTokens.elevationLow,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.softSage,
          side: const BorderSide(color: AppTokens.softSage),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppTokens.softSage),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.darkForest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: AppTokens.mutedSageGray.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: AppTokens.mutedSageGray.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.softSage, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.darkForest,
        indicatorColor: AppTokens.softSage.withValues(alpha: 0.2),
        elevation: AppTokens.elevationMedium,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.softSage);
          }
          return TextStyle(fontSize: 12, color: AppTokens.mutedSageGray);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppTokens.softSage, size: 24);
          }
          return IconThemeData(color: AppTokens.mutedSageGray, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: AppTokens.mutedSageGray.withValues(alpha: 0.2),
        thickness: 0.5,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.darkForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.deepSage,
        contentTextStyle: const TextStyle(color: AppTokens.warmIvory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.darkForest,
        selectedColor: AppTokens.deepSage.withValues(alpha: 0.3),
        side: BorderSide(color: AppTokens.mutedSageGray.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        labelStyle: TextStyle(color: AppTokens.warmIvory, fontSize: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.deepSage,
        foregroundColor: AppTokens.warmIvory,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.softSage;
          return AppTokens.mutedSageGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.deepSage.withValues(alpha: 0.4);
          return AppTokens.darkForest;
        }),
      ),
    );
  }

  // ===== BACKWARD-COMPATIBLE ALIASES =====
  static const Color primaryLight = AppTokens.deepSage;
  static const Color primaryDark = AppTokens.softSage;
  static const Color secondaryLight = AppTokens.mediumSage;
  static const Color secondaryDark = AppTokens.lightSage;
  static const Color backgroundLight = AppTokens.warmIvory;
  static const Color backgroundDark = AppTokens.forestBlack;
  static const Color surfaceLight = AppTokens.pureWhite;
  static const Color surfaceDark = AppTokens.darkForest;
  static const Color textPrimaryLight = AppTokens.textDeepForest;
  static const Color textPrimaryDark = AppTokens.warmIvory;
  static const Color textSecondaryLight = AppTokens.textSecondary;
  static const Color textSecondaryDark = AppTokens.mutedSageGray;
  static const Color errorLight = AppTokens.error;
  static const Color errorDark = AppTokens.errorLight;
  static const Color warningLight = AppTokens.warning;
  static const Color warningDark = AppTokens.warningLight;
  static const Color successLight = AppTokens.successLight;
  static const Color successDark = AppTokens.success;
  static const double spacingSM = AppTokens.sm;
  static const double spacingMD = AppTokens.md;
  static const double spacingLG = AppTokens.lg;
  static const double spacingXL = AppTokens.xl;
  static const double radiusSM = AppTokens.radiusSm;
  static const double radiusMD = AppTokens.radiusMd;
  static const double radiusLG = AppTokens.radiusLg;
  static const double radiusXL = AppTokens.radiusXl;
  static const double radiusFull = AppTokens.radiusFull;
  static const double elevationNone = AppTokens.elevationNone;
  static const double elevationLow = AppTokens.elevationLow;
  static const double elevationMedium = AppTokens.elevationMedium;
  static const double elevationHigh = AppTokens.elevationHigh;

  // ===== HELPER METHODS =====
  static Color captionBubbleColor({required bool isOwn, required bool isDarkMode}) {
    if (isOwn) return isDarkMode ? AppTokens.deepSage : AppTokens.warmIvory;
    return isDarkMode ? AppTokens.darkForest : AppTokens.pureWhite;
  }

  static Color alertColor(String severity) {
    switch (severity) {
      case 'critical': return AppTokens.error;
      case 'warning': return AppTokens.warning;
      default: return AppTokens.info;
    }
  }
}
