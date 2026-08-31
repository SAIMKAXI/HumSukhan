import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'screens/splash_screen.dart';
import 'l10n/app_strings.dart';
import 'services/supabase_service.dart';
import 'services/sound_detection_service.dart';

@pragma('vm:entry-point')
Future<void> environmentalMonitoringBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.humsukhan/environment_monitor');
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
  await channel.invokeMethod('pipelineState', {
    'state': started ? 'ACTIVE' : 'ERROR',
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  runApp(const HumSukhanApp());
}

class HumSukhanApp extends StatefulWidget {
  const HumSukhanApp({super.key});

  @override
  State<HumSukhanApp> createState() => _HumSukhanAppState();
}

class _HumSukhanAppState extends State<HumSukhanApp> {
  bool _showSplash = true;
  String _lastLanguage = 'en';
  bool _settingsWired = false;

  ThemeData _highContrastTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'NotoSans',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        primaryContainer: Colors.white,
        onPrimaryContainer: Colors.black,
        secondary: Colors.black,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        surfaceContainer: Colors.white,
        error: Color(0xFF8B0000),
        onError: Colors.white,
        outline: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colors.black, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.black),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2.5),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.black, width: 1.25),
        labelStyle: TextStyle(color: Colors.black),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.black),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black
              : Colors.white,
        ),
      ),
    );
  }

  Widget _applyAccessibilityScale(BuildContext context, Widget? child, SettingsProvider settings) {
    if (child == null) return const SizedBox.shrink();
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    final scale = baseScale * (settings.isLargeText ? 1.2 : 1.0);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ProfessionalProvider()),
        ChangeNotifierProvider(create: (_) => EnvironmentalProvider()),
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          if (settings.appLanguage != _lastLanguage) {
            _lastLanguage = settings.appLanguage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<QuickReplyProvider>().switchLanguage(settings.appLanguage);
              }
            });
          }

          if (!_settingsWired) {
            _settingsWired = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<EnvironmentalProvider>().setSettingsProvider(settings);
              }
            });
          }

          final appLocale = Locale(settings.appLanguage);
          const localizationDelegates = [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ];
          const supportedLocales = [Locale('en'), Locale('ur')];
          final isUrdu = settings.appLanguage == 'ur';
          final urduFont = isUrdu ? 'NotoNastaliqUrdu' : 'NotoSans';
          final textDirection = isUrdu ? TextDirection.rtl : TextDirection.ltr;
          final highContrast = settings.isHighContrast;
          final regularLightTheme = AppTheme.lightTheme(fontFamily: urduFont);
          final regularDarkTheme = AppTheme.darkTheme(fontFamily: urduFont);
          final highContrastTheme = _highContrastTheme().copyWith(
            textTheme: _highContrastTheme().textTheme.apply(fontFamily: urduFont),
          );

          if (_showSplash) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: highContrast ? highContrastTheme : regularLightTheme,
              darkTheme: highContrast ? highContrastTheme : regularDarkTheme,
              themeMode: highContrast ? ThemeMode.light : settings.themeMode,
              locale: appLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: localizationDelegates,
              builder: (context, child) => _applyAccessibilityScale(context, child, settings),
              home: SplashScreen(
                onComplete: () => setState(() => _showSplash = false),
              ),
            );
          }

          return Directionality(
            textDirection: textDirection,
            child: MaterialApp(
              title: 'HumSukhan',
              debugShowCheckedModeBanner: false,
              theme: highContrast ? highContrastTheme : regularLightTheme,
              darkTheme: highContrast ? highContrastTheme : regularDarkTheme,
              themeMode: highContrast ? ThemeMode.light : settings.themeMode,
              initialRoute: settings.isOnboardingComplete ? AppRouter.home : AppRouter.onboarding,
              onGenerateRoute: AppRouter.generateRoute,
              locale: appLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: localizationDelegates,
              builder: (context, child) => _applyAccessibilityScale(context, child, settings),
            ),
          );
        },
      ),
    );
  }
}
