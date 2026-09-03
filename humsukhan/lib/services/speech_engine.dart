import '../models/models.dart';

/// Common contract for live speech-recognition engines.
///
/// Concrete engines may use different transport/fallback strategies, but the
/// UI and orchestration layers only depend on this lifecycle surface.
abstract interface class SpeechEngine {
  Stream<SpeechResultEvent> get onResult;
  bool get isListening;
  String get currentLanguage;

  Future<void> startListening({String language = 'English'});
  Future<void> stopListening();
  Future<void> switchLanguage(String language);
}
