import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const HumSukhanApp());
}

class HumSukhanApp extends StatefulWidget {
  const HumSukhanApp({super.key});

  @override
  State<HumSukhanApp> createState() => _HumSukhanAppState();
}

class _HumSukhanAppState extends State<HumSukhanApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ProfessionalProvider()),
        ChangeNotifierProvider(create: (_) => EnvironmentalProvider()),
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          if (_showSplash) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(),
              home: SplashScreen(
                onComplete: () {
                  setState(() => _showSplash = false);
                },
              ),
            );
          }

          return MaterialApp(
            title: 'HumSukhan',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: settings.themeMode,
            initialRoute: settings.isOnboardingComplete
                ? AppRouter.home
                : AppRouter.onboarding,
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}
