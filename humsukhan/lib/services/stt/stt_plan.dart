/// Where captions can come from.
enum SpeechSource {
  /// The phone's own recognizer.
  device,

  /// Live Deepgram streaming, English and Urdu side by side in Auto.
  cloudStream,

  /// Each utterance sent to the transcription edge functions.
  cloudChunk,

  /// A downloaded on-device model.
  offline,
}

/// One step of a plan: a source and the language to run it in.
typedef SpeechStep = ({SpeechSource source, String language});

/// The order in which to try recognizers for a caption [language]
/// ('English', 'Urdu' or 'Auto').
///
/// The phone's recognizer comes first when it has the language installed;
/// then the cloud, while there is a connection and a signed-in account; then a
/// downloaded offline model. A phone recognizer listens in one language, so
/// it cannot tell English from Urdu: in Auto the cloud, which can, goes
/// first, and the phone and offline model are the fallbacks.
List<SpeechStep> sttPlan({
  required String language,
  required bool online,
  required bool Function(String language) deviceHas,
  required bool Function(String language) offlineHas,
}) {
  const both = ['English', 'Urdu'];
  final cloud = [
    if (online) (source: SpeechSource.cloudStream, language: language),
    if (online) (source: SpeechSource.cloudChunk, language: language),
  ];
  if (language == 'Auto') {
    return [
      ...cloud,
      for (final l in both)
        if (deviceHas(l)) (source: SpeechSource.device, language: l),
      for (final l in both)
        if (offlineHas(l)) (source: SpeechSource.offline, language: l),
    ];
  }
  return [
    if (deviceHas(language)) (source: SpeechSource.device, language: language),
    ...cloud,
    if (offlineHas(language)) (source: SpeechSource.offline, language: language),
  ];
}
