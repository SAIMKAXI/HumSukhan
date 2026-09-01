import 'package:flutter_test/flutter_test.dart';

String deliveryLanguage(String language, String text) {
  final normalized = language.toLowerCase().trim();
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'urdu';
  const romanUrdu = {
    'aap', 'ap', 'aapko', 'aapki', 'aapke', 'aapka', 'kya', 'kyun', 'hai', 'hain',
    'ho', 'mein', 'main', 'mujhe', 'tum', 'se', 'ko', 'ka', 'ki', 'ke', 'yeh', 'woh',
    'ham', 'hum', 'mera', 'meri', 'mere', 'apna', 'nahi', 'nahin', 'acha', 'achha',
    'theek', 'karo', 'karna', 'jana', 'jao', 'chahiye', 'bhi', 'par',
  };
  final words = text.toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  if (words.any(romanUrdu.contains)) return 'urdu';
  if (normalized == 'urdu' || normalized == 'roman urdu') return 'urdu';
  return 'english';
}

void main() {
  test('Arabic-script text wins over English UI language', () {
    expect(deliveryLanguage('English', 'آپ کیسے ہیں؟'), 'urdu');
  });

  test('Roman Urdu is routed to Urdu speech', () {
    expect(deliveryLanguage('English', 'aap kaise hain'), 'urdu');
  });

  test('normal English stays English', () {
    expect(deliveryLanguage('English', 'How are you today?'), 'english');
  });

  test('explicit Urdu hint routes to Urdu', () {
    expect(deliveryLanguage('Urdu', 'How are you today?'), 'urdu');
  });
}
