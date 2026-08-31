import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';

void main() {
  group('ConversationProvider chat log', () {
    test('new speech turn commits the previous partial instead of replacing it', () {
      final conversation = ConversationProvider();
      conversation.startConversation();

      conversation.addPartialCaption('Hello, how are you?');
      conversation.addPartialCaption('I am doing well, thank you.');

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.first.text, 'Hello, how are you?');
      expect(conversation.captions.first.isPartial, isFalse);
      expect(conversation.currentPartial?.text, 'I am doing well, thank you.');

      conversation.dispose();
    });

    test('user reply is placed after the active speaker turn', () {
      final conversation = ConversationProvider();
      conversation.startConversation();

      conversation.addPartialCaption('Good morning today');
      conversation.addPartialCaption('Let us discuss the meeting agenda');
      conversation.addOwnCaption('My reply');

      expect(conversation.captions, hasLength(3));
      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>[
          'Good morning today',
          'Let us discuss the meeting agenda',
          'My reply',
        ],
      );
      expect(conversation.captions.last.isOwn, isTrue);

      conversation.dispose();
    });

    test('final speech result upgrades the active partial without changing its position timestamp', () {
      final conversation = ConversationProvider();
      conversation.startConversation();

      conversation.addPartialCaption('Hello there');
      final partialTimestamp = conversation.currentPartial!.timestamp;

      conversation.finalizeCaption('Hello there, welcome.');

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.single.text, 'Hello there, welcome.');
      expect(conversation.captions.single.timestamp, partialTimestamp);
      expect(conversation.currentPartial, isNull);

      conversation.dispose();
    });
  });
}
