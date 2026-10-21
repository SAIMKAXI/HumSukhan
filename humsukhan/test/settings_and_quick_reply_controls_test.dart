import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/providers/quick_reply_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/widgets/quick_reply_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'darkMode': true,
        'largeText': true,
        'hapticAlerts': false,
        'defaultRetentionDays': 1,
        'appLanguage': 'ur',
        'onboardingComplete:user-1': true,
      }));

  test('reset restores defaults but keeps the app language and onboarding', () async {
    final settings = SettingsProvider();
    await pumpEventQueue();
    expect(settings.isDarkMode, isTrue);

    await settings.resetToDefaults();

    expect(settings.isDarkMode, isFalse);
    expect(settings.isLargeText, isFalse);
    expect(settings.hapticAlerts, isTrue);
    expect(settings.defaultRetentionDays, 7);
    expect(settings.appLanguage, 'ur');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('darkMode'), isFalse, reason: 'reset must be stored, not only shown');
    expect(prefs.getBool('onboardingComplete:user-1'), isTrue);
  });

  Future<QuickReplyProvider> pumpManager(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'appLanguage': 'en'});
    final replies = QuickReplyProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: replies,
      child: const MaterialApp(
        localizationsDelegates: [AppStrings.delegate],
        home: Scaffold(body: QuickReplyManager()),
      ),
    ));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    return replies;
  }

  testWidgets('a quick reply can be added, favourited to the front, and deleted', (tester) async {
    final replies = await pumpManager(tester);
    final initial = replies.replies.length;

    await tester.enterText(find.byType(TextField), 'Please write it down');
    await tester.tap(find.text('Add'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(replies.replies.length, initial + 1);
    expect(replies.orderedReplies.last.text, 'Please write it down');

    await tester.scrollUntilVisible(find.text('Please write it down'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('Please write it down'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.star_border)));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(replies.orderedReplies.first.text, 'Please write it down');
    // Favouriting moved it to the top of the list.
    await tester.scrollUntilVisible(find.text('Please write it down'), -200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(replies.replies.map((r) => r.text), isNot(contains('Please write it down')));
    expect(replies.replies.length, initial);
  });
}
