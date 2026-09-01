import 'package:flutter/material.dart';
import '../modules/auth/auth.dart';
import '../modules/onboarding/onboarding.dart';
import '../modules/home/home.dart';
import '../modules/conversation/conversation.dart';
import '../modules/professional/professional.dart';
import '../modules/environmental_alerts/environmental_alerts.dart';
import '../modules/settings/settings.dart';
import '../modules/splash/splash.dart';
import '../services/auth_service.dart';

class AppRouter {
  static const String onboarding = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String everyday = '/everyday';
  static const String professional = '/professional';
  static const String sessionDetail = '/session/detail';
  static const String sessionLive = '/session/live';
  static const String environmental = '/environmental';
  static const String settings = '/settings';
  static const String splash = '/splash';

  static bool _requiresAuthentication(String? name) => name != null && name != onboarding && name != auth && name != splash;

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final authenticated = AuthService.instance.isAuthenticated;
    if (_requiresAuthentication(routeSettings.name) && !authenticated) {
      return MaterialPageRoute(builder: (_) => const AuthScreen());
    }

    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        if (!authenticated) return MaterialPageRoute(builder: (_) => const AuthScreen());
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case auth:
        if (authenticated) return MaterialPageRoute(builder: (_) => const MainScaffold());
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MainScaffold());
      case everyday:
        return MaterialPageRoute(builder: (_) => const EverydayScreen());
      case professional:
        return MaterialPageRoute(builder: (_) => const ProfessionalScreen());
      case sessionDetail:
        final sessionId = routeSettings.arguments as String;
        return MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: sessionId));
      case sessionLive:
        final sessionId = routeSettings.arguments as String;
        return MaterialPageRoute(builder: (_) => SessionLiveScreen(sessionId: sessionId));
      case environmental:
        return MaterialPageRoute(builder: (_) => const EnvironmentalScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => authenticated ? const MainScaffold() : const AuthScreen());
    }
  }
}
