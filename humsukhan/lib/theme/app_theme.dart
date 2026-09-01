import 'package:flutter/material.dart';

enum ThemeModeType { light, dark, highContrast }

class AppTokens {
  static const Color deepSage = Color(0xFF506858);
  static const Color primarySage = Color(0xFF587060);
  static const Color mediumSage = Color(0xFF607868);
  static const Color lightSage = Color(0xFF688070);
  static const Color softSage = Color(0xFF789080);
  static const Color darkForest = Color(0xFF3A4F42);
  static const Color deepForest = Color(0xFF2D3E34);
  static const Color forestBlack = Color(0xFF1E2B22);
  static const Color warmIvory = Color(0xFFF8F0E8);
  static const Color creamWhite = Color(0xFFF0E8E0);
  static const Color softCream = Color(0xFFF0F0E0);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color mutedSageGray = Color(0xFFB8C4BC);
  static const Color borderSage = Color(0xFFD0D8D4);
  static const Color disabledSage = Color(0xFFC8D0CC);
  static const Color textOnDark = Color(0xFFF8F0E8);
  static const Color textDeepForest = Color(0xFF2D3E34);
  static const Color textSecondary = Color(0xFF607868);
  static const Color textMuted = Color(0xFF90A898);
  static const Color success = Color(0xFF506858);
  static const Color successLight = Color(0xFF6B8F6B);
  static const Color warning = Color(0xFFB8943C);
  static const Color warningLight = Color(0xFFD4B85C);
  static const Color error = Color(0xFFB85450);
  static const Color errorLight = Color(0xFFD4706C);
  static const Color info = Color(0xFF587060);

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double captionSmall = 12;
  static const double caption = 13;
  static const double body = 15;
  static const double bodyLarge = 17;
  static const double title = 20;
  static const double headline = 28;
  static const double display = 32;
  static const double captionLive = 24;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;
  static const double elevationNone = 0;
  static const double elevationLow = 1;
  static const double elevationMedium = 4;
  static const double elevationHigh = 8;
}

class AppTheme {
  static ThemeData lightTheme({String? fontFamily}) => _buildTheme(
        brightness: Brightness.light,
        fontFamily: fontFamily ?? 'NotoSans',
        primary: AppTokens.deepSage,
        canvas: AppTokens.warmIvory,
        surface: AppTokens.pureWhite,
        text: AppTokens.textDeepForest,
        muted: AppTokens.textSecondary,
        nav: AppTokens.pureWhite,
      );

  static ThemeData darkTheme({String? fontFamily}) => _buildTheme(
        brightness: Brightness.dark,
        fontFamily: fontFamily ?? 'NotoSans',
        primary: AppTokens.softSage,
        canvas: AppTokens.forestBlack,
        surface: AppTokens.darkForest,
        text: AppTokens.warmIvory,
        muted: AppTokens.mutedSageGray,
        nav: AppTokens.darkForest,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required String fontFamily,
    required Color primary,
    required Color canvas,
    required Color surface,
    required Color text,
    required Color muted,
    required Color nav,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness, surface: surface).copyWith(
      primary: primary,
      onPrimary: dark ? AppTokens.forestBlack : AppTokens.textOnDark,
      primaryContainer: primary.withValues(alpha: .16),
      onPrimaryContainer: text,
      secondary: AppTokens.mediumSage,
      onSecondary: dark ? AppTokens.forestBlack : AppTokens.textOnDark,
      surface: surface,
      surfaceContainer: dark ? AppTokens.forestBlack : AppTokens.warmIvory,
      surfaceContainerHighest: dark ? AppTokens.darkForest : AppTokens.softCream,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: dark ? AppTokens.mutedSageGray.withValues(alpha: .45) : AppTokens.borderSage,
      outlineVariant: dark ? AppTokens.darkForest : AppTokens.mutedSageGray,
      error: dark ? AppTokens.errorLight : AppTokens.error,
      onError: AppTokens.pureWhite,
    );
    final border = scheme.outline.withValues(alpha: dark ? .7 : .75);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas.withValues(alpha: .97),
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: AppTokens.title, fontWeight: FontWeight.w600, color: text),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(fontSize: AppTokens.display, fontWeight: FontWeight.w600, letterSpacing: -.8, color: text),
        headlineSmall: TextStyle(fontSize: AppTokens.headline, fontWeight: FontWeight.w600, letterSpacing: -.5, color: text),
        titleLarge: TextStyle(fontSize: AppTokens.title, fontWeight: FontWeight.w600, color: text),
        titleMedium: TextStyle(fontSize: AppTokens.bodyLarge, fontWeight: FontWeight.w600, color: text),
        bodyLarge: TextStyle(fontSize: AppTokens.bodyLarge, color: text, height: 1.45),
        bodyMedium: TextStyle(fontSize: AppTokens.body, color: text, height: 1.45),
        bodySmall: TextStyle(fontSize: AppTokens.caption, color: muted, height: 1.4),
        labelLarge: TextStyle(fontSize: AppTokens.body, fontWeight: FontWeight.w600, color: text),
        labelMedium: TextStyle(fontSize: AppTokens.captionSmall, fontWeight: FontWeight.w600, color: muted, letterSpacing: .4),
        labelSmall: TextStyle(fontSize: AppTokens.captionSmall, fontWeight: FontWeight.w600, color: muted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg), side: BorderSide(color: border)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: primary,
          foregroundColor: dark ? AppTokens.forestBlack : AppTokens.textOnDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(fontSize: AppTokens.body, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: .55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(fontSize: AppTokens.body, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: primary)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppTokens.forestBlack : AppTokens.pureWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd), borderSide: BorderSide(color: scheme.error)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: nav,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: .14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? primary : muted, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontSize: AppTokens.captionSmall, fontWeight: FontWeight.w600, color: states.contains(WidgetState.selected) ? primary : muted)),
      ),
      chipTheme: ChipThemeData(backgroundColor: scheme.surfaceContainerHighest, selectedColor: primary.withValues(alpha: .14), side: BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusFull))),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusXl))),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl)))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primary, foregroundColor: dark ? AppTokens.forestBlack : AppTokens.textOnDark, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: dark ? AppTokens.deepSage : AppTokens.deepForest, contentTextStyle: const TextStyle(color: AppTokens.textOnDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: primary.withValues(alpha: .12)),
    );
  }

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
  static Color captionBubbleColor({required bool isOwn, required bool isDarkMode}) => isOwn ? (isDarkMode ? AppTokens.deepSage : AppTokens.warmIvory) : (isDarkMode ? AppTokens.darkForest : AppTokens.pureWhite);
  static Color alertColor(String severity) { switch (severity) { case 'critical': return AppTokens.error; case 'warning': return AppTokens.warning; default: return AppTokens.info; } }
}
