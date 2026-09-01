import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';

void main() {
  test('Home copy is localized for English and Urdu', () {
    final english = AppStrings(const Locale('en'));
    final urdu = AppStrings(const Locale('ur'));

    expect(english.everydayMode, 'Everyday Mode');
    expect(english.professionalMode, 'Professional Mode');
    expect(english.environmentalAlerts, 'Environmental Alerts');
    expect(english.monitoringActive, 'Monitoring active');
    expect(urdu.everydayMode, isNot(english.everydayMode));
    expect(urdu.professionalMode, isNot(english.professionalMode));
    expect(urdu.environmentalAlerts, isNot(english.environmentalAlerts));
    expect(urdu.monitoringActive, isNot(english.monitoringActive));
  });

  test('Home greeting stays localized', () {
    final english = AppStrings(const Locale('en'));
    final urdu = AppStrings(const Locale('ur'));

    expect(english.goodMorning, 'morning');
    expect(urdu.goodMorning, isNot(english.goodMorning));
    expect(urdu.noRecentSessions, isNot(english.noRecentSessions));
  });
}
