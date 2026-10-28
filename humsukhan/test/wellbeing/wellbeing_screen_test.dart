import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/modules/wellbeing/data/support_library.dart';
import 'package:humsukhan/modules/wellbeing/models/mood_entry.dart';
import 'package:humsukhan/modules/wellbeing/services/mood_store.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/providers/wellbeing_provider.dart';
import 'package:humsukhan/screens/wellbeing_help_screen.dart';
import 'package:humsukhan/screens/wellbeing_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wellbeing_provider_test.dart' show FakeReminders;

/// Keeps check-ins in memory, so widget tests need no file system.
class MemoryStore extends MoodStore {
  MemoryStore() : super(account: 'test');
  List<MoodEntry> saved = [];
  bool failSaves = false;

  @override
  Future<MoodLoad> load() async => MoodLoad([...saved]);

  @override
  Future<void> save(List<MoodEntry> entries, {DateTime? now}) async {
    if (failSaves) throw StateError('disk full');
    saved = [...entries];
  }

  @override
  Future<void> deleteAll() async => saved = [];
}

class FakeSpeech extends SpeechProvider {
  final List<(String, String)> spoken = [];

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}

  @override
  Future<void> speak(String text, {String language = 'English'}) async => spoken.add((text, language));

  @override
  Future<void> stopSpeaking() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late MemoryStore store;
  late FakeReminders reminders;
  late WellbeingProvider wellbeing;
  late FakeSpeech speech;

  /// The speech provider's audio player has no platform side in tests.
  void ignoreAudioPlugin() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException && '${details.exception}'.contains('audioplayers')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpScreen(WidgetTester tester, {String language = 'en', bool openCheckIn = false, bool animations = false}) async {
    ignoreAudioPlugin();
    SharedPreferences.setMockInitialValues({});
    store = MemoryStore();
    reminders = FakeReminders();
    speech = FakeSpeech();
    wellbeing = WellbeingProvider(account: 'test', store: store, reminders: reminders, autoLoad: false);
    await tester.runAsync(wellbeing.load);
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WellbeingProvider>.value(value: wellbeing),
        ChangeNotifierProvider<SpeechProvider>.value(value: speech),
      ],
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !animations),
          child: child!,
        ),
        home: WellbeingScreen(openCheckIn: openCheckIn),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
  }

  Future<void> checkIn(WidgetTester tester, String mood, {String? tag, String? note}) async {
    await tap(tester, find.text(mood).first);
    if (tag != null) await tap(tester, find.widgetWithText(FilterChip, tag));
    if (note != null) await tester.enterText(find.byType(TextField), note);
    await tap(tester, find.text('Save check-in'));
  }

  testWidgets('the first visit explains the feature; "Not now" leaves reminders off', (tester) async {
    await pumpScreen(tester);
    expect(find.text('A private check-in, just for you'), findsOneWidget);
    await tap(tester, find.text('Not now'));
    expect(find.text('A private check-in, just for you'), findsNothing);
    expect(wellbeing.introSeen, isTrue);
    expect(wellbeing.remindersOn, isFalse);
  });

  testWidgets('"Remind me every evening" turns on an 8 pm reminder', (tester) async {
    await pumpScreen(tester);
    await tap(tester, find.text('Remind me every evening'));
    expect(wellbeing.remindersOn, isTrue);
    expect(reminders.scheduled, isNotEmpty);
    expect(reminders.scheduled.every((slot) => slot.hour == 20 && slot.minute == 0), isTrue);
  });

  testWidgets('refused notification permission is explained and the switch stays off', (tester) async {
    await pumpScreen(tester);
    reminders.permission = false;
    await tap(tester, find.text('Daily reminder'));
    expect(wellbeing.remindersOn, isFalse);
    expect(find.textContaining('Notifications are off for HumSukhan'), findsWidgets);
  });

  testWidgets('a good check-in with a word is saved and shown in the history', (tester) async {
    await pumpScreen(tester);
    await checkIn(tester, 'Good', tag: 'Grateful');
    expect(store.saved, hasLength(1));
    expect(store.saved.single.mood, Mood.good);
    expect(store.saved.single.tags, {MoodTag.grateful});
    expect(find.text('Check-in saved'), findsOneWidget);
    expect(find.text('You have been feeling good. Keep noticing what helps.'), findsOneWidget);
    expect(find.textContaining('Good ·'), findsOneWidget);
  });

  testWidgets('a low check-in opens ideas that may help', (tester) async {
    await pumpScreen(tester);
    await checkIn(tester, 'Low', tag: 'Tired');
    expect(find.byType(SupportScreen), findsOneWidget);
    expect(find.text(SupportLibrary.breathing.title.en), findsOneWidget);
    expect(find.text(SupportLibrary.communicationBreak.title.en), findsOneWidget);
  });

  testWidgets('the lowest mood goes straight to the fixed help screen', (tester) async {
    await pumpScreen(tester);
    await checkIn(tester, 'Very low');
    expect(find.byType(HelpNowScreen), findsOneWidget);
    expect(find.text(SupportLibrary.helpNowTitle.en), findsWidgets);

    await tap(tester, find.text('Show this to someone near you'));
    expect(find.text(SupportLibrary.showSomeone.en), findsOneWidget);
    expect(find.text(SupportLibrary.showSomeone.ur), findsOneWidget);
    await tap(tester, find.text('Done'));
    await tap(tester, find.text('I am safe now'));
    expect(find.byType(WellbeingScreen), findsOneWidget);
  });

  testWidgets('words about self-harm in the note go to the help screen whatever the mood', (tester) async {
    await pumpScreen(tester);
    await checkIn(tester, 'Okay', note: 'I want to end my life');
    expect(find.byType(HelpNowScreen), findsOneWidget);
  });

  testWidgets('a failed save is reported and the check-in can be tried again', (tester) async {
    await pumpScreen(tester);
    store.failSaves = true;
    await checkIn(tester, 'Good');
    expect(find.text('Your check-in could not be saved. Please try again.'), findsOneWidget);
    expect(find.byType(CheckInSheet), findsOneWidget);
    store.failSaves = false;
    await tap(tester, find.text('Save check-in'));
    expect(store.saved, hasLength(1));
    expect(find.byType(CheckInSheet), findsNothing);
  });

  testWidgets('skipping closes the check-in without saving', (tester) async {
    await pumpScreen(tester, openCheckIn: true);
    expect(find.byType(CheckInSheet), findsOneWidget);
    await tap(tester, find.text('Skip for now'));
    expect(find.byType(CheckInSheet), findsNothing);
    expect(store.saved, isEmpty);
  });

  testWidgets('Get help always works, and urgent help is always one tap away', (tester) async {
    await pumpScreen(tester);
    await tap(tester, find.text('Get help'));
    expect(find.byType(SupportScreen), findsOneWidget);
    await tap(tester, find.text('Open urgent help'));
    expect(find.byType(HelpNowScreen), findsOneWidget);
  });

  testWidgets('ideas can be shown in both languages and read aloud', (tester) async {
    await pumpScreen(tester);
    await tap(tester, find.text('Get help'));
    await tap(tester, find.text('Show Urdu and English together'));
    expect(wellbeing.showBothLanguages, isTrue);
    expect(find.text(SupportLibrary.breathing.title.ur), findsOneWidget);

    await tap(tester, find.text('Listen').first);
    expect(speech.spoken.map((s) => s.$2), ['English', 'Urdu']);
    expect(speech.spoken.first.$1, contains(SupportLibrary.breathing.title.en));
  });

  testWidgets('deleting all check-ins asks first', (tester) async {
    await pumpScreen(tester);
    await checkIn(tester, 'Great');
    await tap(tester, find.text('Delete all my check-ins'));
    expect(find.text('All your check-ins and notes will be deleted from this phone. This cannot be undone.'), findsOneWidget);
    await tap(tester, find.text('Delete').last);
    expect(store.saved, isEmpty);
    expect(find.text('No check-ins yet.'), findsOneWidget);
  });

  testWidgets('the whole flow works in Urdu', (tester) async {
    await pumpScreen(tester, language: 'ur');
    expect(find.text('آپ کیسا محسوس کر رہے ہیں؟'), findsOneWidget);
    await tap(tester, find.text('اداس').first);
    await tap(tester, find.text('چیک اِن محفوظ کریں'));
    expect(store.saved.single.mood, Mood.low);
    expect(find.text(SupportLibrary.breathing.title.ur), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the breathing circle animates without errors', (tester) async {
    await pumpScreen(tester, animations: true);
    await tester.ensureVisible(find.text('Get help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get help'));
    // Build the new page, then let its transition finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Breathe in for the first 4 seconds of each 10-second cycle, then out.
    expect(find.byType(BreathingCircle), findsOneWidget);
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4000));
    expect(find.text('Breathe out'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
