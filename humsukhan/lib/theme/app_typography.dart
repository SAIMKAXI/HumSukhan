import 'package:flutter/material.dart';

import '../utils/urdu_text.dart';

/// The app's two typefaces, used together on every screen: Noto Sans for
/// Latin letters and Noto Nastaliq Urdu for Urdu. Each script always renders
/// in its own face, whichever language the app is in, so neither falls back
/// to a system font.
///
/// Nastaliq letters rise and fall much further than Latin ones, and the
/// font's own word space is so narrow that neighbouring words look joined.
/// Urdu text therefore gets a taller line and a wider word gap, both scaled
/// to its size.
class AppTypography {
  AppTypography._();

  static const latin = 'NotoSans';
  static const urdu = 'NotoNastaliqUrdu';

  /// Line height for Urdu text, as a multiple of its size.
  static const urduLineHeight = 2.0;

  /// Extra space between Urdu words, as a fraction of the text size.
  static const urduWordSpacing = 0.25;

  /// [height] for Latin text; in Urdu, null, so the taller Urdu line height
  /// from the theme is kept. For styles that set a line height of their own.
  static double? latinLineHeight(BuildContext context, double height) =>
      Localizations.maybeLocaleOf(context)?.languageCode == 'ur' ? null : height;

  /// [style] set in Nastaliq with Urdu line height and word spacing.
  static TextStyle urduStyle(TextStyle style) => style.copyWith(
        fontFamily: urdu,
        fontFamilyFallback: const [latin],
        height: urduLineHeight,
        wordSpacing: (style.fontSize ?? 14) * urduWordSpacing,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// For text whose script is only known at run time, such as captions and
  /// notes: Urdu metrics when [text] contains Urdu, [style] otherwise.
  static TextStyle forText(String text, TextStyle style) => containsUrduScript(text) ? urduStyle(style) : style;

  /// [theme] with every text style it hands out set for the app language:
  /// Urdu metrics throughout in Urdu, and Nastaliq as the fallback for any
  /// Urdu words shown in English.
  static ThemeData apply(ThemeData theme, {required bool urdu}) {
    TextStyle style(TextStyle s) => urdu ? urduStyle(s) : s.copyWith(fontFamily: latin, fontFamilyFallback: const [AppTypography.urdu]);
    TextStyle? maybe(TextStyle? s) => s == null ? null : style(s);
    WidgetStateProperty<TextStyle?>? states(WidgetStateProperty<TextStyle?>? p) =>
        p == null ? null : WidgetStateProperty.resolveWith((s) => maybe(p.resolve(s)));
    ButtonStyle? button(ButtonStyle? b) => b?.copyWith(textStyle: states(b.textStyle));
    TextTheme text(TextTheme t) => t.copyWith(
          displayLarge: maybe(t.displayLarge),
          displayMedium: maybe(t.displayMedium),
          displaySmall: maybe(t.displaySmall),
          headlineLarge: maybe(t.headlineLarge),
          headlineMedium: maybe(t.headlineMedium),
          headlineSmall: maybe(t.headlineSmall),
          titleLarge: maybe(t.titleLarge),
          titleMedium: maybe(t.titleMedium),
          titleSmall: maybe(t.titleSmall),
          bodyLarge: maybe(t.bodyLarge),
          bodyMedium: maybe(t.bodyMedium),
          bodySmall: maybe(t.bodySmall),
          labelLarge: maybe(t.labelLarge),
          labelMedium: maybe(t.labelMedium),
          labelSmall: maybe(t.labelSmall),
        );

    return theme.copyWith(
      textTheme: text(theme.textTheme),
      primaryTextTheme: text(theme.primaryTextTheme),
      appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: maybe(theme.appBarTheme.titleTextStyle)),
      navigationBarTheme: theme.navigationBarTheme.copyWith(labelTextStyle: states(theme.navigationBarTheme.labelTextStyle)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button(theme.elevatedButtonTheme.style)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button(theme.outlinedButtonTheme.style)),
      textButtonTheme: TextButtonThemeData(style: button(theme.textButtonTheme.style)),
      filledButtonTheme: FilledButtonThemeData(style: button(theme.filledButtonTheme.style)),
      snackBarTheme: theme.snackBarTheme.copyWith(contentTextStyle: maybe(theme.snackBarTheme.contentTextStyle)),
      chipTheme: theme.chipTheme.copyWith(labelStyle: maybe(theme.chipTheme.labelStyle)),
    );
  }
}
