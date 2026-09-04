import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/professional_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/screens/session_detail_screen.dart';

class _FakeProfessionalProvider extends ProfessionalProvider {
  _FakeProfessionalProvider(ProfessionalSession session, ProfessionalInsight insight)
      : _session = session,
        _insight = insight;

  final ProfessionalSession _session;
  final ProfessionalInsight _insight;

  @override
  List<ProfessionalSession> get sessions => [_session];

  @override
  ProfessionalInsight? getInsightForSession(String sessionId) =>
      sessionId == _session.id ? _insight : null;

  @override
  bool get isLoading => false;

  @override
  Future<void> generateInsights(String sessionId) async {}
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfessionalProvider>.value(
            value: _FakeProfessionalProvider(session, insight),
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [AppStrings.delegate],
          home: SessionDetailScreen(sessionId: 'session-1'),
        ),
      ),
    );

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
}
