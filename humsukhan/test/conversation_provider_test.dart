import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';

void main() {
  test('keeps finalized speaker utterance before a later user reply', () async {
    final conversation = ConversationProvider();
    conversation.startConversation();

    conversation.addPartialCaption('First sentence');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    conversation.addOwnCaption('User reply');
    conversation.finalizeCaption('First sentence');

    final captions = conversation.captions;
    expect(captions, hasLength(2));
    expect(captions.first.text, 'First sentence');
    expect(captions.first.isOwn, isFalse);
    expect(captions.last.text, 'User reply');
    expect(captions.last.isOwn, isTrue);
    expect(captions.first.timestamp.isBefore(captions.last.timestamp), isTrue);
  });

  test('keeps every finalized utterance in the conversation log', () {
    final conversation = ConversationProvider();
    conversation.startConversation();

    conversation.finalizeCaption('Hello there');
    conversation.finalizeCaption('How are you?');
    conversation.addOwnCaption('I am fine.');

    expect(conversation.captions.map((c) => c.text).toList(), [
      'Hello there',
      'How are you?',
      'I am fine.',
    ]);
  });
}
