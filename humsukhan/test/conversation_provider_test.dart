import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:humsukhan/providers/conversation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy saved conversations are removed and new ones are never persisted', () async {
    SharedPreferences.setMockInitialValues({
      'everydayConversations:guest': '[{"id":"old","captions":[]}]',
      'everydayConversations:user-1': '[]',
    });

    final conversation = ConversationProvider();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('everydayConversations:')),
      isEmpty,
    );

    conversation.startConversation();
    conversation.addOwnCaption('Temporary reply');
    conversation.stopConversation();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      prefs.getKeys().where((key) => key.startsWith('everydayConversations:')),
      isEmpty,
    );
    conversation.deleteConversation();
    conversation.dispose();
  });

  group('ConversationProvider chat log', () {
    test('interim speech stays in the hidden draft and does not create a caption', () {
      final conversation = ConversationProvider();
      conversation.startConversation();
      conversation.beginSpeakerTurn(language: 'English');

      conversation.updateSpeakerTurn('Good morning', language: 'English');
      conversation.updateSpeakerTurn('Good morning, how are you today?', language: 'English');

      expect(conversation.captions, isEmpty);
      expect(conversation.currentPartial?.text, 'Good morning, how are you today?');
      expect(conversation.currentPartial?.isPartial, isTrue);

      conversation.dispose();
    });

    test('finalized speaker turn becomes one caption and user reply follows it', () {
      final conversation = ConversationProvider();
      conversation.startConversation();

      conversation.beginSpeakerTurn(language: 'English');
      conversation.updateSpeakerTurn('I want to ask about tomorrow', language: 'English');
      conversation.updateSpeakerTurn("I want to ask about tomorrow's meeting", language: 'English');
      conversation.commitSpeakerTurn();
      conversation.addOwnCaption('My reply');

      expect(conversation.captions, hasLength(2));
      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>["I want to ask about tomorrow's meeting", 'My reply'],
      );
      expect(conversation.captions.first.isPartial, isFalse);
      expect(conversation.captions.last.isOwn, isTrue);

      conversation.dispose();
    });

    test('final speech result upgrades the active draft without changing its position timestamp', () {
      final conversation = ConversationProvider();
      conversation.startConversation();
      conversation.beginSpeakerTurn(language: 'Urdu');
      conversation.updateSpeakerTurn('مجھے کل آفس جانا ہے', language: 'Urdu');
      final partialTimestamp = conversation.currentPartial!.timestamp;

      conversation.finalizeCaption('مجھے کل آفس جانا ہے، شکریہ۔', language: 'Urdu');

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.single.text, 'مجھے کل آفس جانا ہے، شکریہ۔');
      expect(conversation.captions.single.timestamp, partialTimestamp);
      expect(conversation.captions.single.language, 'Urdu');
      expect(conversation.currentPartial, isNull);

      conversation.dispose();
    });
  });
}
