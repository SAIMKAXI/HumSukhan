import '../models/models.dart';
import 'mixed_transcript_parser.dart';

/// Final-display policy for transcript text. Language choice is a hint; it
/// never removes a detected segment from the transcript.
enum TranscriptRepresentationMode { native, romanizeUrdu }

class PreparedTranscript {
  final String text;
  final List<CaptionSegment> segments;
  final String language;

  const PreparedTranscript({
    required this.text,
    required this.segments,
    required this.language,
  });
}

class TranscriptRepresentation {
  static PreparedTranscript prepare(
    String rawText, {
    required String selection,
    String detectedLanguage = 'English',
  }) {
    final normalizedSelection = selection.trim().toLowerCase();
    final fallback = detectedLanguage.trim().isEmpty ? 'English' : detectedLanguage;
    var value = rawText.trim();
    if (value.isEmpty) {
      return const PreparedTranscript(text: '', segments: [], language: 'English');
    }

    if (normalizedSelection == 'auto' && _containsDevanagari(value)) {
      value = devanagariToUrdu(value);
    }

    final romanize = normalizedSelection == 'english' || normalizedSelection == 'roman urdu';
    final parsed = MixedTranscriptParser.parse(value, fallbackLanguage: fallback);
    final output = <CaptionSegment>[];

    for (final segment in parsed) {
      if (romanize && segment.script == CaptionScript.arabic) {
        output.add(CaptionSegment(
          text: urduToRoman(segment.text),
          language: 'Roman Urdu',
          script: CaptionScript.romanUrdu,
        ));
      } else {
        output.add(segment);
      }
    }

    return PreparedTranscript(
      text: output.map((segment) => segment.text).join(' '),
      segments: List.unmodifiable(output),
      language: _combinedLanguage(output, fallback),
    );
  }

  static String _combinedLanguage(List<CaptionSegment> segments, String fallback) {
    if (segments.any((s) => s.language == 'Roman Urdu')) return 'Roman Urdu';
    if (segments.any((s) => s.language == 'Urdu')) return 'Urdu';
    return fallback;
  }

  static bool _containsDevanagari(String text) => RegExp(r'[\u0900-\u097F]').hasMatch(text);

  static Iterable<String> _tokensWithWhitespace(String text) sync* {
    final tokenPattern = RegExp(r'\s+|\S+');
    for (final match in tokenPattern.allMatches(text)) {
      yield match.group(0)!;
    }
  }

  /// Conservative Urdu-oriented Devanagari normalization. Common Urdu words
  /// get exact lexical mappings first; unknown characters fall back to a
  /// script-preserving transliteration rather than disappearing.
  static String devanagariToUrdu(String text) {
    const words = <String, String>{
      'आप': 'آپ',
      'आपका': 'آپ کا',
      'आपकी': 'آپ کی',
      'आपके': 'آپ کے',
      'कैसे': 'کیسے',
      'हैं': 'ہیں',
      'है': 'ہے',
      'क्या': 'کیا',
      'कहाँ': 'کہاں',
      'कहां': 'کہاں',
      'मैं': 'میں',
      'मुझे': 'مجھے',
      'मेरा': 'میرا',
      'मेरी': 'میری',
      'मेरे': 'میرے',
      'तुम': 'تم',
      'तुम्हें': 'تمہیں',
      'हम': 'ہم',
      'हमारा': 'ہمارا',
      'और': 'اور',
      'में': 'میں',
      'से': 'سے',
      'को': 'کو',
      'का': 'کا',
      'की': 'کی',
      'के': 'کے',
      'नहीं': 'نہیں',
      'नही': 'نہیں',
      'बहुत': 'بہت',
      'ठीक': 'ٹھیک',
      'अच्छा': 'اچھا',
      'अच्छे': 'اچھے',
      'आज': 'آج',
      'कल': 'کل',
      'घर': 'گھر',
      'बात': 'بات',
      'कर': 'کر',
      'करना': 'کرنا',
      'चाहिए': 'چاہیے',
    };

    final out = StringBuffer();
    for (final token in _tokensWithWhitespace(text)) {
      if (token.trim().isEmpty) {
        out.write(token);
        continue;
      }
      final core = token.trim();
      final match = RegExp(r'^([\u0964\u0965,.!?؟،]*)(.*?)([\u0964\u0965,.!?؟،]*)$').firstMatch(core)!;
      final clean = match.group(2)!;
      final mapped = words[clean] ?? _devanagariCharacterMap(clean);
      out.write(match.group(1));
      out.write(mapped);
      out.write(match.group(3));
    }
    return out.toString();
  }

  static String _devanagariCharacterMap(String value) {
    const map = <String, String>{
      'अ': 'ا', 'आ': 'آ', 'इ': 'اِ', 'ई': 'ی', 'उ': 'اُ', 'ऊ': 'او',
      'ए': 'ے', 'ऐ': 'اے', 'ओ': 'و', 'औ': 'او',
      'क': 'ک', 'ख': 'خ', 'ग': 'گ', 'घ': 'گھ', 'ङ': 'نگ',
      'च': 'چ', 'छ': 'چھ', 'ज': 'ج', 'झ': 'جھ', 'ञ': 'نی',
      'ट': 'ٹ', 'ठ': 'ٹھ', 'ड': 'ڈ', 'ढ': 'ڈھ', 'ण': 'ن',
      'त': 'ت', 'थ': 'تھ', 'द': 'د', 'ध': 'دھ', 'न': 'ن',
      'प': 'پ', 'फ': 'ف', 'ब': 'ب', 'भ': 'بھ', 'म': 'م',
      'य': 'ی', 'र': 'ر', 'ल': 'ل', 'व': 'و', 'श': 'ش', 'ष': 'ش',
      'स': 'س', 'ह': 'ہ', 'ज़': 'ز', 'जं': 'ج',
      'ा': 'ا', 'ि': 'ِ', 'ी': 'ی', 'ु': 'ُ', 'ू': 'و', 'े': 'ے',
      'ै': 'ے', 'ो': 'و', 'ौ': 'و', 'ं': 'ں', 'ँ': 'ں', 'ः': 'ہ',
      '्': '', '़': '', 'ृ': 'رِ', '्र': 'ر',
    };
    final out = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      out.write(map[char] ?? char);
    }
    return out.toString();
  }

  /// Display-oriented Urdu romanization. Common words are mapped lexically
  /// first so the result remains natural Roman Urdu instead of raw phonetic
  /// character-by-character output.
  static String urduToRoman(String text) {
    const words = <String, String>{
      'آپ': 'aap',
      'کیسے': 'kaise',
      'ہیں': 'hain',
      'ہے': 'hai',
      'کیا': 'kya',
      'کہاں': 'kahan',
      'میں': 'mein',
      'مجھے': 'mujhe',
      'میرا': 'mera',
      'میری': 'meri',
      'میرے': 'mere',
      'تم': 'tum',
      'تمہیں': 'tumhein',
      'ہم': 'hum',
      'ہمارا': 'hamara',
      'اور': 'aur',
      'سے': 'se',
      'کو': 'ko',
      'کا': 'ka',
      'کی': 'ki',
      'کے': 'ke',
      'نہیں': 'nahi',
      'بہت': 'bohat',
      'ٹھیک': 'theek',
      'اچھا': 'acha',
      'اچھے': 'ache',
      'آج': 'aaj',
      'کل': 'kal',
      'گھر': 'ghar',
      'بات': 'baat',
      'کر': 'kar',
      'کرنا': 'karna',
      'چاہیے': 'chahiye',
    };

    final out = StringBuffer();
    for (final token in _tokensWithWhitespace(text)) {
      if (token.trim().isEmpty) {
        out.write(token);
        continue;
      }
      final core = token.trim();
      final match = RegExp(r'^([^\u0600-\u06FF]*)([\u0600-\u06FF]+)([^\u0600-\u06FF]*)$').firstMatch(core);
      if (match != null) {
        final mapped = words[match.group(2)!] ?? _urduCharacterMap(match.group(2)!);
        out.write(match.group(1));
        out.write(mapped);
        out.write(match.group(3));
      } else {
        out.write(_urduCharacterMap(core));
      }
    }
    return out.toString().trim();
  }

  static String _urduCharacterMap(String text) {
    const map = <String, String>{
      'ا': 'a', 'آ': 'aa', 'ب': 'b', 'پ': 'p', 'ت': 't', 'ٹ': 't', 'ث': 's',
      'ج': 'j', 'چ': 'ch', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ڈ': 'd', 'ذ': 'z',
      'ر': 'r', 'ڑ': 'r', 'ز': 'z', 'ژ': 'zh', 'س': 's', 'ش': 'sh', 'ص': 's',
      'ض': 'z', 'ط': 't', 'ظ': 'z', 'ع': '', 'غ': 'gh', 'ف': 'f', 'ق': 'q',
      'ک': 'k', 'گ': 'g', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ں': 'n', 'و': 'w',
      'ہ': 'h', 'ھ': 'h', 'ء': '', 'ی': 'y', 'ے': 'e', 'ۓ': 'e',
      'َ': 'a', 'ِ': 'i', 'ُ': 'u', 'ّ': '', 'ْ': '', 'ً': 'an', 'ٌ': 'un', 'ٍ': 'in',
      '۔': '.', '،': ',', '؟': '?',
    };
    final out = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      out.write(map[char] ?? char);
    }
    return out.toString();
  }
}
