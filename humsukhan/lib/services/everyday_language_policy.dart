/// Language/script policy for Everyday Mode.
///
/// Product languages are English and Urdu. Hindi/Devanagari is never a valid
/// Everyday caption output, even if an upstream recognizer returns it.
class EverydayLanguagePolicy {
  EverydayLanguagePolicy._();

  static final RegExp urduScript = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final RegExp devanagariScript = RegExp(r'[\u0900-\u097F]');
  static final RegExp latinScript = RegExp(r'[A-Za-z]');

  static bool containsUrduScript(String text) => urduScript.hasMatch(text);
  static bool containsHindiScript(String text) => devanagariScript.hasMatch(text);
  static bool containsLatin(String text) => latinScript.hasMatch(text);

  static String sanitizeHindi(String text) {
    if (!containsHindiScript(text)) return text;
    final cleaned = text
        .replaceAll(RegExp(r'[\u0900-\u097F]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return cleaned;
  }

  static String languageForText(String text, {String fallback = 'English'}) {
    final value = sanitizeHindi(text).trim();
    if (value.isEmpty) return fallback;
    if (containsUrduScript(value)) return 'Urdu';
    return 'English';
  }

  /// Keeps RTL Urdu runs and LTR Latin runs visually separated using Unicode
  /// directional embeddings/marks. This affects display order only.
  static String withBidiIsolation(String text) {
    final value = sanitizeHindi(text).trim();
    if (value.isEmpty) return value;
    final tokens = _tokensWithWhitespace(value);
    final out = StringBuffer();
    var lastWasWhitespace = false;
    for (final token in tokens) {
      if (token.trim().isEmpty) {
        if (!lastWasWhitespace && out.isNotEmpty) out.write(' ');
        lastWasWhitespace = true;
        continue;
      }
      if (out.isNotEmpty && !lastWasWhitespace) out.write(' ');
      if (containsUrduScript(token)) {
        out.write('\u2067'); // RLI
        out.write(token);
        out.write('\u2069'); // PDI
      } else if (containsLatin(token)) {
        out.write('\u2066'); // LRI
        out.write(token);
        out.write('\u2069'); // PDI
      } else {
        out.write(token);
      }
      lastWasWhitespace = false;
    }
    return out.toString();
  }

  /// Roman Urdu is only applied to Urdu-script runs. English is preserved.
  static String toEnglishMode(String text) {
    final sanitized = sanitizeHindi(text);
    if (sanitized.isEmpty) return sanitized;

    final out = StringBuffer();
    for (final piece in _tokensWithWhitespace(sanitized)) {
      if (piece.trim().isEmpty) {
        out.write(piece);
      } else if (containsUrduScript(piece)) {
        out.write(_romanizeWord(piece));
      } else {
        out.write(piece);
      }
    }
    return out.toString().trim();
  }

  static Iterable<String> _tokensWithWhitespace(String text) sync* {
    final tokenPattern = RegExp(r'\s+|\S+');
    for (final match in tokenPattern.allMatches(text)) {
      yield match.group(0)!;
    }
  }

  static final Map<String, String> _common = <String, String>{
    'آپ': 'Aap',
    'اپ': 'Ap',
    'آپکو': 'Aapko',
    'آپ کو': 'Aap ko',
    'کیسے': 'kaise',
    'کیسا': 'kaisa',
    'کیسی': 'kaisi',
    'ہیں': 'hain',
    'ہے': 'hai',
    'ہوں': 'hoon',
    'میں': 'mein',
    'مَیں': 'mein',
    'ہم': 'hum',
    'تم': 'tum',
    'مجھ': 'mujh',
    'مجھے': 'mujhe',
    'میرا': 'mera',
    'میری': 'meri',
    'میرے': 'mere',
    'آپکا': 'aapka',
    'آپکی': 'aapki',
    'آپکے': 'aapke',
    'کیا': 'kya',
    'کیوں': 'kyun',
    'کون': 'kaun',
    'کہاں': 'kahan',
    'کہ': 'ke',
    'یہ': 'yeh',
    'وہ': 'woh',
    'نہیں': 'nahi',
    'نہيں': 'nahin',
    'نہیں۔': 'nahi.',
    'اچھا': 'achha',
    'اچھی': 'achi',
    'اچھے': 'achhe',
    'ٹھیک': 'theek',
    'چاہیے': 'chahiye',
    'بھی': 'bhi',
    'بس': 'bas',
    'اب': 'ab',
    'اور': 'aur',
    'لیکن': 'lekin',
    'پھر': 'phir',
    'کرنا': 'karna',
    'کرو': 'karo',
    'کریں': 'karein',
    'جانا': 'jana',
    'جاؤ': 'jao',
    'آؤ': 'aao',
    'آنا': 'aana',
    'کل': 'kal',
    'آج': 'aaj',
    'کلک': 'kal',
    'گھر': 'ghar',
    'بات': 'baat',
    'برا': 'bura',
    'بہت': 'bohat',
    'شکریہ': 'shukriya',
    'سلام': 'salam',
    'خدا': 'khuda',
    'حافظ': 'hafiz',
  };

  static String _romanizeWord(String word) {
    final leading = RegExp(r'^\p{P}+', unicode: true).stringMatch(word) ?? '';
    final trailing = RegExp(r'\p{P}+$', unicode: true).stringMatch(word) ?? '';
    final start = leading.length;
    final end = trailing.isEmpty ? word.length : word.length - trailing.length;
    final core = word.substring(start, end);

    final common = _common[core];
    if (common != null) return '$leading$common$trailing';

    var value = core
        .replaceAll('ﷲ', 'Allah')
        .replaceAll('ﷺ', 'sallallahu alaihi wasallam')
        .replaceAll('ٔ', '')
        .replaceAll('ٕ', '')
        .replaceAll('َ', '')
        .replaceAll('ِ', '')
        .replaceAll('ُ', '')
        .replaceAll('ّ', '')
        .replaceAll('ْ', '')
        .replaceAll('ً', '')
        .replaceAll('ٌ', '')
        .replaceAll('ٍ', '');

    const digraphs = <String, String>{
      'بھ': 'bh',
      'پھ': 'ph',
      'تھ': 'th',
      'ٹھ': 'th',
      'جھ': 'jh',
      'چھ': 'chh',
      'دھ': 'dh',
      'ڈھ': 'dh',
      'ڑھ': 'rh',
      'کھ': 'kh',
      'گھ': 'gh',
      'ش': 'sh',
      'چ': 'ch',
      'ژ': 'zh',
      'خ': 'kh',
      'غ': 'gh',
    };
    for (final entry in digraphs.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }

    const map = <String, String>{
      'ا': 'a', 'آ': 'aa', 'ب': 'b', 'پ': 'p', 'ت': 't', 'ٹ': 't',
      'ث': 's', 'ج': 'j', 'ح': 'h', 'د': 'd', 'ڈ': 'd', 'ذ': 'z',
      'ر': 'r', 'ڑ': 'r', 'ز': 'z', 'س': 's', 'ص': 's', 'ض': 'z',
      'ط': 't', 'ظ': 'z', 'ع': 'a', 'ف': 'f', 'ق': 'q', 'ک': 'k',
      'گ': 'g', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ں': 'n', 'و': 'w',
      'ہ': 'h', 'ھ': 'h', 'ء': "'", 'ؤ': 'o', 'ئ': 'i', 'ی': 'y',
      'ے': 'e', 'ۓ': 'e', 'ۃ': 't', 'ة': 't', 'ـ': '',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char);
    }
    var roman = buffer
        .toString()
        .replaceAll(RegExp(r"'+$"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    roman = roman
        .replaceAll(RegExp(r'^aap$'), 'Aap')
        .replaceAll(RegExp(r'^kais+y$'), 'kaise')
        .replaceAll(RegExp(r'^hyn$'), 'hain')
        .replaceAll('yh', 'y')
        .replaceAll('ww', 'w')
        .replaceAll('aaee', 'aai');
    return '$leading$roman$trailing';
  }
}
