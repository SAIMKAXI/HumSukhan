import 'package:flutter/material.dart';
import '../screens/screens.dart';
import '../widgets/main_scaffold.dart';

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
  static const String psl = '/psl';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case auth:
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
      case psl:
        return MaterialPageRoute(builder: (_) => const PslScreen());
      default:
        return MaterialPageRoute(builder: (_) => const MainScaffold());
    }
  }
}
