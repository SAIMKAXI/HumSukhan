import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/screens/screens.dart';
import 'package:humsukhan/widgets/quick_reply_manager.dart';

import 'urdu_harness.dart';

/// Every dialog and sheet, opened in Urdu on a small phone, shows no English
/// and nothing in it overflows, at the normal text size and at large text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  silencePlugins();
  setUpAll(loadAppFonts);

  final s = AppStrings(const Locale('ur'));
  final session = ProfessionalSession(
    title: 'ریاضی کی کلاس',
    type: SessionType.class_,
    captionLanguage: 'Urdu',
    captions: [Caption(text: 'آج ہم الجبرا پڑھیں گے', language: 'Urdu')],
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Long lists build only what is on screen: scroll down to the item.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tap(tester, find.byType(PopupMenuButton<String>));
    await tap(tester, find.text(item));
  }

  final dialogs = <String, (Widget Function(), Future<void> Function(WidgetTester, AppProviders))>{
    'New session': (() => const ProfessionalScreen(), (t, _) => tap(t, find.byType(FloatingActionButton))),
    'New folder': (() => const ProfessionalScreen(), (t, _) => tap(t, find.text(s.createFolder))),
    'Folder sessions': (() => const ProfessionalScreen(), (t, _) => tap(t, find.text(s.generalFolder))),
    'Delete folder': (
      () => const ProfessionalScreen(),
      (t, app) async {
        await t.runAsync(() => app.professional.createFolder('نوٹس'));
        await t.pump();
        await menu(t, s.delete);
      },
    ),
    'App language': (() => const SettingsScreen(), (t, _) => tap(t, find.widgetWithText(ListTile, s.appLanguage))),
    'Keep sessions for': (() => const SettingsScreen(), (t, _) => tap(t, find.widgetWithText(ListTile, s.defaultRetentionPeriod))),
    'Reset settings': (() => const SettingsScreen(), (t, _) => tap(t, find.widgetWithText(ListTile, s.resetSettings))),
    'Export session': (() => SessionDetailScreen(sessionId: session.id), (t, _) => menu(t, s.exportAction)),
    'Move to folder': (() => SessionDetailScreen(sessionId: session.id), (t, _) => menu(t, s.moveToFolderAction)),
    'Delete session': (() => SessionDetailScreen(sessionId: session.id), (t, _) => menu(t, s.deleteAction)),
    'Check in': (() => const WellbeingScreen(), (t, _) => tap(t, find.text(s.moodOkay))),
    'Delete all check-ins': (
      () => const WellbeingScreen(),
      (t, app) async {
        await t.runAsync(() => app.wellbeing.addCheckIn(Mood.good));
        await t.pump();
        await tap(t, find.text(s.deleteAllCheckIns));
      },
    ),
    // Quick replies show only during a conversation; long-pressing one opens this.
    'Quick reply actions': (
      () => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showQuickReplyActions(context, QuickReply(text: 'ذرا آہستہ بولیں')),
                child: const Text('کھولیں'),
              ),
            ),
          ),
      (t, _) => tap(t, find.byType(TextButton)),
    ),
  };

  for (final textScale in [1.0, 1.3]) {
    for (final MapEntry(key: name, value: (screen, open)) in dialogs.entries) {
      testWidgets('$name is all Urdu and fits a small phone at text scale $textScale', (tester) async {
        final overflows = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          text.contains('overflowed') ? overflows.add(text.split('\n').first) : original?.call(details);
        };

        useScreen(tester, textScale: textScale);
        final app = AppProviders(sessions: [session]);
        await tester.runAsync(app.wellbeing.load);
        await tester.pumpWidget(app.wrap(screen()));
        await tester.runAsync(pumpEventQueue);
        await tester.pump(const Duration(milliseconds: 600));
        final routes = find.byType(ModalBarrier).evaluate().length;
        await open(tester, app);
        final opened = find.byType(ModalBarrier).evaluate().length > routes;
        final english = visibleEnglish(tester);

        await tester.pumpWidget(const SizedBox());
        // Restored before expect, which the test framework requires.
        FlutterError.onError = original;

        expect(opened, isTrue, reason: '$name did not open');
        expect(english, isEmpty, reason: '$name shows English:\n${english.join('\n')}');
        expect(overflows, isEmpty, reason: '$name at text scale $textScale:\n${overflows.join('\n')}');
      });
    }
  }
}
