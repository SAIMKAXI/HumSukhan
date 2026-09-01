import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/stt/enhanced_stt.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';

class SessionLiveScreen extends StatefulWidget {
  final String sessionId;

  const SessionLiveScreen({super.key, required this.sessionId});

  @override
  State<SessionLiveScreen> createState() => _SessionLiveScreenState();
}

class _SessionLiveScreenState extends State<SessionLiveScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _captionController = TextEditingController();

  StreamSubscription<SpeechResultEvent>? _speechSubscription;
  Timer? _durationTimer;
  DateTime _startTime = DateTime.now();

  Caption? _hiddenDraft;
  String _speechStatus = 'Preparing microphone…';
  String? _startupError;
  bool _sessionStarting = true;
  bool _isListening = false;
  bool _acceptSpeechResults = false;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  Future<void> _initSession() async {
    if (!mounted) return;
    final pro = context.read<ProfessionalProvider>();
    final session = pro.sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    if (session == null) {
      setState(() {
        _sessionStarting = false;
        _startupError = 'This session could not be opened because it no longer exists.';
        _speechStatus = 'Session unavailable';
      });
      return;
    }

    await pro.startSessionRecording(widget.sessionId);

    final speech = context.read<SpeechProvider>();
    try {
      await speech.initialize(preferredLanguage: session.captionLanguage);
      await _speechSubscription?.cancel();
      _speechSubscription = speech.onResult.listen(_handleSpeechResult);
      _startTime = DateTime.now();

      if (!mounted) return;
      setState(() {
        _sessionStarting = false;
        _isListening = false;
        _speechStatus = 'Ready — tap microphone to listen';
        _startupError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionStarting = false;
        _isListening = false;
        _speechStatus = 'Microphone unavailable';
        _startupError = 'Speech setup failed: $error';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (!mounted || _sessionStarting || _isFinalizing) return;

    final pro = context.read<ProfessionalProvider>();
    final session = pro.sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    if (session == null) return;

    final speech = context.read<SpeechProvider>();
    if (_isListening || speech.isListening) {
      await _stopListeningSegment(speech);
      return;
    }

    _acceptSpeechResults = true;
    _hiddenDraft = null;
    setState(() {
      _startupError = null;
      _isListening = false;
      _speechStatus = 'Starting microphone…';
    });

    try {
      await speech.startListening(
        language: session.captionLanguage == 'Roman Urdu'
            ? 'Urdu'
            : session.captionLanguage,
      );
      if (!mounted) return;
      final listening = speech.isListening;
      setState(() {
        _isListening = listening;
        _speechStatus = listening
            ? 'Listening… tap microphone to stop'
            : 'Microphone could not be started';
        if (!listening) {
          _startupError =
              'Speech recognition did not start. The selected language may be unavailable on this device, or microphone access may be blocked.';
          _acceptSpeechResults = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      _acceptSpeechResults = false;
      setState(() {
        _isListening = false;
        _speechStatus = 'Could not start listening';
        _startupError = 'Speech recognition failed: $error';
      });
    }
  }

  Future<void> _stopListeningSegment(SpeechProvider speech) async {
    if (_isFinalizing) return;
    setState(() {
      _isFinalizing = true;
      _isListening = false;
      _speechStatus = 'Finalizing this caption…';
    });

    try {
      // Keep accepting the final recognition event while the STT provider flushes
      // buffered speech. Interim results stay hidden from the transcript UI.
      await speech.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await _flushHiddenDraft();
    } catch (error) {
      if (mounted) {
        setState(() {
          _startupError = 'Stopping speech recognition failed: $error';
        });
      }
    } finally {
      _acceptSpeechResults = false;
      if (mounted) {
        setState(() {
          _isFinalizing = false;
          _isListening = false;
          _speechStatus = 'Microphone off — session still active';
        });
      }
    }
  }

  void _handleSpeechResult(SpeechResultEvent result) {
    if (!mounted || !_acceptSpeechResults) return;
    final text = result.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (!result.isFinal) {
      // Intentionally keep interim recognition internal. Professional Mode must
      // not flash or constantly rewrite transcript text while someone speaks.
      _hiddenDraft = Caption(
        id: _hiddenDraft?.id,
        text: text,
        speaker: 'Speaker 1',
        timestamp: _hiddenDraft?.timestamp ?? now,
        language: result.language,
        isPartial: true,
      );
      return;
    }

    final existing = _hiddenDraft;
    final caption = Caption(
      id: existing?.id,
      text: text,
      speaker: 'Speaker 1',
      timestamp: existing?.timestamp ?? now,
      language: result.language,
      isPartial: false,
    );
    _hiddenDraft = null;
    unawaited(_persistFinalCaption(caption));
  }

  Future<void> _persistFinalCaption(Caption caption) async {
    try {
      await context.read<ProfessionalProvider>().addCaptionToSession(
            widget.sessionId,
            caption,
          );
      if (mounted) {
        setState(() {
          _speechStatus = _isListening
              ? 'Listening… tap microphone to stop'
              : _speechStatus;
        });
      }
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        setState(() {
          _startupError = 'Could not save this caption: $error';
        });
      }
    }
  }

  Future<void> _flushHiddenDraft() async {
    final draft = _hiddenDraft;
    if (draft == null || draft.text.trim().isEmpty) return;
    _hiddenDraft = null;
    await _persistFinalCaption(draft.copyWith(isPartial: false));
  }

  Future<void> _addManualCaption(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final session = context
        .read<ProfessionalProvider>()
        .sessions
        .where((s) => s.id == widget.sessionId)
        .firstOrNull;
    if (session == null) return;

    await context.read<ProfessionalProvider>().addCaptionToSession(
          widget.sessionId,
          Caption(
            text: value,
            speaker: 'You',
            language: session.captionLanguage,
            isOwn: true,
          ),
        );
    if (!mounted) return;
    _captionController.clear();
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _stopSession() async {
    if (_isFinalizing) return;
    final speech = context.read<SpeechProvider>();
    if (speech.isListening || _isListening) {
      await _stopListeningSegment(speech);
    }
    await _flushHiddenDraft();
    await context.read<ProfessionalProvider>().stopSession(widget.sessionId);
    if (!mounted) return;

    final action = await _showCompletionDialog();
    if (!mounted) return;

    if (action == _SessionCompletionAction.discard) {
      await context.read<ProfessionalProvider>().deleteSession(widget.sessionId);
    }
    if (mounted) Navigator.pop(context, action);
  }

  Future<_SessionCompletionAction?> _showCompletionDialog() {
    final s = AppStrings.of(context);
    return showDialog<_SessionCompletionAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.stopSession),
        content: const Text(
          'Session complete. Your transcript is saved on this device and can be reopened later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SessionCompletionAction.continueEditing,
            ),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SessionCompletionAction.discard,
            ),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SessionCompletionAction.save,
            ),
            child: const Text('Save session'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final nearLatest =
          position.maxScrollExtent - position.pixels < 180 || position.maxScrollExtent == 0;
      if (!nearLatest) return;
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String get _duration {
    final diff = DateTime.now().difference(_startTime);
    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _speechSubscription?.cancel();
    _durationTimer?.cancel();
    _captionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();
    final session = pro.sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final s = AppStrings.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This session is no longer available.')),
      );
    }

    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _duration,
                semanticsLabel: 'Session duration $_duration',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            color: theme.colorScheme.primary.withValues(alpha: .07),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_speechStatus · ${speechModeLabel(context)} · ${session.captionLanguage}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: _isListening ? 'Stop listening' : 'Start listening',
                  hint: 'Tap to toggle the microphone. Holding is not required.',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                        _isListening
                            ? 'Listening — tap to stop'
                            : _isFinalizing
                                ? 'Finalizing…'
                                : 'Tap to listen',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Listening is controlled with a tap. Your speech appears once as a finalized caption.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_startupError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _startupError!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: session.captions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _sessionStarting
                            ? 'Starting session…'
                            : _isListening
                                ? 'Listening…'
                                : 'Tap the microphone to begin listening.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    itemCount: session.captions.length,
                    itemBuilder: (_, index) {
                      final caption = session.captions[index];
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
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withValues(alpha: .3)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _captionController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: s.addCaptionManually,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.cardColor,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _addManualCaption,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Speak reply',
                    icon: const Icon(Icons.volume_up),
                    onPressed: _captionController.text.trim().isEmpty
                        ? null
                        : () => context.read<SpeechProvider>().speak(
                              _captionController.text.trim(),
                              language: session.captionLanguage,
                            ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Add caption',
                    icon: const Icon(Icons.add),
                    onPressed: () => _addManualCaption(_captionController.text),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: PrimaryActionButton(
                label: s.stopSession,
                icon: Icons.stop,
                onPressed: _stopSession,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String speechModeLabel(BuildContext context) =>
      context.read<SpeechProvider>().sttModeLabel;
}

enum _SessionCompletionAction { save, discard, continueEditing }

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
