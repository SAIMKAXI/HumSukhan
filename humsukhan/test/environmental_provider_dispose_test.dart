import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/environmental_provider.dart';

void main() {
  test('environmental provider can be disposed without notification failures', () {
    final provider = EnvironmentalProvider();
    provider.dispose();
    provider.notifyListeners();
  });
}
