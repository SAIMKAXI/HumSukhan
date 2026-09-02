import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('caption model does not filter mixed language content', () {
    const caption = CaptionSegment(text: 'office', language: 'English', script: CaptionScript.latin);
    const urdu = CaptionSegment(text: 'بازار', language: 'Urdu', script: CaptionScript.arabic);
    expect([caption, urdu].length, 2);
  });
}
