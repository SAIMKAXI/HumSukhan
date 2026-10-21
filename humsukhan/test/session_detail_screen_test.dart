import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/professional_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/screens/session_detail_screen.dart';

class _FakeProfessionalProvider extends ProfessionalProvider {
  _FakeProfessionalProvider(
    this._session, {
    ProfessionalInsight? insight,
    String? error,
  })  : _insight = insight,
        _error = error;

  final ProfessionalSession _session;
  final ProfessionalInsight? _insight;
  final String? _error;
  int generateCalls = 0;

  @override
  List<ProfessionalSession> get sessions => [_session];

  @override
  ProfessionalInsight? getInsightForSession(String sessionId) =>
      sessionId == _session.id ? _insight : null;

  @override
  bool get isLoading => false;

  @override
  bool isGeneratingInsight(String sessionId) => false;

  @override
  String? insightError(String sessionId) => _error;

  @override
  Future<void> generateInsights(String sessionId) async {
    generateCalls++;
  }

  final List<(String, String?)> moves = [];

  @override
  List<Folder> get folders => [Folder(id: 'f1', name: 'Physics')];

  @override
  Future<void> moveSessionToFolder(String sessionId, String? folderId) async {
    moves.add((sessionId, folderId));
  }
}

Widget _app(_FakeProfessionalProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfessionalProvider>.value(value: provider),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [AppStrings.delegate],
      home: SessionDetailScreen(sessionId: 'session-1'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('session details keep summary out of overview and actions dedicated',
      (tester) async {
    final session = ProfessionalSession(
      id: 'session-1',
      title: 'Planning meeting',
      type: SessionType.meeting,
      captionLanguage: 'English',
      captions: const [],
    );
    final insight = ProfessionalInsight(
      sessionId: session.id,
      summary: 'Project direction and launch date were agreed.',
      summaryBullets: const [
        'The team agreed on the project direction.',
        'Launch preparation will start this week.',
      ],
      actionItems: const [
        'Prepare the launch checklist.',
        'The team discussed the launch timeline.',
        'The deadline is Friday.',
      ],
      deadlines: const ['Friday'],
      mentionedPeople: const ['Aisha'],
      isAvailable: true,
    );
    final provider = _FakeProfessionalProvider(session, insight: insight);

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    expect(find.text('Project direction and launch date were agreed.'), findsNothing);

    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(find.text('The team agreed on the project direction.'), findsOneWidget);
    expect(find.text('Prepare the launch checklist.'), findsNothing);

    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare the launch checklist.'), findsOneWidget);
    expect(find.text('The team discussed the launch timeline.'), findsNothing);
    expect(find.text('The deadline is Friday.'), findsNothing);
    expect(find.text('Friday'), findsNothing);
    expect(find.text('Aisha'), findsNothing);
  });

  testWidgets('action-only AI insight remains available when summary bullets are empty',
      (tester) async {
    final session = ProfessionalSession(
      id: 'session-1',
      title: 'Planning meeting',
      type: SessionType.meeting,
      captions: const [],
    );
    final insight = ProfessionalInsight(
      sessionId: session.id,
      actionItems: const ['Prepare the launch checklist.'],
      deadlines: const ['Friday'],
      isAvailable: true,
    );
    final provider = _FakeProfessionalProvider(session, insight: insight);

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings(const Locale('en')).summaryNotProvided),
      findsOneWidget,
    );
    expect(find.text('Friday'), findsOneWidget);

    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare the launch checklist.'), findsOneWidget);
  });

  testWidgets('AI summary error screen retries generation',
      (tester) async {
    final session = ProfessionalSession(
      id: 'session-1',
      title: 'Planning meeting',
      type: SessionType.meeting,
      captions: [
        Caption(
          id: 'caption-1',
          text: 'Aisha will send the launch checklist by Friday.',
          timestamp: DateTime(2026, 10, 20, 10),
        ),
      ],
    );
    final provider = _FakeProfessionalProvider(
      session,
      error: 'Simulated AI service failure.',
    );

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Simulated AI service failure.'), findsOneWidget);
    expect(find.text('Retry AI summary'), findsOneWidget);
    final callsBeforeRetry = provider.generateCalls;

    await tester.tap(find.text('Retry AI summary'));
    await tester.pumpAndSettle();

    expect(provider.generateCalls, callsBeforeRetry + 1);
  });

  testWidgets('a session can be moved to a folder from its menu', (tester) async {
    final provider = _FakeProfessionalProvider(ProfessionalSession(
      id: 'session-1',
      title: 'Thermodynamics',
      type: SessionType.lecture,
      captionLanguage: 'English',
      captions: const [],
    ));
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to folder'));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsOneWidget);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    expect(provider.moves, [('session-1', 'f1')]);
    expect(find.text('Moved to Physics'), findsOneWidget);
  });
}
