import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
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
  StreamSubscription? _speechSubscription;
  Timer? _durationTimer;
  late DateTime _startTime;

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
    final pro = context.read<ProfessionalProvider>();
    pro.startSessionRecording(widget.sessionId);
    final session = pro.sessions.firstWhere((s) => s.id == widget.sessionId);
    final speech = context.read<SpeechProvider>();
    await speech.initialize(preferredLanguage: session.captionLanguage);
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted || result.text.trim().isEmpty) return;
      if (result.isFinal) {
        pro.addCaptionToSession(widget.sessionId, Caption(text: result.text.trim(), speaker: 'Speaker 1', language: result.language));
      }
      setState(() {});
      _scrollToBottom();
    });
    await speech.startListening(language: session.captionLanguage == 'Roman Urdu' ? 'Urdu' : session.captionLanguage);
    if (!speech.isLiveStt && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live speech recognition is unavailable. Check microphone access or download the required speech model.')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
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
    final session = pro.sessions.cast<ProfessionalSession?>().firstWhere((s) => s?.id == widget.sessionId, orElse: () => null);
    final s = AppStrings.of(context);
    if (session == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Session not found')));
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(_duration, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700))))],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.primary.withValues(alpha: .08),
          child: Row(children: [
            Icon(Icons.mic, color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${s.liveSession} · ${session.captionLanguage} · ${session.type.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary))),
          ]),
        ),
        Expanded(
          child: session.captions.isEmpty
              ? Center(child: Text(s.listeningDots, style: theme.textTheme.bodyLarge))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: session.captions.length,
                  itemBuilder: (_, index) => SpeakableCaptionBubble(caption: session.captions[index], textSize: context.watch<SettingsProvider>().captionTextSize, isHighContrast: context.watch<SettingsProvider>().isHighContrast),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: .3)))),
          child: Row(children: [
            Expanded(child: TextField(controller: _captionController, decoration: InputDecoration(hintText: s.addCaptionManually, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusFull), borderSide: BorderSide.none), filled: true, fillColor: theme.cardColor), onSubmitted: _addManualCaption)),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Speak reply', icon: const Icon(Icons.volume_up), onPressed: _captionController.text.trim().isEmpty ? null : () => context.read<SpeechProvider>().speak(_captionController.text.trim(), language: session.captionLanguage)),
            const SizedBox(width: 4),
            IconButton.filled(tooltip: 'Add caption', icon: const Icon(Icons.add), onPressed: () => _addManualCaption(_captionController.text)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: PrimaryActionButton(label: s.stopSession, icon: Icons.stop, onPressed: _stopSession)),
      ]),
    );
  }

  void _addManualCaption(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    final session = context.read<ProfessionalProvider>().sessions.firstWhere((s) => s.id == widget.sessionId);
    context.read<ProfessionalProvider>().addCaptionToSession(widget.sessionId, Caption(text: value, speaker: 'You', language: session.captionLanguage, isOwn: true));
    _captionController.clear();
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _stopSession() async {
    await context.read<SpeechProvider>().stopListening();
    await context.read<ProfessionalProvider>().stopSession(widget.sessionId);
    if (mounted) Navigator.pop(context);
  }
}
