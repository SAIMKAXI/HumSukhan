import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/turn_taking.dart';

void main() {
  group('How finished speech sounds', () {
    void sounds(String text, Completeness expected) =>
        expect(TurnTaking.completeness(text), expected, reason: text);

    test('English', () {
      sounds('I went to the market.', Completeness.complete);
      sounds('Can you hear me?', Completeness.complete);
      sounds('Yes, I can.', Completeness.complete);
      sounds('Yes.', Completeness.complete);
      sounds('okay', Completeness.complete);
      // A recognizer puts a full stop wherever the speaker paused.
      sounds('I went to the.', Completeness.unfinished);
      sounds('I was thinking that', Completeness.unfinished);
      sounds('so um', Completeness.unfinished);
      sounds('Well, I wanted to say...', Completeness.unfinished);
      sounds('Market.', Completeness.open);
      sounds('maybe tomorrow', Completeness.open);
    });

    test('Urdu', () {
      sounds('میں بازار گیا تھا', Completeness.complete);
      sounds('آپ کیسے ہیں؟', Completeness.complete);
      sounds('میں کل آؤں گا۔', Completeness.complete);
      sounds('ٹھیک', Completeness.complete);
      sounds('میں نے کہا کہ', Completeness.unfinished);
      sounds('وہ گھر کے', Completeness.unfinished);
      sounds('اور', Completeness.unfinished);
      // A full stop after a postposition does not end an Urdu sentence.
      sounds('ہم سب لوگ بازار سے۔', Completeness.unfinished);
    });

    test('Roman Urdu', () {
      sounds('main ja raha hoon', Completeness.complete);
      sounds('mujhe pata nahi', Completeness.complete);
      sounds('maine kaha ke', Completeness.unfinished);
      sounds('woh ghar mein', Completeness.unfinished);
    });
  });

  group('How long a pause ends the caption', () {
    const base = Duration(milliseconds: 1700);

    test('short after a finished sentence, longer when it hangs', () {
      final complete = TurnTaking.pauseToEnd('I am going home now.', base: base);
      final open = TurnTaking.pauseToEnd('maybe tomorrow', base: base);
      final unfinished = TurnTaking.pauseToEnd('I wanted to tell you that', base: base);
      expect(complete, lessThan(const Duration(seconds: 1)));
      expect(open, base);
      expect(unfinished, greaterThan(const Duration(milliseconds: 2500)));
    });

    test('a speaker who pauses long mid-thought is given longer', () {
      final usual = TurnTaking.pauseToEnd('maybe tomorrow', base: base);
      final slow = TurnTaking.pauseToEnd('maybe tomorrow', base: base, speakerPause: const Duration(milliseconds: 2400));
      expect(slow, greaterThan(usual));
    });

    test('never shorter than 0.6 s or longer than 4.5 s', () {
      expect(TurnTaking.pauseToEnd('Done.', base: const Duration(milliseconds: 800)), TurnTaking.shortest);
      expect(
        TurnTaking.pauseToEnd('and', base: const Duration(seconds: 4), speakerPause: const Duration(seconds: 4)),
        TurnTaking.longest,
      );
    });
  });

  group('Joining speech after a pause', () {
    test('a hesitation carries the sentence on, without the stray full stop', () {
      expect(TurnTaking.join('I want to.', 'Go home now.', newSentence: false), 'I want to go home now.');
      expect(TurnTaking.join('Please call.', 'Ali tomorrow.', newSentence: false), 'Please call Ali tomorrow.',
          reason: 'names keep their capital');
    });

    test('a new sentence after a finished one is closed and capitalised', () {
      expect(TurnTaking.join('I am fine', 'how are you?', newSentence: true), 'I am fine. How are you?');
      expect(TurnTaking.join('میں ٹھیک ہوں', 'آپ کیسے ہیں؟', newSentence: true), 'میں ٹھیک ہوں۔ آپ کیسے ہیں؟');
      expect(TurnTaking.join('I am fine.', 'Thanks.', newSentence: true), 'I am fine. Thanks.');
    });
  });

  test('a speaker\'s usual pause is learned once there are a few', () {
    final pauses = SpeakerPauses();
    pauses.carriedOn(const Duration(milliseconds: 400));
    pauses.carriedOn(const Duration(milliseconds: 600));
    expect(pauses.typical, isNull);
    pauses.carriedOn(const Duration(milliseconds: 900));
    pauses.carriedOn(const Duration(milliseconds: 700));
    expect(pauses.typical, const Duration(milliseconds: 700));
  });

  group('Professional sentences', () {
    test('a piece cut off mid-sentence waits for the rest', () {
      final sentences = SentenceAssembler();
      expect(sentences.add('I went to the.'), isNull);
      expect(sentences.add('Market yesterday.'), 'I went to the Market yesterday.');
      expect(sentences.add('It was busy.'), 'It was busy.');
    });

    test('Urdu pieces are joined into one sentence', () {
      final sentences = SentenceAssembler();
      expect(sentences.add('ہم نے فیصلہ کیا کہ'), isNull);
      expect(sentences.add('کل میٹنگ ہوگی۔'), 'ہم نے فیصلہ کیا کہ کل میٹنگ ہوگی۔');
    });

    test('what is held is kept when listening stops', () {
      final sentences = SentenceAssembler();
      sentences.add('The deadline is');
      expect(sentences.flush(tail: 'next Friday'), 'The deadline is next Friday');
      expect(sentences.flush(), isNull);
    });
  });
}
