import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
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
    expect(replies.orderedReplies.first.text, 'Please write it down',
        reason: 'a reply just added must be among the first shown in a conversation');

    final row = find.ancestor(of: find.text('Please write it down'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.star_border)));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(replies.orderedReplies.first.text, 'Please write it down');

    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(replies.replies.map((r) => r.text), isNot(contains('Please write it down')));
    expect(replies.replies.length, initial);
  });

  group('quick reply order and language', () {
    Map<String, Object> stored(List<QuickReply> replies) => {
          'appLanguage': 'en',
          'quickReplies:guest': jsonEncode(replies.map((r) => r.toJson()).toList()),
        };

    test('favourites come first, then the user\'s own newest first, then built-ins', () async {
      SharedPreferences.setMockInitialValues(stored([
        QuickReply(text: 'Hello'),
        QuickReply(text: 'Older own', createdAt: DateTime(2026, 1, 1)),
        QuickReply(text: 'Yes', isFavorite: true),
        QuickReply(text: 'Newer own', createdAt: DateTime(2026, 2, 1)),
      ]));
      final replies = QuickReplyProvider();
      await pumpEventQueue();
      expect(replies.orderedReplies.map((r) => r.text), ['Yes', 'Newer own', 'Older own', 'Hello']);
    });

    test('switching language keeps the user\'s replies and which built-ins are starred', () async {
      SharedPreferences.setMockInitialValues(stored([
        for (final d in AppStrings.quickRepliesEn) QuickReply(text: d.$1, category: d.$2, isFavorite: d.$1 == 'Thank you'),
        QuickReply(text: 'My own', isFavorite: true),
      ]));
      final replies = QuickReplyProvider();
      await replies.switchLanguage('ur');
      final texts = replies.replies.map((r) => r.text).toList();
      expect(texts, contains('شکریہ'));
      expect(texts, isNot(contains('Thank you')));
      expect(replies.favoriteReplies.map((r) => r.text), unorderedEquals(['شکریہ', 'My own']));
    });

    test('a language switch that arrives before loading finishes does not wipe stored replies', () async {
      SharedPreferences.setMockInitialValues(stored([QuickReply(text: 'Keep me', isFavorite: true)]));
      final replies = QuickReplyProvider();
      // No await between construction and the switch, as at app start.
      await replies.switchLanguage('ur');
      expect(replies.orderedReplies.first.text, 'Keep me');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('quickReplies:guest'), contains('Keep me'));
    });
  });
}
