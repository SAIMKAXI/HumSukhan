import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/utils/urdu_text.dart';

void main() {
  test('detects Urdu/Arabic script', () {
    expect(containsUrduScript('آپ کیسے ہیں؟'), isTrue);
    expect(containsUrduScript('سلام'), isTrue);
  });

  test('does not classify Latin text as Urdu', () {
    expect(containsUrduScript('How are you?'), isFalse);
    expect(containsUrduScript('Roman Urdu'), isFalse);
  });
}
