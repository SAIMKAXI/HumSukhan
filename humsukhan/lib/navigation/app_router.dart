import 'package:flutter/material.dart';
import '../screens/screens.dart';
import '../widgets/main_scaffold.dart';
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

  static bool _requiresAuthentication(String? name) => name != null && name != onboarding && name != auth;

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final authenticated = AuthService.instance.isAuthenticated;
    if (_requiresAuthentication(routeSettings.name) && !authenticated) {
      return MaterialPageRoute(builder: (_) => const AuthScreen());
    }

    switch (routeSettings.name) {
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
