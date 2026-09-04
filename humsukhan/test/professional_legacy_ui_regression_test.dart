import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/professional_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/screens/session_detail_screen.dart';

class _LegacyProfessionalProvider extends ProfessionalProvider {
  _LegacyProfessionalProvider(this.session, this.insight);

  final ProfessionalSession session;
  final ProfessionalInsight insight;

  @override
  List<ProfessionalSession> get sessions => [session];

  @override
  ProfessionalInsight? getInsightForSession(String sessionId) =>
      sessionId == session.id ? insight : null;

  @override
  bool get isLoading => false;

  @override
  Future<void> generateInsights(String sessionId) async {}
}

void main() {
  testWidgets('legacy summary never renders as a structured AI summary bullet',
      (tester) async {
    final session = ProfessionalSession(
      id: 'legacy-session',
      title: 'Legacy planning meeting',
      type: SessionType.meeting,
      captions: const [],
    );
    final insight = ProfessionalInsight(
      sessionId: session.id,
      summary: 'This is legacy free-form summary text.',
      summaryBullets: const [],
      isAvailable: true,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfessionalProvider>.value(
            value: _LegacyProfessionalProvider(session, insight),
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [AppStrings.delegate],
          home: SessionDetailScreen(sessionId: 'legacy-session'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(find.text('This is legacy free-form summary text.'), findsNothing);
    expect(find.textContaining('Insights unavailable'), findsWidgets);
  });
}
