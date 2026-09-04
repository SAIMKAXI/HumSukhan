// Regression coverage for SpeechCapability's resume-time recheck logic.
//
// Root cause under test: `recheckIfMissing()` used to only re-probe the
// platform recognizer's installed locales when the *overall* `stt_available`
// flag was a cached negative. A device whose recognizer exists (available =
// true) but was missing a specific language pack (e.g. Urdu) at first probe
// would have that language permanently cached as unavailable, even after the
// user installed the missing language pack and resumed the app. See
// lib/services/speech_capability.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'package:humsukhan/services/speech_capability.dart';

/// A fake platform implementation that reports only English initially, then
/// "installs" Urdu to simulate the user adding a language pack between app
/// resumes.
class _FakeSpeechToTextPlatform extends SpeechToTextPlatform
    with MockPlatformInterfaceMixin {
  List<String> localeStrings = ['en-US:English (US)'];

  @override
  Future<bool> initialize({
    debugLogging = false,
    String? debugLogFilePath,
    List<SpeechConfigOption>? options,
  }) async =>
      true;

  @override
  Future<List<dynamic>> locales() async => localeStrings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSpeechToTextPlatform fakePlatform;
  late SpeechToText platformStt;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakePlatform = _FakeSpeechToTextPlatform();
    SpeechToTextPlatform.instance = fakePlatform;
    platformStt = SpeechToText.withMethodChannel();
  });

  test('probeStt caches per-language availability from installed locales', () async {
    final capability = SpeechCapability.instance;
    final available = await capability.probeStt(platformStt);

    expect(available, isTrue);
    expect(capability.sttSupportsEnglishCached, isTrue);
    expect(capability.sttSupportsUrduCached, isFalse);
  });

  test(
      'recheckIfMissing rediscovers a newly installed language even though '
      'the recognizer itself was already available', () async {
    final capability = SpeechCapability.instance;

    // First probe: only English is installed. Recognizer overall is
    // available, but Urdu is a cached negative.
    await capability.probeStt(platformStt);
    expect(capability.sttSupportsEnglishCached, isTrue);
    expect(capability.sttSupportsUrduCached, isFalse);

    // The user installs the Urdu language pack for the device recognizer.
    fakePlatform.localeStrings = ['en-US:English (US)', 'ur-PK:Urdu (Pakistan)'];

    // App resumes and asks the capability registry to recheck anything
    // still missing.
    await capability.recheckIfMissing(platformStt: platformStt);

    expect(
      capability.sttSupportsUrduCached,
      isTrue,
      reason: 'A newly installed language pack must be rediscovered on '
          'resume even when the recognizer overall was already usable.',
    );
  });

  test('recheckIfMissing is a no-op once every tracked capability is positive', () async {
    final capability = SpeechCapability.instance;
    fakePlatform.localeStrings = ['en-US:English (US)', 'ur-PK:Urdu (Pakistan)'];
    await capability.probeStt(platformStt);

    // Flip the fake platform to report nothing installed. If recheckIfMissing
    // still re-probed after everything was already positive, this would
    // incorrectly clear the cached capability.
    fakePlatform.localeStrings = [];
    await capability.recheckIfMissing(platformStt: platformStt);

    expect(capability.sttSupportsEnglishCached, isTrue);
    expect(capability.sttSupportsUrduCached, isTrue);
  });
}
