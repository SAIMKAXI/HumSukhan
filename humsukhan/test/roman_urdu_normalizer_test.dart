import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/conversation/services/roman_urdu_normalizer.dart';

void main() {
  test('keeps Latin Roman Urdu unchanged', () {
    expect(RomanUrduNormalizer.normalize('main ghar ja raha hoon'), 'main ghar ja raha hoon');
  });
  test('converts accidental Devanagari output in Roman Urdu mode', () {
    expect(RomanUrduNormalizer.normalize('मैं घर जा रहा हूँ'), isNot(contains(RegExp(r'[\u0900-\u097F]'))));
  });
}
