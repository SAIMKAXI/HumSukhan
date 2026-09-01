import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';

void main() {
  group('Conversation Mode gold-standard behavior', () {
    test('a speaker turn appears as one finalized caption, never as a visible partial', () {
      final conversation = ConversationProvider();
      conversation.startConversation();
      conversation.beginSpeakerTurn(language: 'Auto');
      conversation.updateSpeakerTurn('I want to ask about tomorrow', language: 'English');
      conversation.updateSpeakerTurn("I want to ask about tomorrow's meeting", language: 'English');

      expect(conversation.captions, isEmpty);
      expect(conversation.currentPartial?.text, "I want to ask about tomorrow's meeting");

      conversation.commitSpeakerTurn();

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.single.text, "I want to ask about tomorrow's meeting");
      expect(conversation.captions.single.isPartial, isFalse);
      expect(conversation.currentPartial, isNull);
      expect(conversation.isListening, isFalse);

      conversation.dispose();
    });

    test('completed speaker text retains its original turn timestamp', () {
      final conversation = ConversationProvider();
      conversation.startConversation();
      conversation.beginSpeakerTurn(language: 'Urdu');
      conversation.updateSpeakerTurn('مجھے کل آفس جانا ہے', language: 'Urdu');
      final turnTimestamp = conversation.currentPartial!.timestamp;

      conversation.commitSpeakerTurn();

      expect(conversation.captions.single.timestamp, turnTimestamp);
      expect(conversation.captions.single.language, 'Urdu');

      conversation.dispose();
    });
  });
}
