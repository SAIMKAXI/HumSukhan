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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize Supabase
  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('Supabase init failed: $e');
    // App continues without cloud sync
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
          // Sync quick replies when language changes
          if (settings.appLanguage != _lastLanguage) {
            _lastLanguage = settings.appLanguage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<QuickReplyProvider>().switchLanguage(settings.appLanguage);
              }
            });
          }

          // Wire settings provider to environmental provider for alert feedback
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
          final urduFont = isUrdu ? 'NotoNastaliqUrdu' : null;
          final textDirection = isUrdu ? TextDirection.rtl : TextDirection.ltr;

          if (_showSplash) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(fontFamily: urduFont),
              locale: appLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: localizationDelegates,
              home: SplashScreen(
                onComplete: () {
                  setState(() => _showSplash = false);
                },
              ),
            );
          }

          return Directionality(
            textDirection: textDirection,
            child: MaterialApp(
              title: 'HumSukhan',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(fontFamily: urduFont),
              darkTheme: AppTheme.darkTheme(fontFamily: urduFont),
              themeMode: settings.themeMode,
              initialRoute: settings.isOnboardingComplete
                  ? AppRouter.home
                  : AppRouter.onboarding,
              onGenerateRoute: AppRouter.generateRoute,
              locale: appLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: localizationDelegates,
            ),
          );
        },
      ),
    );
  }
}
