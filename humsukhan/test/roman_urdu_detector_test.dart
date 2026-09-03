import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/roman_urdu_detector.dart';

void main() {
  group('RomanUrduDetector', () {
    test('recognizes natural Roman Urdu phrases', () {
      expect(RomanUrduDetector.isRomanUrdu('Aap kaise hain?'), isTrue);
      expect(RomanUrduDetector.isRomanUrdu('Mujhe kal office jana hai.'), isTrue);
      expect(RomanUrduDetector.isRomanUrdu('Tumhe yeh kaam karna chahiye.'), isTrue);
    });

    test('does not classify ordinary English from one overlapping word', () {
      expect(RomanUrduDetector.isRomanUrdu('How are you today?'), isFalse);
      expect(RomanUrduDetector.isRomanUrdu('This is a map of the city.'), isFalse);
      expect(RomanUrduDetector.isRomanUrdu('I have to go to the office.'), isFalse);
    });

    test('normalizes punctuation and case', () {
      expect(RomanUrduDetector.isRomanUrdu('AAP, KAISE hain!!!'), isTrue);
      expect(RomanUrduDetector.isRomanUrdu('Mujhe... BOHAT der hui.'), isTrue);
    });

    test('does not classify empty or numeric-only text', () {
      expect(RomanUrduDetector.isRomanUrdu(''), isFalse);
      expect(RomanUrduDetector.isRomanUrdu('12345'), isFalse);
    });
  });
}
