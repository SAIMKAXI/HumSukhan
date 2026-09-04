// Regression coverage: when TTS fails end-to-end (native AND cloud both
// unavailable), SpeechProvider.speak() rethrows. Before this fix, the Speak
// button on a caption bubble awaited that future without a try/catch, so the
// failure was silently swallowed by the Flutter zone error handler and the
// user saw no feedback at all — violating "the app must never silently do
// nothing" / "TTS errors are surfaced meaningfully".
//
// This subclasses the real SpeechProvider and overrides only `speak()` so the
// test exercises the actual widget/provider wiring without touching native
// TTS/STT plugins.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/providers.dart';
import 'package:humsukhan/widgets/speakable_caption_bubble.dart';

class _AlwaysFailingSpeechProvider extends SpeechProvider {
  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    throw StateError('No verified device voice on this phone');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Speak failure surfaces a visible error instead of failing silently',
      (tester) async {
    final speech = _AlwaysFailingSpeechProvider();
    addTearDown(speech.dispose);
    final caption = Caption(text: 'Hello there', language: 'English');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<SpeechProvider>.value(
          value: speech,
          child: Scaffold(
            body: SpeakableCaptionBubble(caption: caption),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Speak this message'), findsOneWidget);
    await tester.tap(find.byTooltip('Speak this message'));
    // speak() throws asynchronously; pump to let the microtask/catch run and
    // the SnackBar animate in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Could not speak this message'),
      findsOneWidget,
      reason: 'A failed Speak action must show the user an explicit error, '
          'never fail silently.',
    );
  });
}
