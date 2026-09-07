import 'everyday_speech_provider.dart';

export 'settings_provider.dart';
export 'user_provider.dart';
export 'conversation_provider.dart';
export 'professional_provider.dart';
export 'environmental_provider.dart';
export 'everyday_speech_provider.dart';
export 'speech_provider.dart';
export 'quick_reply_provider.dart';
export 'connectivity_provider.dart';
export 'auth_provider.dart';
export '../services/conversation_engine.dart';

// Compatibility alias for existing screens/tests. There is one canonical
// Everyday speech implementation; this does not recreate the removed legacy
// SpeechProvider implementation.
typedef SpeechProvider = EverydaySpeechProvider;
