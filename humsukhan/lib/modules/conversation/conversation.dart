/// Public entry point for Conversational Mode.
///
/// Implementation is intentionally re-exported from the legacy location during
/// the migration so we can refactor internals without changing behavior.
export '../../screens/everyday_screen.dart';
export '../../providers/conversation_provider.dart';
export '../../providers/speech_provider.dart';
export '../../services/deepgram_transcription_service.dart';
export '../../services/cloud_tts_service.dart';
export '../../widgets/speakable_caption_bubble.dart';
