import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';

/// A final Deepgram result whose words are spread over [words] seconds each.
String result(String transcript, double confidence) {
  final tokens = transcript.split(' ');
  return jsonEncode({
    'type': 'Results',
    'is_final': true,
    'speech_final': true,
    'channel': {
      'alternatives': [
        {
          'transcript': transcript,
          'confidence': confidence,
          'words': [
            for (var i = 0; i < tokens.length; i++)
              {'word': tokens[i], 'punctuated_word': tokens[i], 'start': i * 0.3, 'end': i * 0.3 + 0.25, 'confidence': confidence},
          ],
        },
      ],
    },
  });
}

Future<EverydayBilingualResult> hear({required String english, required double englishConfidence, required String urdu, required double urduConfidence}) async {
  final stt = EverydayBilingualSttService.instance..debugBegin('Auto');
  final next = stt.onResult.firstWhere((r) => r.isFinal);
  stt.debugReceive('English', result(english, englishConfidence));
  stt.debugReceive('Urdu', result(urdu, urduConfidence));
  return next.timeout(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Urdu speech is shown in Urdu even when the English recognizer is more confident', () async {
    // nova-3 English writes Urdu speech out phonetically, often confidently.
    final heard = await hear(
      english: 'aap kya karna chahte hain',
      englishConfidence: 0.86,
      urdu: 'آپ کیا کرنا چاہتے ہیں',
      urduConfidence: 0.74,
    );
    expect(heard.text, 'آپ کیا کرنا چاہتے ہیں');
    expect(heard.language, 'Urdu');
  });

  test('English speech stays English', () async {
    final heard = await hear(
      english: 'please send the report today',
      englishConfidence: 0.93,
      urdu: 'پلیز سینڈ دی رپورٹ',
      urduConfidence: 0.41,
    );
    expect(heard.text, 'please send the report today');
    expect(heard.language, 'English');
  });
}
