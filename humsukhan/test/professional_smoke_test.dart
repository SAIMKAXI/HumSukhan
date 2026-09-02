import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('professional session supports Auto preference', () {
    final session = ProfessionalSession(title: 'Test', captionLanguage: 'Auto');
    expect(session.captionLanguage, 'Auto');
  });
}
