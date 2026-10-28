/// Notices words about self-harm or suicide in a check-in note, in English,
/// Urdu and Roman Urdu.
///
/// A match never blocks or reports anything. It only makes HumSukhan show
/// its fixed help screen straight away instead of everyday suggestions. A
/// false alarm therefore costs one extra screen, while a miss could cost far
/// more, so the phrases lean towards matching.
class CrisisWords {
  CrisisWords._();

  /// Phrases matched at the start of a word, after [normalize]. "suicid"
  /// matches "suicide" and "suicidal".
  static const List<String> phrases = [
    // English
    'suicid', 'kill myself', 'killing myself', 'end my life', 'ending my life',
    'take my own life', 'take my life', 'want to die', 'wanna die', 'wish i was dead',
    'wish i were dead', 'better off dead', 'hurt myself', 'hurting myself', 'harm myself',
    'self harm', 'cut myself', 'cutting myself', 'no reason to live', 'dont want to live',
    'do not want to live', 'cant go on', 'end it all',
    // Urdu
    'خودکشی', 'خود کشی', 'خود کو مار', 'خود کو ختم', 'اپنی جان لے', 'اپنی جان دے',
    'مرنا چاہتا', 'مرنا چاہتی', 'مر جانا چاہتا', 'مر جانا چاہتی', 'کاش میں مر',
    'جینا نہیں چاہتا', 'جینا نہیں چاہتی', 'جینے کی کوئی وجہ نہیں', 'زندگی ختم کر',
    'خود کو نقصان', 'خود کو تکلیف',
    // Roman Urdu
    'khudkushi', 'khud kushi', 'khudkashi', 'khud kashi', 'khud ko maar', 'khud ko mar',
    'khud ko khatam', 'apni jaan le', 'apni jan le', 'apni jaan de', 'marna chahta',
    'marna chahti', 'mar jana chahta', 'mar jana chahti', 'kash main mar', 'kaash main mar',
    'jeena nahi chahta', 'jeena nahi chahti', 'jina nahi chahta', 'jina nahi chahti',
    'jeene ki koi wajah nahi', 'zindagi khatam kar', 'khud ko nuksan', 'khud ko nuqsan',
  ];

  static final List<String> _normalizedPhrases = [for (final p in phrases) normalize(p)];

  /// Whether [text] contains any of [phrases].
  static bool mentionsSelfHarm(String text) {
    final normalized = ' ${normalize(text)} ';
    if (normalized.trim().isEmpty) return false;
    for (final phrase in _normalizedPhrases) {
      if (normalized.contains(' $phrase')) return true;
    }
    return false;
  }

  /// Lower case, one spelling per Urdu letter, no vowel marks, no
  /// apostrophes or punctuation, single spaces.
  static String normalize(String text) {
    var value = text.toLowerCase();
    value = value
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ه', 'ہ')
        .replaceAll('ۀ', 'ہ')
        .replaceAll('‌', ' ')
        .replaceAll('‍', '');
    // Arabic-script vowel marks and the superscript alef.
    value = value.replaceAll(RegExp('[ً-ٰٟ]'), '');
    // Apostrophes join ("can't" -> "cant"); other punctuation separates.
    value = value.replaceAll(RegExp("['’`]"), '');
    value = value.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
    return value.trim();
  }
}
