/// Conservative detector for Roman Urdu written with Latin characters.
///
/// A single token is not enough because common words such as "main", "to",
/// or "se" can legitimately occur in English text. Detection therefore uses
/// weighted lexical signals and requires either multiple independent signals or
/// a distinctive phrase.
class RomanUrduDetector {
  RomanUrduDetector._();

  static const Map<String, int> _signals = {
    'aap': 3,
    'ap': 3,
    'aapko': 3,
    'aapki': 3,
    'aapke': 3,
    'aapka': 3,
    'mujhe': 3,
    'mujh': 3,
    'mera': 2,
    'meri': 2,
    'mere': 2,
    'apna': 2,
    'apni': 2,
    'apne': 2,
    'hum': 2,
    'ham': 2,
    'tum': 2,
    'tumhe': 3,
    'tumhain': 3,
    'aaj': 2,
    'kal': 1,
    'abhi': 2,
    'phir': 2,
    'kyun': 3,
    'kyon': 3,
    'kya': 2,
    'kaise': 3,
    'kaisa': 2,
    'kaisi': 2,
    'hain': 3,
    'hai': 1,
    'ho': 1,
    'hoga': 2,
    'hogi': 2,
    'honge': 2,
    'nahi': 3,
    'nahin': 3,
    'acha': 2,
    'achha': 2,
    'theek': 2,
    'chahiye': 3,
    'karna': 2,
    'karo': 2,
    'karein': 3,
    'karen': 3,
    'karungi': 3,
    'karunga': 3,
    'jayen': 3,
    'jana': 2,
    'jaana': 2,
    'jao': 2,
    'aana': 2,
    'ao': 2,
    'bhi': 1,
    'sirf': 2,
    'bohat': 3,
    'bahut': 3,
    'zyada': 2,
    'kam': 1,
    'bilkul': 3,
    'zaroor': 3,
    'zarur': 3,
    'shayad': 3,
    'lekin': 2,
    'magar': 2,
    'kyunke': 3,
    'kyonke': 3,
    'isliye': 3,
    'mujhse': 3,
    'apko': 3,
    'aapse': 3,
  };

  static const Set<String> _strongSignals = {
    'aap', 'ap', 'aapko', 'aapki', 'aapke', 'aapka',
    'mujhe', 'mujhse', 'tumhe', 'tumhain',
    'kyun', 'kyon', 'kaise', 'nahi', 'nahin', 'chahiye',
    'bohat', 'bahut', 'bilkul', 'zaroor', 'zarur', 'shayad',
    'kyunke', 'kyonke', 'isliye',
  };

  static final RegExp _wordPattern = RegExp(r"[a-z]+(?:'[a-z]+)?", caseSensitive: false);

  static Set<String> _tokens(String text) {
    return _wordPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();
  }

  static bool isRomanUrdu(String text) {
    final tokens = _tokens(text);
    if (tokens.isEmpty) return false;

    final strongHits = tokens.intersection(_strongSignals).length;
    if (strongHits >= 1 && tokens.length >= 2) {
      final score = tokens.fold<int>(0, (sum, token) => sum + (_signals[token] ?? 0));
      if (score >= 4) return true;
    }

    final score = tokens.fold<int>(0, (sum, token) => sum + (_signals[token] ?? 0));
    return score >= 5 && tokens.length >= 3;
  }
}
