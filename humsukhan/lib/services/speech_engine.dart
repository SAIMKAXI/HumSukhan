import 'stt/enhanced_stt.dart';

/// Common contract for live speech-recognition engines.
///
/// Concrete engines may use different transport/fallback strategies, but the
/// UI and orchestration layers only depend on this lifecycle surface.
/// Delivered as an error on [SpeechEngine.onResult] when recognition stops by
/// itself mid-session and no fallback could take over, so the screen can say
/// so instead of showing a microphone that is no longer captioning anything.
class SpeechInterruption implements Exception {
  const SpeechInterruption(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class SpeechEngine {
  Stream<SpeechResultEvent> get onResult;
  bool get isListening;
  String get currentLanguage;

  Future<void> startListening({String language = 'English'});
  Future<void> stopListening();
  Future<void> switchLanguage(String language);
}
