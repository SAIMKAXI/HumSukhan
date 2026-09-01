import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/main_scaffold.dart';
import 'l10n/app_strings.dart';
import 'services/supabase_service.dart';
import 'services/sound_detection_service.dart';

@pragma('vm:entry-point')
Future<void> environmentalMonitoringBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.humsukhan/environmental_monitor');
  final detector = SoundDetectionService.instance;

  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') {
      detector.stopMonitoring();
      await channel.invokeMethod('pipelineState', {'state': 'OFF'});
      return true;
    }
    return null;
  });

  detector.onSoundDetected = (event) {
    channel.invokeMethod('event', <String, dynamic>{
      'type': event.type,
      'confidence': event.confidence,
      'severity': event.severity,
      'timestamp': event.timestamp.toIso8601String(),
    });
  };

  final started = await detector.startMonitoring(permissionAlreadyGranted: true);
  await channel.invokeMethod('pipelineState', {'state': started ? 'ACTIVE' : 'ERROR'});
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HumSukhanApp());
}

class HumSukhanApp extends StatefulWidget {
  const HumSukhanApp({super.key});
  @override
  State<HumSukhanApp> createState() => _HumSukhanAppState();
}

class _HumSukhanAppState extends State<HumSukhanApp> {
  late final AuthProvider _authProvider;
  bool _showSplash = true;
  String _lastLanguage = 'en';
  String? _lastSyncedSettingsUserId;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider()..addListener(_handleAuthChanged);
    unawaited(_initializeStartupServices());
  }

  Future<void> _initializeStartupServices() async {
    try {
      await SupabaseService.instance.initialize().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Supabase startup initialization failed: $e');
    }

    if (!mounted) return;
    _authProvider.refresh();
  }

  void _handleAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authProvider
      ..removeListener(_handleAuthChanged)
      ..dispose();
    super.dispose();
  }

  ThemeData _highContrastTheme({String? fontFamily, required bool dark}) {
    final foreground = dark ? Colors.white : Colors.black;
    final background = dark ? const Color(0xFF050A07) : Colors.white;
    final surface = dark ? const Color(0xFF101812) : Colors.white;
    final primary = dark ? const Color(0xFFB8FFD0) : Colors.black;
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: fontFamily ?? 'NotoSans',
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: dark ? Colors.black : Colors.white,
        primaryContainer: dark ? const Color(0xFF1A2A20) : Colors.white,
        onPrimaryContainer: foreground,
        secondary: primary,
        onSecondary: dark ? Colors.black : Colors.white,
        secondaryContainer: surface,
        onSecondaryContainer: foreground,
        tertiary: primary,
        onTertiary: dark ? Colors.black : Colors.white,
        tertiaryContainer: surface,
        onTertiaryContainer: foreground,
        error: dark ? const Color(0xFFFF8A80) : const Color(0xFF8B0000),
        onError: Colors.white,
        surface: surface,
        onSurface: foreground,
        surfaceContainerHighest: surface,
        onSurfaceVariant: dark ? const Color(0xFFE8F2EC) : Colors.black,
        outline: foreground,
        outlineVariant: foreground,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: foreground,
        onInverseSurface: background,
        inversePrimary: dark ? Colors.black : Colors.white,
      ),
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: foreground, elevation: 0),
      cardTheme: CardThemeData(color: surface, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: foreground, width: 1.5))),
      dividerTheme: DividerThemeData(color: foreground, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: dark ? Colors.black : Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: primary, side: BorderSide(color: primary, width: 1.5))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: foreground, width: 1.5)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primary, width: 2.5))),
      chipTheme: ChipThemeData(backgroundColor: surface, side: BorderSide(color: foreground, width: 1.25), labelStyle: TextStyle(color: foreground)),
      switchTheme: SwitchThemeData(thumbColor: WidgetStatePropertyAll(primary), trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary.withValues(alpha: .85) : surface)),
      textTheme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light, fontFamily: fontFamily ?? 'NotoSans').textTheme.apply(bodyColor: foreground, displayColor: foreground),
    );
  }

  ThemeData _withUrduMetrics(ThemeData theme, bool isUrdu) {
    if (!isUrdu) return theme;
    final t = theme.textTheme;
    TextStyle? tune(TextStyle? style, {double? size, FontWeight? weight}) => style?.copyWith(
          fontSize: size ?? style.fontSize,
          fontWeight: weight ?? style.fontWeight,
          height: 1.65,
        );
    return theme.copyWith(
      textTheme: t.copyWith(
        displayLarge: tune(t.displayLarge),
        displayMedium: tune(t.displayMedium),
        displaySmall: tune(t.displaySmall),
        headlineLarge: tune(t.headlineLarge),
        headlineMedium: tune(t.headlineMedium),
        headlineSmall: tune(t.headlineSmall),
        titleLarge: tune(t.titleLarge),
        titleMedium: tune(t.titleMedium),
        titleSmall: tune(t.titleSmall),
        bodyLarge: tune(t.bodyLarge),
        bodyMedium: tune(t.bodyMedium),
        bodySmall: tune(t.bodySmall),
        labelLarge: tune(t.labelLarge),
        labelMedium: tune(t.labelMedium),
        labelSmall: tune(t.labelSmall),
      ),
    );
  }

  Widget _applyAccessibilityScale(BuildContext context, Widget? child, SettingsProvider settings) {
    if (child == null) return const SizedBox.shrink();
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    final scale = baseScale * (settings.isLargeText ? 1.2 : 1.0);
    final brightness = Theme.of(context).brightness;
    final isUrdu = settings.appLanguage == 'ur';
    final currentTheme = _withUrduMetrics(Theme.of(context), isUrdu);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: Theme(
        data: currentTheme,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: ValueKey(_authProvider.userId),
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ProfessionalProvider()),
        ChangeNotifierProvider(create: (_) => EnvironmentalProvider()),
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()..initialize()),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, _) {
          if (settings.appLanguage != _lastLanguage) {
            _lastLanguage = settings.appLanguage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.read<QuickReplyProvider>().switchLanguage(settings.appLanguage);
            });
          }

          if (!auth.isAuthenticated) {
            _lastSyncedSettingsUserId = null;
          } else if (auth.userId != _lastSyncedSettingsUserId) {
            _lastSyncedSettingsUserId = auth.userId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(context.read<SettingsProvider>().syncFromCloud());
            });
          }

          context.read<EnvironmentalProvider>().setSettingsProvider(settings);

          final appLocale = Locale(settings.appLanguage);
          const delegates = [AppStrings.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate];
          const locales = [Locale('en'), Locale('ur')];
          final isUrdu = settings.appLanguage == 'ur';
          final urduFont = isUrdu ? 'NotoNastaliqUrdu' : 'NotoSans';
          final direction = isUrdu ? TextDirection.rtl : TextDirection.ltr;
          final highContrast = settings.isHighContrast;
          final lightBase = highContrast ? _highContrastTheme(fontFamily: urduFont, dark: false) : AppTheme.lightTheme(fontFamily: urduFont);
          final darkBase = highContrast ? _highContrastTheme(fontFamily: urduFont, dark: true) : AppTheme.darkTheme(fontFamily: urduFont);
          final lightTheme = _withUrduMetrics(lightBase, isUrdu);
          final darkTheme = _withUrduMetrics(darkBase, isUrdu);
          final themeMode = settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;

          if (_showSplash) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
              locale: appLocale,
              supportedLocales: locales,
              localizationsDelegates: delegates,
              builder: (context, child) => _applyAccessibilityScale(context, child, settings),
              home: SplashScreen(onComplete: () => setState(() => _showSplash = false)),
            );
          }

          return Directionality(
            textDirection: direction,
            child: MaterialApp(
              title: 'HumSukhan',
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
              home: const _AccountGate(),
              onGenerateRoute: AppRouter.generateRoute,
              locale: appLocale,
              supportedLocales: locales,
              localizationsDelegates: delegates,
              builder: (context, child) => _applyAccessibilityScale(context, child, settings),
            ),
          );
        },
      ),
    );
  }
}

class _AccountGate extends StatelessWidget {
  const _AccountGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    if (!settings.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.isAuthenticated) return const AuthScreen();
    if (!settings.isOnboardingComplete) return const OnboardingScreen();
    return const MainScaffold();
  }
}
