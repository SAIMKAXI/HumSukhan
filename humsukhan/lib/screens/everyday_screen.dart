import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';
import '../l10n/app_strings.dart';
import '../utils/urdu_text.dart';

class EverydayScreen extends StatefulWidget {
  const EverydayScreen({super.key});
  @override
  State<EverydayScreen> createState() => _EverydayScreenState();
}

class _EverydayScreenState extends State<EverydayScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ConversationEngine _engine;
  bool _typedUrdu = false;

  @override
  void initState() {
    super.initState();
    _engine = ConversationEngine(
      speech: context.read<SpeechProvider>(),
      conversation: context.read<ConversationProvider>(),
    )..addListener(_onEngineChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  void _onEngineChanged() { if (mounted) setState(() {}); }

  Future<void> _initSpeech() async {
    final speech = context.read<SpeechProvider>();
    await speech.initialize(preferredLanguage: 'Auto');
    unawaited(speech.warmUpTts());
  }

  void _startConversation() { _engine.startConversation(); _scrollToBottom(); }
  void _toggleSpeakerListening() { if (_engine.isBusy) return; _engine.toggleListening(); }
  void _stop() { _engine.stopAndEndConversation(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _engine..removeListener(_onEngineChanged)..dispose();
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
    final appIsUrdu = settings.appLanguage == 'ur';
    final inputIsUrdu = _typedUrdu || appIsUrdu;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.everydayTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: StatusIndicator(label: _engine.statusLabel, color: theme.colorScheme.primary, isActive: conv.isListening, icon: conv.isListening ? Icons.mic : Icons.mic_none)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (conv.state == ConversationState.active || conv.state == ConversationState.starting) _buildSpeakerControls(context, conv, settings, theme),
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
                  child: QuickReplyChip(reply: reply, isHighContrast: settings.isHighContrast, onTap: conv.isListening || _engine.isBusy ? null : () { conv.addOwnCaption(reply.text); _scrollToBottom(); }),
                )).toList(),
              ),
            ),
          if (conv.state == ConversationState.active)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: .3)))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _textController,
                          enabled: !conv.isListening && !_engine.isBusy,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textDirection: inputIsUrdu ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: inputIsUrdu ? TextAlign.right : TextAlign.left,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontFamily: inputIsUrdu ? 'NotoNastaliqUrdu' : null, fontSize: 17, height: 1.45),
                          decoration: InputDecoration(
                            hintText: conv.isListening ? 'Speaker is talking…' : (appIsUrdu ? 'اردو یا انگریزی میں جواب لکھیں' : 'Type in Urdu or English'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusFull), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onChanged: (value) {
                            final isUrdu = containsUrduScript(value);
                            if (isUrdu != _typedUrdu) setState(() => _typedUrdu = isUrdu);
                            else setState(() {});
                          },
                          onSubmitted: (value) { if (value.trim().isNotEmpty) _sendTypedText(value); },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Speak response',
                      icon: Icon(speech.isSpeaking ? Icons.stop : Icons.volume_up),
                      onPressed: conv.isListening || _engine.isBusy || _textController.text.trim().isEmpty
                          ? null
                          : () => _speakOrStop(speech, _textController.text.trim()),
                    ),
                    const SizedBox(width: 2),
                    IconButton.filled(
                      tooltip: 'Send response',
                      icon: const Icon(Icons.send),
                      onPressed: conv.isListening || _engine.isBusy || _textController.text.trim().isEmpty ? null : () => _sendTypedText(_textController.text),
                    ),
                  ],
                ),
              ),
            ),
          if (conv.state == ConversationState.active)
            SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 12), child: PrimaryActionButton(label: s.stopConversation, icon: Icons.stop, onPressed: _stop))),
        ],
      ),
    );
  }

  Widget _buildSpeakerControls(BuildContext context, ConversationProvider conv, SettingsProvider settings, ThemeData theme) {
    final busy = _engine.isBusy;
    final listening = conv.isListening;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: .06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(listening ? Icons.record_voice_over : Icons.mic_none, color: theme.colorScheme.primary), const SizedBox(width: 8), Flexible(child: Text(_engine.statusLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center))]),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: listening ? 'Stop speaker microphone' : 'Start speaker microphone',
            child: InkResponse(
              radius: 52,
              onTap: busy ? null : _toggleSpeakerListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120), width: 78, height: 78,
                decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? theme.colorScheme.surfaceContainerHighest : listening ? theme.colorScheme.error : theme.colorScheme.primary, boxShadow: listening ? [BoxShadow(color: theme.colorScheme.error.withValues(alpha: .25), blurRadius: 16, spreadRadius: 2)] : []),
                child: busy ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary)) : Icon(listening ? Icons.mic : Icons.mic_none, color: theme.colorScheme.onPrimary, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Bilingual speaker captions', style: theme.textTheme.labelLarge), const SizedBox(width: 8), PopupMenuButton<int>(tooltip: 'Pause before ending utterance', initialValue: _engine.pauseThreshold.inMilliseconds, onSelected: (value) => _engine.setPauseThreshold(Duration(milliseconds: value)), itemBuilder: (context) => const [PopupMenuItem(value: 1200, child: Text('Short pause · 1.2 s')), PopupMenuItem(value: 1700, child: Text('Natural pause · 1.7 s')), PopupMenuItem(value: 2500, child: Text('Patient pause · 2.5 s')), PopupMenuItem(value: 0, child: Text('Manual only · no auto-stop'))], icon: Icon(Icons.more_time, size: 20, color: theme.colorScheme.primary))]),
          if (_engine.state == ConversationEngineState.waitingForTurnEnd) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Pause detected — speak again to continue', style: theme.textTheme.bodySmall, textAlign: TextAlign.center)),
          if (_engine.isManualPauseMode) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Manual mode — tap the microphone to end the utterance', style: theme.textTheme.bodySmall, textAlign: TextAlign.center)),
        ]),
      ),
    );
  }

  Future<void> _speakOrStop(SpeechProvider speech, String text, {String language = 'Auto'}) async {
    if (speech.isSpeaking) {
      await speech.stopSpeaking();
      return;
    }
    try {
      await speech.speak(text, language: language);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not speak this message: $e')),
      );
    }
  }

  void _sendTypedText(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    context.read<ConversationProvider>().addOwnCaption(value);
    _textController.clear();
    if (mounted) setState(() => _typedUrdu = false);
    _scrollToBottom();
  }

  Widget _buildIdleState(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.chat_bubble_outline, size: 80, color: theme.colorScheme.outlineVariant), const SizedBox(height: 24), Text(s.startConversation, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center), const SizedBox(height: 12), Text('Start a conversation, then tap the microphone whenever the speaker talks.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center), const SizedBox(height: 32), PrimaryActionButton(label: s.startListening, icon: Icons.chat, onPressed: _startConversation)])));
  }

  Widget _buildCaptionArea(BuildContext context, ConversationProvider conv, SettingsProvider settings, AppStrings s) {
    final theme = Theme.of(context);
    final captions = conv.captions;
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [LanguageBadge(language: conv.currentLanguage), const SizedBox(width: 8), OfflineBadge(isOnline: context.watch<ConnectivityProvider>().isOnline)])),
      Expanded(
        child: captions.isEmpty && conv.currentPartial == null
            ? Center(child: Text('Waiting for the speaker…', style: theme.textTheme.bodyLarge))
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: captions.length + (conv.currentPartial != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == captions.length && conv.currentPartial != null) return KeyedSubtree(key: ValueKey(conv.currentPartial!.id), child: SpeakableCaptionBubble(caption: conv.currentPartial!, textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast));
                  final caption = captions[index];
                  return KeyedSubtree(key: ValueKey(caption.id), child: SpeakableCaptionBubble(caption: caption, textSize: settings.captionTextSize, isHighContrast: settings.isHighContrast));
                },
              ),
      ),
    ]);
  }

  Widget _buildSaveDecision(BuildContext context, AppStrings s) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.save_alt, size: 64, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 24), Text(s.saveConversation, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center), const SizedBox(height: 12), Text(s.saveConversationDesc, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center), const SizedBox(height: 32), PrimaryActionButton(label: s.save, icon: Icons.save, onPressed: () => context.read<ConversationProvider>().saveConversation()), const SizedBox(height: 12), SecondaryActionButton(label: s.delete, icon: Icons.delete_outline, onPressed: () => context.read<ConversationProvider>().deleteConversation()), const SizedBox(height: 12), TextButton(onPressed: () => context.read<ConversationProvider>().cancelStop(), child: Text(s.continueListening))])));
  }
}
