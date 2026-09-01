import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/auth/auth.dart' as auth;
import 'package:humsukhan/modules/branding/branding.dart' as branding;
import 'package:humsukhan/modules/conversation/conversation.dart' as conversation;
import 'package:humsukhan/modules/core/core.dart' as core;
import 'package:humsukhan/modules/environmental_alerts/environmental_alerts.dart' as environmental;
import 'package:humsukhan/modules/home/home.dart' as home;
import 'package:humsukhan/modules/onboarding/onboarding.dart' as onboarding;
import 'package:humsukhan/modules/professional/professional.dart' as professional;
import 'package:humsukhan/modules/settings/settings.dart' as settings;
import 'package:humsukhan/modules/splash/splash.dart' as splash;

void main() {
  test('feature modules expose their public APIs', () {
    expect(auth.AuthScreen, isNotNull);
    expect(branding.BrandLogo, isNotNull);
    expect(conversation.EverydayScreen, isNotNull);
    expect(core.AppRouter, isNotNull);
    expect(environmental.EnvironmentalScreen, isNotNull);
    expect(home.HomeScreen, isNotNull);
    expect(onboarding.OnboardingScreen, isNotNull);
    expect(professional.ProfessionalScreen, isNotNull);
    expect(settings.SettingsScreen, isNotNull);
    expect(splash.SplashScreen, isNotNull);
  });
}
