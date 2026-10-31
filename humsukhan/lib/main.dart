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
import 'modules/environmental_alerts/background/environmental_background_pipeline.dart';
import 'modules/environmental_alerts/services/environmental_monitor.dart';

/// Entry point of the Flutter engine Android's environmental monitoring
/// service starts; it runs with the app closed. Looked up by name from
/// `EnvironmentalMonitoringService`, so it must stay in this library.
@pragma('vm:entry-point')
Future<void> environmentalMonitoringBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runEnvironmentalBackgroundPipeline();
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

  Widget _applyAccessibilityScale(BuildContext context, Widget? child, SettingsProvider settings) {
    if (child == null) return const SizedBox.shrink();
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    final scale = baseScale * (settings.isLargeText ? 1.2 : 1.0);
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
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
        ChangeNotifierProvider(create: (_) => WellbeingProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()..initialize()),
      ],
      child: SpeechLifecycleGuard(
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
            final wellbeing = context.read<WellbeingProvider>();
            final urduReminders = settings.appLanguage == 'ur';
            WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(wellbeing.setUrdu(urduReminders)));

            final appLocale = Locale(settings.appLanguage);
            const delegates = [AppStrings.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate];
            const locales = [Locale('en'), Locale('ur')];
            final isUrdu = settings.appLanguage == 'ur';
            final direction = isUrdu ? TextDirection.rtl : TextDirection.ltr;
            final highContrast = settings.isHighContrast;
            final lightTheme = AppTheme.forApp(urdu: isUrdu, dark: false, highContrast: highContrast);
            final darkTheme = AppTheme.forApp(urdu: isUrdu, dark: true, highContrast: highContrast);
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
      ),
    );
  }
}

class SpeechLifecycleGuard extends StatefulWidget {
  const SpeechLifecycleGuard({required this.child, super.key});

  final Widget child;

  @override
  State<SpeechLifecycleGuard> createState() => _SpeechLifecycleGuardState();
}

class _SpeechLifecycleGuardState extends State<SpeechLifecycleGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final speech = context.read<SpeechProvider>();
      unawaited(_stopSpeechSession(speech));
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheckSpeechCapabilities());
      if (!context.read<SpeechProvider>().isListening) {
        unawaited(EnvironmentalMonitoring.resumeAfterForegroundSpeech());
      }
    }
  }

  Future<void> _stopSpeechSession(SpeechProvider speech) async {
    try {
      await Future.wait<void>([
        speech.stopListening(),
        speech.stopSpeaking(),
      ]);
    } catch (e) {
      debugPrint('Speech session cleanup on app lifecycle change failed: $e');
    }
  }

  Future<void> _recheckSpeechCapabilities() async {
    try {
      await context.read<SpeechProvider>().recheckSpeechCapabilities();
    } catch (e) {
      debugPrint('Speech capability recheck after resume failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AccountGate extends StatelessWidget {
  const _AccountGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    if (auth.isPasswordRecovery) return const AuthScreen(recoveryMode: true);
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
