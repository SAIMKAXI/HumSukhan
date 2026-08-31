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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  Future<void> _initSpeech() async {
    final speech = context.read<SpeechProvider>();
    await speech.initialize();
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted) return;
      final conv = context.read<ConversationProvider>();
      if (result.text.trim().isEmpty) return;
      if (result.isFinal) {
        conv.finalizeCaption(result.text, language: result.language);
        speech.detectLanguage(result.text);
      } else {
        conv.addPartialCaption(result.text, language: result.language);
      }
      _scrollToBottom();
    });
  }

  Future<void> _start() async {
    final conv = context.read<ConversationProvider>();
    final speech = context.read<SpeechProvider>();
    conv.startConversation();
    // Caption language is an explicit preference when set; otherwise English is
    // the platform-neutral starting locale and the result language is surfaced.
    final language = context.read<SettingsProvider>().captionLanguage;
    await speech.startListening(language: language == 'Roman Urdu' ? 'Urdu' : language);
    if (!speech.isLiveStt && mounted) {
      conv.stopConversation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is unavailable. Download a speech model or check microphone access.')),
      );
    }
  }

  Future<void> _stop() async {
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
              child: Center(child: StatusIndicator(label: conv.listeningStatus, color: theme.colorScheme.primary, isActive: conv.isListening, icon: Icons.mic)),
            ),
        ],
      ),
      body: Column(children: [
        if (conv.state == ConversationState.active || conv.state == ConversationState.starting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.primary.withValues(alpha: .08),
            child: Row(children: [
              Icon(conv.isListening ? Icons.mic : Icons.hourglass_empty, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(conv.isListening ? s.listeningStatus : conv.listeningStatus, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppTokens.radiusFull)),
                child: Text(speech.sttModeLabel, style: theme.textTheme.labelSmall),
              ),
            ]),
          ),
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
                  onTap: () {
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
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: s.typeResponse,
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
                tooltip: 'Speak reply',
                icon: Icon(speech.isSpeaking ? Icons.stop : Icons.volume_up),
                onPressed: _textController.text.trim().isEmpty ? null : () => speech.isSpeaking ? speech.stopSpeaking() : speech.speak(_textController.text.trim(), language: settings.captionLanguage),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: 'Send reply',
                icon: const Icon(Icons.send),
                onPressed: () => _sendTypedText(_textController.text),
              ),
            ]),
          ),
        if (conv.state == ConversationState.active)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryActionButton(label: s.stopConversation, icon: Icons.stop, onPressed: _stop),
          ),
      ]),
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
          Text(s.listeningDots, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryActionButton(label: s.startListening, icon: Icons.mic, onPressed: _start),
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
            ? Center(child: Text(s.listeningDots, style: theme.textTheme.bodyLarge))
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
