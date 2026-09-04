import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/tts_capability_service.dart';

void main() {
  test('Urdu capability probe checks Pakistan and India locales', () {
    expect(
      TtsCapabilityService.instance.candidatesFor('urdu'),
      ['ur-PK', 'ur-IN'],
    );
  });

  test('English capability probe checks common installed locales', () {
    expect(
      TtsCapabilityService.instance.candidatesFor('english'),
      ['en-US', 'en-GB', 'en-IN'],
    );
  });
}
