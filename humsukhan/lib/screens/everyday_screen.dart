import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';
import '../l10n/app_strings.dart';

class EverydayScreen extends StatefulWidget {
  const EverydayScreen({super.key});
  @override
  State<EverydayScreen> createState() => _EverydayScreenState();
}

class _EverydayScreenState extends State<EverydayScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _speechSubscription;
  bool _speakerPressActive = false;
  int _speakerTurnToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  Future<void> _initSpeech() async {
    final speech = context.read<SpeechProvider>();
    await speech.initialize();
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted || result.text.trim().isEmpty) return;
      final conv = context.read<ConversationProvider>();
      // Conversational Mode is intentionally push-to-talk. STT results only
      // belong to the currently held speaker turn and never start listening by
      // themselves.
      if (!conv.isSpeakerTurnActive) return;
      conv.updateSpeakerTurn(result.text, language: result.language);
      speech.detectLanguage(result.text);
      _scrollToBottom();
    });
  }

  Future<void> _startConversation() async {
    final conv = context.read<ConversationProvider>();
    conv.startConversation();
    if (mounted) setState(() {});
  }

  Future<void> _beginSpeakerPress() async {
    if (!mounted || _speakerPressActive) return;
    final conv = context.read<ConversationProvider>();
    if (conv.state != ConversationState.active) return;

    final settings = context.read<SettingsProvider>();
    final speech = context.read<SpeechProvider>();
    final language = settings.captionLanguage == 'Roman Urdu' ? 'Urdu' : settings.captionLanguage;

    _speakerPressActive = true;
    _speakerTurnToken++;
    final token = _speakerTurnToken;
    conv.beginSpeakerTurn(language: language);
    if (mounted) setState(() {});

    await speech.startListening(language: language);

    if (!speech.isListening && mounted && token == _speakerTurnToken) {
      _speakerPressActive = false;
      conv.commitSpeakerTurn();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The speaker microphone could not start. Check microphone permission or the speech model.')),
      );
    }
  }

  Future<void> _endSpeakerPress() async {
    if (!_speakerPressActive) return;
    _speakerPressActive = false;
    _speakerTurnToken++;
    final speech = context.read<SpeechProvider>();

    // Stop the recognizer first so its trailing final event can update the
    // current turn. A short drain window prevents the last word being lost.
    await speech.stopListening();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    context.read<ConversationProvider>().commitSpeakerTurn();
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _stop() async {
    _speakerPressActive = false;
    _speakerTurnToken++;
    await context.read<SpeechProvider>().stopListening();
    if (mounted) context.read<ConversationProvider>().stopConversation();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speakerTurnToken++;
    _speechSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = context.watch<ConversationProvider>();
    final settings = context.watch<SettingsProvider>();
    final quickReplies = context.watch<QuickReplyProvider>();
    final speech = context.watch<SpeechProvider>();
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.everydayTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: StatusIndicator(
                  label: conv.isListening ? 'Speaker talking' : 'Waiting for speaker',
                  color: theme.colorScheme.primary,
                  isActive: conv.isListening,
                  icon: conv.isListening ? Icons.mic : Icons.mic_none,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (conv.state == ConversationState.active || conv.state == ConversationState.starting)
            _buildSpeakerControls(context, conv, settings, theme),
          if (conv.state == ConversationState.idle) PrivacyNotice(text: s.privacyNote),
          Expanded(
            child: conv.state == ConversationState.idle
                ? _buildIdleState(context, s)
                : conv.state == ConversationState.saveDecision
                    ? _buildSaveDecision(context, s)
                    : _buildCaptionArea(context, conv, settings, s),
          ),
          if (conv.state == ConversationState.active)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: quickReplies.replies.take(6).map((reply) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: QuickReplyChip(
                    reply: reply,
                    isHighContrast: settings.isHighContrast,
                    onTap: conv.isListening
                        ? null
                        : () {
                            conv.addOwnCaption(reply.text);
                            _scrollToBottom();
                          },
                  ),
                )).toList(),
              ),
            ),
          if (conv.state == ConversationState.active)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: .3))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !conv.isListening,
                      decoration: InputDecoration(
                        hintText: conv.isListening ? 'Speaker is talking…' : s.typeResponse,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusFull), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _sendTypedText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Speak response',
                    icon: Icon(speech.isSpeaking ? Icons.stop : Icons.volume_up),
                    onPressed: conv.isListening || _textController.text.trim().isEmpty
                        ? null
                        : () => speech.isSpeaking
                            ? speech.stopSpeaking()
                            : speech.speak(_textController.text.trim(), language: settings.captionLanguage),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Send response',
                    icon: const Icon(Icons.send),
                    onPressed: conv.isListening ? null : () => _sendTypedText(_textController.text),
                  ),
                ],
              ),
            ),
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PrimaryActionButton(label: s.stopConversation, icon: Icons.stop, onPressed: _stop),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeakerControls(BuildContext context, ConversationProvider conv, SettingsProvider settings, ThemeData theme) {
    final language = settings.captionLanguage;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Text(
              conv.isListening
                  ? 'Release when the speaker finishes'
                  : 'Speaker: hold the microphone while talking',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _beginSpeakerPress(),
              onTapUp: (_) => _endSpeakerPress(),
              onTapCancel: _endSpeakerPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: conv.isListening ? theme.colorScheme.error : theme.colorScheme.primary,
                  boxShadow: [
                    if (conv.isListening)
                      BoxShadow(color: theme.colorScheme.error.withValues(alpha: .30), blurRadius: 18, spreadRadius: 3),
                  ],
                ),
                child: Icon(
                  conv.isListening ? Icons.mic : Icons.mic_none,
                  color: theme.colorScheme.onPrimary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(language, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }

  void _sendTypedText(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    context.read<ConversationProvider>().addOwnCaption(value);
    _textController.clear();
    setState(() {});
    _scrollToBottom();
  }

  Widget _buildIdleState(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 24),
          Text(s.startConversation, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Start a conversation, then the speaker can hold the microphone for each turn.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryActionButton(label: s.startListening, icon: Icons.chat, onPressed: _startConversation),
        ]),
      ),
    );
  }

  Widget _buildCaptionArea(BuildContext context, ConversationProvider conv, SettingsProvider settings, AppStrings s) {
    final theme = Theme.of(context);
    final captions = conv.captions;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          LanguageBadge(language: conv.currentLanguage),
          const SizedBox(width: 8),
          OfflineBadge(isOnline: context.watch<ConnectivityProvider>().isOnline),
        ]),
      ),
      Expanded(
        child: captions.isEmpty && conv.currentPartial == null
            ? Center(child: Text('Waiting for the speaker…', style: theme.textTheme.bodyLarge))
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: captions.length + (conv.currentPartial != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == captions.length && conv.currentPartial != null) {
                    return SpeakableCaptionBubble(caption: conv.currentPartial!, textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast);
                  }
                  return SpeakableCaptionBubble(caption: captions[index], textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast);
                },
              ),
      ),
    ]);
  }

  Widget _buildSaveDecision(BuildContext context, AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.save_alt, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(s.saveConversation, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(s.saveConversationDesc, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryActionButton(label: s.save, icon: Icons.save, onPressed: () => context.read<ConversationProvider>().saveConversation()),
          const SizedBox(height: 12),
          SecondaryActionButton(label: s.delete, icon: Icons.delete_outline, onPressed: () => context.read<ConversationProvider>().deleteConversation()),
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.read<ConversationProvider>().cancelStop(), child: Text(s.continueListening)),
        ]),
      ),
    );
  }
}
