import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/wellbeing/data/support_library.dart';
import 'package:humsukhan/modules/wellbeing/models/mood_entry.dart';
import 'package:humsukhan/modules/wellbeing/services/crisis_words.dart';
import 'package:humsukhan/modules/wellbeing/services/mood_patterns.dart';
import 'package:humsukhan/modules/wellbeing/services/mood_store.dart';

final _now = DateTime(2026, 10, 28, 20);
var _ids = 0;

MoodEntry _at(Duration ago, Mood mood, {String note = '', Set<MoodTag> tags = const {}}) =>
    MoodEntry(id: 'e${_ids++}', at: _now.subtract(ago), mood: mood, note: note, tags: tags);

MoodState _state(List<MoodEntry> entries) => MoodPatterns.analyse(entries, now: _now).state;

void main() {
  group('Mood pattern rules', () {
    test('no check-ins, or only old ones, says nothing', () {
      expect(_state([]), MoodState.noData);
      expect(_state([_at(const Duration(days: 3), Mood.veryLow)]), MoodState.noData);
    });

    test('the lowest mood is urgent on its own', () {
      expect(_state([_at(const Duration(hours: 1), Mood.veryLow)]), MoodState.urgent);
    });

    test('words about self-harm are urgent whatever mood was picked', () {
      expect(_state([_at(const Duration(hours: 1), Mood.okay, note: 'I just want to die')]), MoodState.urgent);
    });

    test('one low check-in is a low day', () {
      expect(_state([_at(const Duration(hours: 2), Mood.low)]), MoodState.lowDay);
    });

    test('three low check-ins in a row within a week are several low days', () {
      expect(
        _state([
          _at(const Duration(days: 2), Mood.low),
          _at(const Duration(days: 1), Mood.low),
          _at(const Duration(hours: 1), Mood.low),
        ]),
        MoodState.severalLowDays,
      );
    });

    test('three low check-ins spread over more than a week are not a run', () {
      expect(
        _state([
          _at(const Duration(days: 20), Mood.low),
          _at(const Duration(days: 10), Mood.low),
          _at(const Duration(hours: 1), Mood.low),
        ]),
        MoodState.lowDay,
      );
    });

    test('a clear drop below the usual level is several low days', () {
      final usual = [for (var d = 4; d <= 12; d++) _at(Duration(days: d), Mood.great)];
      final recent = [_at(const Duration(days: 2), Mood.okay), _at(const Duration(hours: 3), Mood.okay)];
      final pattern = MoodPatterns.analyse([...usual, ...recent], now: _now);
      expect(pattern.usualAverage, 5);
      expect(pattern.recentAverage, 3);
      expect(pattern.state, MoodState.severalLowDays);
    });

    test('going from great to good is not called hard days', () {
      final usual = [for (var d = 4; d <= 12; d++) _at(Duration(days: d), Mood.great)];
      final recent = [_at(const Duration(days: 2), Mood.good), _at(const Duration(hours: 3), Mood.good)];
      expect(_state([...usual, ...recent]), MoodState.doingWell);
    });

    test('the drop rule waits for enough check-ins to know the usual level', () {
      final usual = [for (var d = 4; d <= 6; d++) _at(Duration(days: d), Mood.great)];
      final recent = [_at(const Duration(days: 2), Mood.okay), _at(const Duration(hours: 3), Mood.okay)];
      final pattern = MoodPatterns.analyse([...usual, ...recent], now: _now);
      expect(pattern.usualAverage, isNull);
      expect(pattern.state, MoodState.steady);
    });

    test('good and great are doing well; okay is steady', () {
      expect(_state([_at(const Duration(hours: 1), Mood.good)]), MoodState.doingWell);
      expect(_state([_at(const Duration(hours: 1), Mood.okay)]), MoodState.steady);
    });

    test('the latest check-in decides, not the order they were given in', () {
      final entries = [_at(const Duration(hours: 1), Mood.great), _at(const Duration(hours: 5), Mood.veryLow)];
      expect(_state(entries), MoodState.doingWell);
    });

    test('streak counts consecutive days up to today or yesterday', () {
      final entries = [
        _at(const Duration(days: 1), Mood.okay),
        _at(const Duration(days: 2), Mood.okay),
        _at(const Duration(days: 4), Mood.okay),
      ];
      expect(MoodPatterns.analyse(entries, now: _now).streakDays, 2);
      expect(MoodPatterns.analyse([...entries, _at(const Duration(hours: 1), Mood.okay)], now: _now).streakDays, 3);
    });

    test('daily averages cover each day, with gaps left empty', () {
      final days = MoodPatterns.daily([
        _at(const Duration(hours: 1), Mood.great),
        _at(const Duration(hours: 2), Mood.okay),
        _at(const Duration(days: 2), Mood.low),
      ], now: _now, days: 7);
      expect(days, hasLength(7));
      expect(days.last.average, 4);
      expect(days.last.count, 2);
      expect(days[days.length - 2].average, isNull);
      expect(days[days.length - 3].average, 2);
    });
  });

  group('Words about self-harm', () {
    test('are noticed in English, Urdu and Roman Urdu', () {
      for (final note in [
        'I feel suicidal tonight',
        "I can't go on like this",
        'Sometimes I want to hurt myself.',
        'میں خودکشی کے بارے میں سوچ رہا ہوں',
        'میں مرنا چاہتی ہوں',
        'دل کرتا ہے میں جینا نہیں چاہتا',
        'kabhi kabhi khudkushi ka khayal aata hai',
        'main marna chahta hoon',
        'Mujhe jeena nahi chahti aisi zindagi',
      ]) {
        expect(CrisisWords.mentionsSelfHarm(note), isTrue, reason: note);
      }
    });

    test('Arabic letter variants and vowel marks do not hide them', () {
      expect(CrisisWords.mentionsSelfHarm('خودكشي'), isTrue);
      expect(CrisisWords.mentionsSelfHarm('مَرنا چاہتا'), isTrue);
    });

    test('everyday words are not mistaken for them', () {
      for (final note in [
        'I was dying to see my cousin',
        'The phone battery died',
        'Tired after a long day at work',
        'آج بہت تھکن ہے',
        'kal exam hai, thora stress hai',
        'Killing time before class',
        '',
      ]) {
        expect(CrisisWords.mentionsSelfHarm(note), isFalse, reason: note);
      }
    });
  });

  group('Support library', () {
    test('every item has English and Urdu text', () {
      for (final item in SupportLibrary.all) {
        expect(item.title.en.trim(), isNotEmpty, reason: item.id);
        expect(item.title.ur.trim(), isNotEmpty, reason: item.id);
        expect(item.body.en.trim(), isNotEmpty, reason: item.id);
        expect(item.body.ur.trim(), isNotEmpty, reason: item.id);
        expect(item.steps, isNotEmpty, reason: item.id);
        for (final step in item.steps) {
          expect(step.en.trim(), isNotEmpty, reason: item.id);
          expect(step.ur.trim(), isNotEmpty, reason: item.id);
        }
      }
      expect({for (final item in SupportLibrary.all) item.id}, hasLength(SupportLibrary.all.length));
    });

    test('every state but urgent has suggestions; urgent has only the fixed help screen', () {
      for (final state in MoodState.values) {
        final items = SupportLibrary.forState(state);
        if (state == MoodState.urgent) {
          expect(items, isEmpty);
        } else {
          expect(items, isNotEmpty, reason: state.name);
          expect(items.every(SupportLibrary.all.contains), isTrue, reason: state.name);
        }
      }
      expect(SupportLibrary.helpNowSteps, isNotEmpty);
      expect(SupportLibrary.showSomeone.en, contains('1122'));
      expect(SupportLibrary.showSomeone.ur, contains('1122'));
    });
  });

  group('Mood store', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('wellbeing_test'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    MoodStore store(String account) => MoodStore(account: account, baseDirectory: () async => dir);

    test('check-ins are saved and read back in order', () async {
      final entries = [
        _at(const Duration(hours: 1), Mood.good, tags: {MoodTag.tired, MoodTag.happy}, note: 'آج اچھا دن تھا'),
        _at(const Duration(days: 1), Mood.low),
      ];
      await store('user-1').save(entries, now: _now);
      final loaded = await store('user-1').load();
      expect(loaded.damaged, isFalse);
      expect(loaded.entries.map((e) => e.id), [entries[1].id, entries[0].id]);
      expect(loaded.entries.last.tags, {MoodTag.tired, MoodTag.happy});
      expect(loaded.entries.last.note, 'آج اچھا دن تھا');
      expect(loaded.entries.last.at, entries[0].at);
    });

    test('each account has its own check-ins', () async {
      await store('user-1').save([_at(const Duration(hours: 1), Mood.good)], now: _now);
      expect((await store('user-2').load()).entries, isEmpty);
      expect((await store('user-1').load()).entries, hasLength(1));
    });

    test('they are kept in the folder excluded from backups', () async {
      await store('user-1').save([_at(const Duration(hours: 1), Mood.good)], now: _now);
      expect(File('${dir.path}/${MoodStore.folder}/user-1.json').existsSync(), isTrue);
    });

    test('very old check-ins are dropped when saving', () async {
      await store('u').save([
        _at(const Duration(days: 500), Mood.good),
        _at(const Duration(days: 1), Mood.okay),
      ], now: _now);
      expect((await store('u').load()).entries, hasLength(1));
    });

    test('a damaged file is reported and set aside, not silently overwritten', () async {
      final folder = Directory('${dir.path}/${MoodStore.folder}')..createSync(recursive: true);
      File('${folder.path}/u.json').writeAsStringSync('{not json');
      final loaded = await store('u').load();
      expect(loaded.damaged, isTrue);
      expect(loaded.entries, isEmpty);
      expect(folder.listSync().map((f) => f.uri.pathSegments.last).any((n) => n.startsWith('u.json.damaged-')), isTrue);
    });

    test('one unreadable record does not hide the others', () async {
      final folder = Directory('${dir.path}/${MoodStore.folder}')..createSync(recursive: true);
      File('${folder.path}/u.json').writeAsStringSync(
        '{"version":1,"entries":[{"id":"a","at":"2026-10-28T10:00:00Z","score":4},{"id":"b","score":9}]}',
      );
      final loaded = await store('u').load();
      expect(loaded.damaged, isTrue);
      expect(loaded.entries.map((e) => e.id), ['a']);
    });

    test('delete removes everything, including set-aside copies', () async {
      final s = store('u');
      await s.save([_at(const Duration(hours: 1), Mood.good)], now: _now);
      File('${dir.path}/${MoodStore.folder}/u.json.damaged-1').writeAsStringSync('x');
      await store('other').save([_at(const Duration(hours: 1), Mood.good)], now: _now);
      await s.deleteAll();
      final names = Directory('${dir.path}/${MoodStore.folder}').listSync().map((f) => f.uri.pathSegments.last).toList();
      expect(names, ['other.json']);
    });

    test('writes in quick succession end with the last one', () async {
      final s = store('u');
      final first = [_at(const Duration(hours: 2), Mood.low)];
      final second = [...first, _at(const Duration(hours: 1), Mood.great)];
      await Future.wait([s.save(first, now: _now), s.save(second, now: _now)]);
      expect((await s.load()).entries, hasLength(2));
    });
  });
}
