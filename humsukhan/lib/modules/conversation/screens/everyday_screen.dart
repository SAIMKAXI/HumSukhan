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
  String _speechLanguage = 'Auto';
  String? _speechError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  Future<void> _initSpeech() async {
    final speech = context.read<SpeechProvider>();
    await speech.initialize(preferredLanguage: _speechLanguage);
    await _speechSubscription?.cancel();
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted || result.text.trim().isEmpty) return;
      final conv = context.read<ConversationProvider>();
      if (!conv.isSpeakerTurnActive) return;
      // Interim and final stream updates are buffered internally. Nothing from
      // this callback is rendered directly; one completed bubble is committed
      // when the speaker stops.
      conv.updateSpeakerTurn(result.text, language: result.language);
      if (result.isFinal) speech.detectLanguage(result.text);
    });
  }

  Future<void> _startConversation() async {
    final conv = context.read<ConversationProvider>();
    conv.startConversation();
    if (mounted) setState(() => _speechError = null);
  }

  Future<void> _toggleSpeakerListening() async {
    if (!mounted || _speakerActionInFlight) return;
    final conv = context.read<ConversationProvider>();
    if (conv.state != ConversationState.active) return;

    final speech = context.read<SpeechProvider>();
    _speakerActionInFlight = true;
    final token = ++_speakerTurnToken;
    if (mounted) setState(() => _speechError = null);

    try {
      if (speech.isListening) {
        await speech.stopListening();
        if (!mounted || token != _speakerTurnToken) return;
        conv.commitSpeakerTurn();
        _scrollToBottom();
        return;
      }

      conv.beginSpeakerTurn(language: _speechLanguage);
      if (mounted) setState(() {});
      await speech.startListening(language: _speechLanguage);

      if (!speech.isListening) {
        final reason = speech.sttProvider.lastStartError;
        conv.commitSpeakerTurn();
        if (mounted) {
          setState(() => _speechError = reason ?? 'Live speech recognition could not be started.');
        }
      }
    } finally {
      _speakerActionInFlight = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectSpeechLanguage(String language) async {
    if (_speakerActionInFlight || context.read<SpeechProvider>().isListening) return;
    setState(() => _speechLanguage = language);
    await context.read<SpeechProvider>().switchLanguage(language);
    if (mounted) setState(() => _speechError = null);
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
    final connectivity = context.watch<ConnectivityProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.everydayTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Speech language',
            initialValue: _speechLanguage,
            onSelected: _selectSpeechLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Auto', child: Text('Auto — Urdu + English')),
              PopupMenuItem(value: 'English', child: Text('English')),
              PopupMenuItem(value: 'Urdu', child: Text('Urdu')),
            ],
            icon: const Icon(Icons.translate_rounded),
          ),
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: StatusIndicator(
                  label: conv.isListening ? 'Listening' : 'Ready',
                  color: colors.primary,
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
                    : _buildCaptionArea(context, conv, settings, s, connectivity),
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
                    onTap: conv.isListening ? null : () {
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
                            hintText: conv.isListening ? 'Listening…' : s.typeResponse,
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
                          : () => speech.isSpeaking ? speech.stopSpeaking() : speech.speak(_textController.text.trim(), language: _speechLanguage),
                    ),
                    const SizedBox(width: 2),
                    IconButton.filled(
                      tooltip: 'Send response',
                      icon: const Icon(Icons.send),
                      onPressed: conv.isListening || _textController.text.trim().isEmpty ? null : () => _sendTypedText(_textController.text),
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
    final listening = conv.isListening;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: .06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            if (_speechError != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_speechError!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                ]),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    busy ? 'Starting…' : listening ? 'Listening…' : 'Tap microphone to speak',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PulsingMicButton(
              listening: listening,
              busy: busy,
              onPressed: busy ? null : _toggleSpeakerListening,
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              error: theme.colorScheme.error,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in const ['Auto', 'English', 'Urdu'])
                  ChoiceChip(
                    label: Text(language),
                    selected: _speechLanguage == language,
                    onSelected: listening || busy ? null : (_) => _selectSpeechLanguage(language),
                  ),
                OfflineBadge(isOnline: context.watch<ConnectivityProvider>().isOnline),
              ],
            ),
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
          Icon(Icons.forum_rounded, size: 72, color: theme.colorScheme.primary.withValues(alpha: .65)),
          const SizedBox(height: 20),
          Text(s.startConversation, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('Speak naturally. HumSukhan shows the complete caption when you finish.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          PrimaryActionButton(label: s.startListening, icon: Icons.chat_rounded, onPressed: _startConversation),
        ]),
      ),
    );
  }

  Widget _buildCaptionArea(BuildContext context, ConversationProvider conv, SettingsProvider settings, AppStrings s, ConnectivityProvider connectivity) {
    final theme = Theme.of(context);
    final captions = conv.captions;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(child: Text('Conversation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          LanguageBadge(language: _speechLanguage),
          const SizedBox(width: 8),
          OfflineBadge(isOnline: connectivity.isOnline),
        ]),
      ),
      Expanded(
        child: captions.isEmpty
            ? Center(child: Text(conv.isListening ? 'Listening…' : 'Waiting for the speaker…', style: theme.textTheme.bodyLarge))
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: captions.length,
                itemBuilder: (context, index) {
                  final caption = captions[index];
                  return KeyedSubtree(
                    key: ValueKey(caption.id),
                    child: SpeakableCaptionBubble(
                      caption: caption,
                      textSize: settings.captionTextSize,
                      isHighContrast: settings.isHighContrast,
                    ),
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
          Icon(Icons.check_circle_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text('Conversation complete', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(s.saveConversationDesc, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          PrimaryActionButton(label: s.save, icon: Icons.save_rounded, onPressed: () => context.read<ConversationProvider>().saveConversation()),
          const SizedBox(height: 10),
          SecondaryActionButton(label: s.delete, icon: Icons.delete_outline_rounded, onPressed: () => context.read<ConversationProvider>().deleteConversation()),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.read<ConversationProvider>().cancelStop(), child: Text(s.continueListening)),
        ]),
      ),
    );
  }
}

class _PulsingMicButton extends StatefulWidget {
  final bool listening;
  final bool busy;
  final VoidCallback? onPressed;
  final Color primary;
  final Color onPrimary;
  final Color error;

  const _PulsingMicButton({
    required this.listening,
    required this.busy,
    required this.onPressed,
    required this.primary,
    required this.onPrimary,
    required this.error,
  });

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop microphone' : 'Start microphone',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = widget.listening ? 1.0 + (_controller.value * .06) : 1.0;
          return Transform.scale(
            scale: pulse,
            child: Material(
              color: widget.busy
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : widget.listening
                      ? widget.error
                      : widget.primary,
              shape: const CircleBorder(),
              elevation: widget.listening ? 8 : 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Center(
                    child: widget.busy
                        ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: widget.primary))
                        : Icon(widget.listening ? Icons.stop_rounded : Icons.mic_rounded, size: 38, color: widget.onPrimary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
