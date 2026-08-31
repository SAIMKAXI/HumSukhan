import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/stt/enhanced_stt.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';
import '../l10n/app_strings.dart';

class SessionLiveScreen extends StatefulWidget {
  final String sessionId;
  const SessionLiveScreen({super.key, required this.sessionId});

  @override
  State<SessionLiveScreen> createState() => _SessionLiveScreenState();
}

class _SessionLiveScreenState extends State<SessionLiveScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<SpeechResultEvent>? _speechSubscription;
  Timer? _durationTimer;
  late DateTime _startTime;
  Caption? _livePartial;
  String _lastFinalText = '';
  DateTime? _lastFinalAt;
  bool _sessionStarting = true;
  String _speechStatus = 'Starting microphone…';
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  Future<void> _initSession() async {
    if (!mounted) return;
    final pro = context.read<ProfessionalProvider>();
    final existing = pro.sessions.where((s) => s.id == widget.sessionId);
    if (existing.isEmpty) {
      setState(() {
        _sessionStarting = false;
        _startupError = 'Session not found.';
      });
      return;
    }

    final session = existing.first;
    await pro.startSessionRecording(widget.sessionId);

    final speech = context.read<SpeechProvider>();
    await speech.initialize(preferredLanguage: session.captionLanguage);

    await _speechSubscription?.cancel();
    _speechSubscription = speech.onResult.listen(_handleSpeechResult);

    setState(() {
      _speechStatus = 'Listening for speech…';
      _startupError = null;
    });

    await speech.startListening(
      language: session.captionLanguage == 'Roman Urdu'
          ? 'Urdu'
          : session.captionLanguage,
    );

    if (!mounted) return;
    final listening = speech.isListening;
    setState(() {
      _sessionStarting = false;
      _speechStatus = listening
          ? 'Listening for speech…'
          : 'Microphone could not be started';
      if (!listening) {
        _startupError =
            'Speech recognition could not start. Check microphone permission or download the required speech model.';
      }
    });
  }

  void _handleSpeechResult(SpeechResultEvent result) {
    if (!mounted) return;
    final text = result.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (result.isFinal) {
      if (_lastFinalText == text &&
          _lastFinalAt != null &&
          now.difference(_lastFinalAt!) < const Duration(seconds: 2)) {
        return;
      }

      final partial = _livePartial;
      final caption = Caption(
        id: partial?.id,
        text: text,
        speaker: 'Speaker 1',
        timestamp: partial?.timestamp ?? now,
        language: result.language,
        isPartial: false,
      );
      _livePartial = null;
      _lastFinalText = text;
      _lastFinalAt = now;

      final pro = context.read<ProfessionalProvider>();
      unawaited(pro.addCaptionToSession(widget.sessionId, caption));
      setState(() {});
    } else {
      final existing = _livePartial;
      _livePartial = Caption(
        id: existing?.id,
        text: text,
        speaker: 'Speaker 1',
        timestamp: existing?.timestamp ?? now,
        language: result.language,
        isPartial: true,
      );
      _speechStatus = 'Listening…';
      setState(() {});
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
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
    final session = pro.sessions.cast<ProfessionalSession?>().firstWhere(
          (s) => s?.id == widget.sessionId,
          orElse: () => null,
        );
    final s = AppStrings.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Session not found')),
      );
    }

    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final captionsWithPartial = <Caption>[
      ...session.captions,
      if (_livePartial != null) _livePartial!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _duration,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.primary.withValues(alpha: .08),
            child: Row(
              children: [
                Icon(
                  _sessionStarting || _livePartial != null
                      ? Icons.mic
                      : Icons.mic_none,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_speechStatus} · ${session.captionLanguage} · ${session.type.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
            child: captionsWithPartial.isEmpty
                ? Center(
                    child: Text(
                      _sessionStarting ? 'Starting session…' : s.listeningDots,
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: captionsWithPartial.length,
                    itemBuilder: (_, index) {
                      final caption = captionsWithPartial[index];
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: theme.dividerColor.withValues(alpha: .3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _captionController,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryActionButton(
              label: s.stopSession,
              icon: Icons.stop,
              onPressed: _stopSession,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualCaption(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final session = context
        .read<ProfessionalProvider>()
        .sessions
        .firstWhere((s) => s.id == widget.sessionId);
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
    await context.read<SpeechProvider>().stopListening();
    await _speechSubscription?.cancel();
    _speechSubscription = null;
    if (_livePartial != null) {
      final partial = _livePartial!;
      _livePartial = null;
      await context.read<ProfessionalProvider>().addCaptionToSession(
            widget.sessionId,
            partial.copyWith(isPartial: false),
          );
    }
    await context.read<ProfessionalProvider>().stopSession(widget.sessionId);
    if (mounted) Navigator.pop(context);
  }
}
