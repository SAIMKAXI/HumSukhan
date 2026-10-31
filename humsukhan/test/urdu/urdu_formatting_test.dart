import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';

/// Times read naturally in each language, with no Latin AM or PM in Urdu.
void main() {
  test('Urdu clock times name the part of the day', () {
    final s = AppStrings(const Locale('ur'));
    expect(s.clockTime(0, 30), 'رات 12:30');
    expect(s.clockTime(7, 5), 'صبح 7:05');
    expect(s.clockTime(12, 0), 'دوپہر 12:00');
    expect(s.clockTime(18, 42), 'شام 6:42');
    expect(s.clockTime(21, 15), 'رات 9:15');
  });

  test('English clock times use AM and PM', () {
    final s = AppStrings(const Locale('en'));
    expect(s.clockTime(0, 30), '12:30 AM');
    expect(s.clockTime(18, 42), '6:42 PM');
  });
}
