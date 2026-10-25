/// How people pause while they talk, as rules the captions follow.
///
/// A recognizer reports silence, not meaning: a speaker who stops to think
/// in the middle of a sentence and one who has finished look the same to
/// it. These rules read the words said so far to tell the two apart, so a
/// caption is not cut in half while someone searches for a word, and is not
/// left open once they have clearly finished.
///
/// Everything here is plain rules over the text and the timing. No model is
/// involved, so the result is the same on every phone and every run.
library;

/// How finished the words said so far sound.
enum Completeness {
  /// A full sentence: it ends in a full stop or question mark, or, in Urdu,
  /// in the verb or particle that closes a sentence.
  complete,

  /// Could go either way.
  open,

  /// Plainly still going: it ends in "and", "the", "کہ", "کے", a filler
  /// such as "um", or trails off with "...".
  unfinished,
}

class TurnTaking {
  TurnTaking._();

  static const Duration shortest = Duration(milliseconds: 600);
  static const Duration longest = Duration(milliseconds: 4500);

  /// Words a sentence does not end on.
  static const Set<String> _englishHanging = {
    'and', 'or', 'but', 'so', 'because', 'cause', 'if', 'when', 'while',
    'that', 'which', 'who', 'whose', 'where', 'than', 'then', 'as',
    'the', 'a', 'an', 'this', 'these', 'those', 'some', 'any', 'every',
    'to', 'of', 'in', 'at', 'for', 'with', 'from', 'by', 'about',
    'into', 'onto', 'under', 'before', 'between', 'through',
    'my', 'your', 'his', 'our', 'their', 'its',
    'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'i', "i'm", "i'll", "i've", "i'd", 'we', 'they', 'he', 'she',
    'very', 'really', 'just', 'also', 'not', 'like', 'um', 'uh', 'er', 'erm',
    'hmm', 'mm', 'ah',
  };

  /// One-word answers that are complete on their own.
  static const Set<String> _englishWhole = {
    'yes', 'yeah', 'yep', 'no', 'nope', 'okay', 'ok', 'sure', 'thanks',
    'hello', 'hi', 'bye', 'right', 'fine', 'great', 'done', 'please', 'sorry',
    'good', 'nice', 'cool', 'perfect', 'exactly', 'alright', 'absolutely',
  };

  /// Urdu words a sentence does not end on: conjunctions, postpositions,
  /// pronouns waiting for their verb, and fillers.
  static const Set<String> _urduHanging = {
    'اور', 'لیکن', 'مگر', 'بلکہ', 'کہ', 'کیونکہ', 'چونکہ', 'اگر', 'جب', 'جو',
    'جس', 'جن', 'تاکہ', 'یا', 'یعنی', 'مطلب', 'جیسے', 'پھر', 'تو',
    'کے', 'کی', 'کا', 'کو', 'سے', 'میں', 'پر', 'نے', 'تک', 'والا', 'والی', 'والے',
    'بھی', 'ہی', 'بہت', 'زیادہ', 'کچھ', 'ایک',
    'آپ', 'ہم', 'وہ', 'یہ', 'مجھے', 'ہمیں', 'انہیں', 'اس', 'ان', 'میرا', 'میری',
    'میرے', 'آپکا', 'آپ کی', 'اپنا', 'اپنی', 'اپنے',
    'ام', 'اممم', 'ہمم',
  };

  /// Urdu verbs and particles that close a sentence.
  static const Set<String> _urduClosing = {
    'ہے', 'ہیں', 'تھا', 'تھی', 'تھے', 'تھیں', 'ہوں', 'ہو', 'ہوا', 'ہوئی', 'ہوئے',
    'گا', 'گی', 'گے', 'ہوگا', 'ہوگی', 'ہوگے', 'ہونگے', 'گیا', 'گئی', 'گئے', 'گئیں', 'دیا', 'دی', 'دیے', 'لیا', 'لی', 'لیے',
    'رہا', 'رہی', 'رہے', 'چاہیے', 'چاہیئے', 'سکتا', 'سکتی', 'سکتے', 'کریں', 'کرو',
    'کرے', 'کرنا', 'جائیں', 'جاؤ', 'آئیں', 'آؤ', 'دیں', 'دو', 'لیں', 'لو', 'بتائیں',
    'کیا', 'نہیں', 'ہاں', 'جی', 'ٹھیک', 'شکریہ', 'اچھا', 'بالکل', 'خدا حافظ', 'سلام',
  };

  /// The same, as the English recognizer writes Urdu out in Latin letters.
  static const Set<String> _romanHanging = {
    'aur', 'lekin', 'magar', 'balkay', 'balke', 'ke', 'ki', 'ka', 'ko', 'se',
    'mein', 'mai', 'par', 'pe', 'ne', 'tak', 'kyunke', 'kyunki', 'kyonke',
    'agar', 'jab', 'jo', 'ya', 'yani', 'matlab', 'jaise', 'phir', 'bhi',
    'wala', 'wali', 'walay', 'wale', 'bohat', 'bahut', 'kuch',
  };

  static const Set<String> _romanClosing = {
    'hai', 'hain', 'hay', 'tha', 'thi', 'thay', 'thy', 'hoon', 'hun', 'ho',
    'hua', 'hui', 'huay', 'ga', 'gi', 'gay', 'gaya', 'gayi', 'gaye', 'diya',
    'liya', 'raha', 'rahi', 'rahe', 'chahiye', 'sakta', 'sakti', 'sakte',
    'karein', 'karo', 'jayein', 'jao', 'nahi', 'nahin', 'haan', 'ji', 'theek',
    'shukriya', 'acha', 'achha', 'bilkul',
  };

  static final RegExp _edgePunctuation = RegExp(r'''^[\s"'“”‘’(\[]+|[\s"'“”‘’)\],،؛;:]+$''');
  static final RegExp _terminal = RegExp(r'[.?!۔؟]$');
  static final RegExp _trailingOff = RegExp(r'(\.\.\.|…|-|—)$');
  static final RegExp _urduScript = RegExp(r'[؀-ۿ]');

  /// How finished [text] sounds as the end of what someone is saying.
  static Completeness completeness(String text) {
    final trimmed = text.trim().replaceAll(_edgePunctuation, '');
    if (trimmed.isEmpty) return Completeness.open;
    if (_trailingOff.hasMatch(trimmed)) return Completeness.unfinished;

    final words = trimmed.split(RegExp(r'\s+'));
    final last = _bare(words.last);
    final lastTwo = words.length > 1 ? '${_bare(words[words.length - 2])} $last' : last;
    final terminal = _terminal.hasMatch(trimmed);

    // Recognizers put a full stop wherever the speaker paused, so a full
    // stop after "and" or "کے" does not end the sentence.
    if (_englishHanging.contains(last) ||
        _urduHanging.contains(last) ||
        _urduHanging.contains(lastTwo) ||
        _romanHanging.contains(last)) {
      return Completeness.unfinished;
    }
    if (_urduClosing.contains(last) || _urduClosing.contains(lastTwo) || _romanClosing.contains(last)) {
      return Completeness.complete;
    }
    if (terminal) {
      // One word ending in a full stop is usually a pause, not an answer.
      if (words.length == 1 && !_englishWhole.contains(last)) return Completeness.open;
      return Completeness.complete;
    }
    if (words.length == 1 && _englishWhole.contains(last)) return Completeness.complete;
    return Completeness.open;
  }

  /// How long the silence after [text] must last before the caption is
  /// finished. [base] is the pause the user chose; [speakerPause] is how
  /// long this speaker usually pauses in the middle of a thought, once known.
  static Duration pauseToEnd(String text, {required Duration base, Duration? speakerPause}) {
    final typical = speakerPause ?? Duration.zero;
    final Duration wait;
    switch (completeness(text)) {
      case Completeness.complete:
        // A finished sentence ends the caption quickly, unless this speaker
        // is known to pause longer between sentences that belong together.
        final quick = _max(shortest, base * 0.45);
        wait = _max(quick, _min(typical * 0.8, base));
      case Completeness.open:
        wait = _max(base, typical * 1.3);
      case Completeness.unfinished:
        wait = _max(base * 1.8, typical * 1.8);
    }
    return _min(_max(wait, shortest), longest);
  }

  /// Joins speech that came after a pause to the words before it. After a
  /// hesitation ([newSentence] false) it carries on the same sentence, and a
  /// full stop the recognizer put at the pause is removed. After a finished
  /// sentence it starts a new one, closing the previous one if the
  /// recognizer did not.
  static String join(String previous, String next, {required bool newSentence}) {
    final before = previous.trim();
    final after = next.trim();
    if (before.isEmpty) return after;
    if (after.isEmpty) return before;
    if (newSentence) {
      final closed = _terminal.hasMatch(before) ? before : '$before${_urduScript.hasMatch(_lastWord(before)) ? '۔' : '.'}';
      return '$closed ${_capitalize(after)}';
    }
    final open = before.endsWith('.') && !before.endsWith('...') ? before.substring(0, before.length - 1) : before;
    return '$open ${_lowerFirst(after)}';
  }

  static String _bare(String word) => word
      .toLowerCase()
      .replaceAll(RegExp(r'''[.?!۔؟,،;:"'“”‘’()\[\]]'''), '')
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ه', 'ہ');

  static String _lastWord(String text) => text.split(RegExp(r'\s+')).last;

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// Lower-cases the capital a recognizer gives the first word after its
  /// own full stop, for common words only, so names keep theirs.
  static String _lowerFirst(String text) {
    final first = text.split(' ').first;
    final lower = first.toLowerCase();
    if (first == lower || !(_englishHanging.contains(lower) || _englishCommon.contains(lower))) return text;
    if (lower == 'i' || lower.startsWith("i'")) return text;
    return lower + text.substring(first.length);
  }

  static const Set<String> _englishCommon = {
    'it', 'you', 'there', 'here', 'what', 'how', 'why', 'all', 'more', 'now',
    'going', 'want', 'need', 'think', 'know', 'get', 'go', 'come', 'make',
    'take', 'see', 'tell', 'say', 'said', 'yesterday', 'today', 'tomorrow',
    'please', 'maybe', 'actually', 'basically', 'something', 'someone',
    'everything', 'nothing', 'one', 'two', 'three', 'me', 'him', 'them', 'us',
  };

  static Duration _max(Duration a, Duration b) => a > b ? a : b;
  static Duration _min(Duration a, Duration b) => a < b ? a : b;
}

/// How long one speaker pauses in the middle of what they are saying,
/// learned from the pauses after which they carried on.
class SpeakerPauses {
  SpeakerPauses({this.remember = 12});

  final int remember;
  final List<Duration> _pauses = [];

  /// The speaker carried on after a pause of [pause].
  void carriedOn(Duration pause) {
    if (pause <= Duration.zero || pause > TurnTaking.longest) return;
    _pauses.add(pause);
    if (_pauses.length > remember) _pauses.removeAt(0);
  }

  /// A pause this speaker reaches three times in four, once there are
  /// enough to tell; null before that.
  Duration? get typical {
    if (_pauses.length < 3) return null;
    final sorted = [..._pauses]..sort();
    return sorted[((sorted.length - 1) * 0.75).round()];
  }

  void clear() => _pauses.clear();
}

/// Puts Professional Mode's recognized pieces back into sentences.
///
/// A recognizer ends a piece at every pause, so "I went to the." and
/// "market yesterday." would be kept as two lines. A piece that plainly
/// carries on is held and joined to the next; anything else is kept at once.
class SentenceAssembler {
  String _pending = '';

  /// Words held, waiting for the rest of their sentence.
  String get pending => _pending;

  /// Adds a recognized piece and returns what is ready to keep, if anything.
  String? add(String piece) {
    final text = piece.trim();
    if (text.isEmpty) return null;
    _pending = TurnTaking.join(_pending, text, newSentence: false);
    if (TurnTaking.completeness(_pending) == Completeness.unfinished) return null;
    return flush();
  }

  /// Returns and clears whatever is held, joined to [tail] (words heard but
  /// not yet recognized as final), or null if there is nothing.
  String? flush({String tail = ''}) {
    final text = TurnTaking.join(_pending, tail, newSentence: false).trim();
    _pending = '';
    return text.isEmpty ? null : text;
  }
}
