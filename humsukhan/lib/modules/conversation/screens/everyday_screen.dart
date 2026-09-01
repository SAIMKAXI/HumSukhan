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
  bool _speakerActionInFlight = false;
  int _speakerTurnToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  Future<void> _initSpeech() async {
    final speech = context.read<SpeechProvider>();
    await speech.initialize(preferredLanguage: 'Auto');
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted || result.text.trim().isEmpty) return;
      final conv = context.read<ConversationProvider>();
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

  Future<void> _toggleSpeakerListening() async {
    if (!mounted || _speakerActionInFlight) return;
    final conv = context.read<ConversationProvider>();
    if (conv.state != ConversationState.active) return;

    final speech = context.read<SpeechProvider>();
    _speakerActionInFlight = true;
    final token = ++_speakerTurnToken;

    try {
      if (speech.isListening) {
        await speech.stopListening();
        if (!mounted || token != _speakerTurnToken) return;
        conv.commitSpeakerTurn();
        _scrollToBottom();
        return;
      }

      conv.beginSpeakerTurn(language: 'Auto');
      if (mounted) setState(() {});

      // Auto mode uses the low-latency Deepgram streaming recognizer. It
      // explicitly requests/validates microphone access and has a platform
      // speech fallback if the cloud stream cannot be established.
      await speech.startListening(language: 'Auto');

      if (!speech.isListening) {
        final reason = speech.sttProvider.lastStartError;
        conv.commitSpeakerTurn();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason ?? 'Live speech recognition could not be started.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      _speakerActionInFlight = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _stop() async {
    _speakerTurnToken++;
    _speakerActionInFlight = true;
    await context.read<SpeechProvider>().stopListening();
    if (mounted) context.read<ConversationProvider>().stopConversation();
    _speakerActionInFlight = false;
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
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: .3))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _textController,
                          enabled: !conv.isListening,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: conv.isListening ? 'Speaker is talking…' : s.typeResponse,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) _sendTypedText(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Speak response',
                      icon: Icon(speech.isSpeaking ? Icons.stop : Icons.volume_up),
                      onPressed: conv.isListening || _textController.text.trim().isEmpty
                          ? null
                          : () => speech.isSpeaking
                              ? speech.stopSpeaking()
                              : speech.speak(_textController.text.trim(), language: 'Auto'),
                    ),
                    const SizedBox(width: 2),
                    IconButton.filled(
                      tooltip: 'Send response',
                      icon: const Icon(Icons.send),
                      onPressed: conv.isListening || _textController.text.trim().isEmpty
                          ? null
                          : () => _sendTypedText(_textController.text),
                    ),
                  ],
                ),
              ),
            ),
          if (conv.state == ConversationState.active)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: PrimaryActionButton(label: s.stopConversation, icon: Icons.stop, onPressed: _stop),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeakerControls(BuildContext context, ConversationProvider conv, SettingsProvider settings, ThemeData theme) {
    final busy = _speakerActionInFlight;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: .06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(conv.isListening ? Icons.record_voice_over : Icons.mic_none, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    busy
                        ? 'Starting speech recognition…'
                        : conv.isListening
                            ? 'Tap the microphone to stop'
                            : 'Tap the microphone to start speaker captions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: conv.isListening ? 'Stop speaker microphone' : 'Start speaker microphone',
              child: InkResponse(
                radius: 52,
                onTap: busy ? null : _toggleSpeakerListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: busy
                        ? theme.colorScheme.surfaceContainerHighest
                        : conv.isListening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                    boxShadow: conv.isListening
                        ? [BoxShadow(color: theme.colorScheme.error.withValues(alpha: .25), blurRadius: 16, spreadRadius: 2)]
                        : [],
                  ),
                  child: busy
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
                        )
                      : Icon(
                          conv.isListening ? Icons.mic : Icons.mic_none,
                          color: theme.colorScheme.onPrimary,
                          size: 36,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Bilingual speaker captions', style: theme.textTheme.labelLarge),
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
          Text('Start a conversation, then tap the microphone whenever the speaker talks.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: captions.length + (conv.currentPartial != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == captions.length && conv.currentPartial != null) {
                    return KeyedSubtree(
                      key: ValueKey(conv.currentPartial!.id),
                      child: SpeakableCaptionBubble(caption: conv.currentPartial!, textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast),
                    );
                  }
                  final caption = captions[index];
                  return KeyedSubtree(
                    key: ValueKey(caption.id),
                    child: SpeakableCaptionBubble(caption: caption, textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast),
                  );
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
