import '../models/models.dart';

/// Normalizes a transcript into contiguous script/language segments.
///
/// This deliberately does not translate or transliterate Devanagari. A script
/// signal is metadata; the user's selected language policy remains authoritative.
class MixedTranscriptParser {
  static final _arabic = RegExp(r'[\u0600-\u06FF]');
  static final _devanagari = RegExp(r'[\u0900-\u097F]');
  static final _latin = RegExp(r'[A-Za-z]');

  static List<CaptionSegment> parse(
    String rawText, {
    String fallbackLanguage = 'English',
  }) {
    final value = rawText.trim();
    if (value.isEmpty) return const [];

    final pieces = value.split(RegExp(r'(\s+)'));
    final segments = <CaptionSegment>[];
    var currentScript = CaptionScript.other;
    var currentLanguage = fallbackLanguage;
    final buffer = StringBuffer();

    void flush() {
      final text = buffer.toString();
      if (text.trim().isEmpty) {
        buffer.clear();
        return;
      }
      final normalized = text.trim();
      final segment = CaptionSegment(
        text: normalized,
        language: currentLanguage,
        script: currentScript,
      );
      if (segments.isNotEmpty &&
          segments.last.script == segment.script &&
          segments.last.language == segment.language) {
        final previous = segments.removeLast();
        segments.add(CaptionSegment(
          text: '${previous.text} $normalized',
          language: segment.language,
          script: segment.script,
        ));
      } else {
        segments.add(segment);
      }
      buffer.clear();
    }

    for (final piece in pieces) {
      if (piece.trim().isEmpty) continue;
      final script = classifyScript(piece);
      if (currentScript != CaptionScript.other &&
          script != CaptionScript.other &&
          script != currentScript) {
        flush();
      }
      if (currentScript == CaptionScript.other) {
        currentScript = script;
        currentLanguage = _languageForScript(script, fallbackLanguage);
      }
      if (script != CaptionScript.other && script != currentScript) {
        flush();
        currentScript = script;
        currentLanguage = _languageForScript(script, fallbackLanguage);
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(piece);
    }
    flush();
    return List.unmodifiable(segments);
  }

  static CaptionScript classifyScript(String text) {
    if (_arabic.hasMatch(text)) return CaptionScript.arabic;
    if (_devanagari.hasMatch(text)) return CaptionScript.devanagari;
    if (_latin.hasMatch(text)) return CaptionScript.latin;
    return CaptionScript.other;
  }

  static String _languageForScript(CaptionScript script, String fallback) {
    switch (script) {
      case CaptionScript.arabic:
        return 'Urdu';
      case CaptionScript.latin:
        return fallback.toLowerCase() == 'urdu' ? 'English' : fallback;
      case CaptionScript.devanagari:
      case CaptionScript.other:
        return fallback;
    }
  }

  static String withDirectionMarks(List<CaptionSegment> segments) {
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (buffer.isNotEmpty) buffer.write(' ');
      if (segment.isRtl) {
        buffer.write('\u200F');
        buffer.write(segment.text);
        buffer.write('\u200F');
      } else {
        buffer.write('\u200E');
        buffer.write(segment.text);
        buffer.write('\u200E');
      }
    }
    return buffer.toString();
  }
}
