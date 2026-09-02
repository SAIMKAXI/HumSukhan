import '../../models/models.dart';

/// Normalizes a transcript into contiguous script/language segments.
///
/// Script metadata never rewrites transcript text. In particular, Devanagari
/// is preserved and never silently transliterated into Urdu.
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

    final romanUrduFallback = fallbackLanguage.trim().toLowerCase() == 'roman urdu';
    final pieces = value.split(RegExp(r'(\s+)'));
    final segments = <CaptionSegment>[];
    CaptionScript currentScript = CaptionScript.other;
    String currentLanguage = fallbackLanguage;
    final buffer = StringBuffer();

    CaptionScript effectiveScript(CaptionScript script) =>
        romanUrduFallback && script == CaptionScript.latin
            ? CaptionScript.romanUrdu
            : script;

    void flush() {
      final text = buffer.toString().trim();
      if (text.isEmpty) {
        buffer.clear();
        return;
      }
      final segment = CaptionSegment(
        text: text,
        language: currentLanguage,
        script: currentScript,
      );
      if (segments.isNotEmpty &&
          segments.last.script == segment.script &&
          segments.last.language == segment.language) {
        final previous = segments.removeLast();
        segments.add(CaptionSegment(
          text: '${previous.text} $text',
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
      final script = effectiveScript(classifyScript(piece));
      if (currentScript != CaptionScript.other &&
          script != CaptionScript.other &&
          script != currentScript) {
        flush();
        currentScript = script;
        currentLanguage = _languageForScript(script, fallbackLanguage);
      } else if (currentScript == CaptionScript.other) {
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
      case CaptionScript.romanUrdu:
        return 'Roman Urdu';
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
