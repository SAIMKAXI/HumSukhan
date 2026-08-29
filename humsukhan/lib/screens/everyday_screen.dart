import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSpeech();
    });
  }

  void _initSpeech() {
    final speech = context.read<SpeechProvider>();
    speech.initialize();
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted) return;
      final conv = context.read<ConversationProvider>();
      if (result.isFinal) {
        conv.finalizeCaption(result.text, language: result.language);
        speech.detectLanguage(result.text);
      } else {
        conv.addPartialCaption(result.text, language: result.language);
      }
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
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
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.everydayTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: StatusIndicator(
                label: conv.listeningStatus,
                color: AppTheme.successLight,
                isActive: conv.isListening,
                icon: Icons.mic,
              ),
            ),
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusIndicator(
                label: '${s.durationLabel}: ${conv.formattedDuration}',
                color: Theme.of(context).colorScheme.primary,
                isActive: true,
                icon: Icons.timer,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Listening Status Banner
          if (conv.state == ConversationState.active || conv.state == ConversationState.starting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: conv.isListening
                  ? AppTheme.successLight.withValues(alpha: 0.1)
                  : AppTheme.warningLight.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    conv.isListening ? Icons.mic : Icons.hourglass_empty,
                    color: conv.isListening ? AppTheme.successLight : AppTheme.warningLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    conv.isListening ? s.listeningStatus : conv.listeningStatus,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: conv.isListening ? AppTheme.successLight : AppTheme.warningLight,
                    ),
                  ),
                  const Spacer(),
                  // STT Mode indicator
                  Consumer<SpeechProvider>(
                    builder: (_, speech, _) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: speech.isOfflineMode
                            ? AppTheme.successLight.withValues(alpha: 0.2)
                            : speech.isOnlineMode
                                ? AppTheme.primaryLight.withValues(alpha: 0.2)
                                : AppTheme.warningLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            speech.isOfflineMode ? Icons.wifi_off : Icons.wifi,
                            size: 12,
                            color: speech.isOfflineMode
                                ? AppTheme.successLight
                                : speech.isOnlineMode
                                    ? AppTheme.primaryLight
                                    : AppTheme.warningLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            speech.sttModeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: speech.isOfflineMode
                                  ? AppTheme.successLight
                                  : speech.isOnlineMode
                                      ? AppTheme.primaryLight
                                      : AppTheme.warningLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Privacy Banner
          if (conv.state == ConversationState.idle)
            PrivacyNotice(
              text: s.privacyNote,
            ),

          // Caption Area
          Expanded(
            child: conv.state == ConversationState.idle
                ? _buildIdleState(context, s)
                : conv.state == ConversationState.saveDecision
                    ? _buildSaveDecision(context, s)
                    : _buildCaptionArea(context, conv, settings, s),
          ),

          // Quick Replies
          if (conv.state == ConversationState.active)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...quickReplies.replies.take(6).map((reply) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: QuickReplyChip(
                        reply: reply,
                        isHighContrast: settings.isHighContrast,
                        onTap: () {
                          conv.addOwnCaption(reply.text);
                          _scrollToBottom();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          if (conv.state == ConversationState.active)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: s.typeResponse,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (text) => _sendTypedText(text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Speak button
                  Container(
                    decoration: BoxDecoration(
                      color: speech.isSpeaking ? AppTheme.errorLight : Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        speech.isSpeaking ? Icons.stop : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: _textController.text.isNotEmpty
                          ? () {
                              if (speech.isSpeaking) {
                                speech.stopSpeaking();
                              } else {
                                speech.speak(_textController.text);
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendTypedText(_textController.text),
                    ),
                  ),
                ],
              ),
            ),

          // Stop Button
          if (conv.state == ConversationState.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PrimaryActionButton(
                label: s.stopConversation,
                icon: Icons.stop,
                onPressed: () {
                  context.read<SpeechProvider>().stopListening();
                  conv.stopConversation();
                },
              ),
            ),
        ],
      ),
    );
  }

  void _sendTypedText(String text) {
    if (text.trim().isEmpty) return;
    final conv = context.read<ConversationProvider>();
    conv.addOwnCaption(text.trim());
    _textController.clear();
    _scrollToBottom();
  }

  Widget _buildIdleState(BuildContext context, AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              s.startConversation,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              s.listeningDots,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PrimaryActionButton(
              label: s.startListening,
              icon: Icons.mic,
              onPressed: () {
                context.read<ConversationProvider>().startConversation();
                context.read<SpeechProvider>().startListening();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionArea(BuildContext context, ConversationProvider conv, SettingsProvider settings, AppStrings s) {
    return Column(
      children: [
        // Language indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              LanguageBadge(language: conv.currentLanguage),
              const SizedBox(width: 8),
              Consumer<ConnectivityProvider>(
                builder: (_, conn, _) => OfflineBadge(isOnline: conn.isOnline),
              ),
            ],
          ),
        ),

        // Captions list
        Expanded(
          child: conv.captions.isEmpty && conv.currentPartial == null
              ? Center(
                  child: Text(
                    s.listeningDots,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conv.captions.length + (conv.currentPartial != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == conv.captions.length && conv.currentPartial != null) {
                      return CaptionBubble(
                        caption: conv.currentPartial!,
                        textSize: settings.captionTextSize,
                        isHighContrast: settings.isHighContrast,
                      );
                    }
                    return CaptionBubble(
                      caption: conv.captions[index],
                      textSize: settings.captionTextSize,
                      isHighContrast: settings.isHighContrast,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSaveDecision(BuildContext context, AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_alt, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              s.saveConversation,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              s.saveConversationDesc,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PrimaryActionButton(
              label: s.save,
              icon: Icons.save,
              onPressed: () => context.read<ConversationProvider>().saveConversation(),
            ),
            const SizedBox(height: 12),
            SecondaryActionButton(
              label: s.delete,
              icon: Icons.delete_outline,
              onPressed: () => _showDeleteConfirmation(context, s),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<ConversationProvider>().cancelStop(),
              child: Text(s.continueListening),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteConversation),
        content: Text(s.deleteConversationDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ConversationProvider>().deleteConversation();
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
