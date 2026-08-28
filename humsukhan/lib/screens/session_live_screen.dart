import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<ProfessionalProvider>();
      pro.startSessionRecording(widget.sessionId);

      final speech = context.read<SpeechProvider>();
      speech.initialize();
      _speechSubscription = speech.onResult.listen((result) {
        if (!mounted) return;
        final pro = context.read<ProfessionalProvider>();
        if (result.isFinal) {
          pro.addCaptionToSession(
            widget.sessionId,
            Caption(
              text: result.text,
              speaker: 'Speaker 1',
              language: result.language,
              isPartial: false,
            ),
          );
          _scrollToBottom();
        } else {
          // Show partial in UI (handled via state)
        }
      });
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

  String get _duration {
    final diff = DateTime.now().difference(_startTime);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
    final session = pro.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => ProfessionalSession(title: 'Session', status: SessionStatus.inProgress),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppTheme.successLight),
                    const SizedBox(width: 6),
                    Text('$_duration', style: TextStyle(
                      color: AppTheme.successLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.successLight.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.mic, color: AppTheme.successLight, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Live Session · ${session.captionLanguage} · ${session.type.name}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.successLight,
                  ),
                ),
              ],
            ),
          ),

          // Captions
          Expanded(
            child: session.captions.isEmpty
                ? Center(
                    child: Text(
                      'Listening...\nCaptions will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: session.captions.length,
                    itemBuilder: (context, index) {
                      final caption = session.captions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${caption.speaker} · ${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(caption.text, style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Add caption input
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
                    controller: _captionController,
                    decoration: InputDecoration(
                      hintText: 'Add a caption manually...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (text) => _addManualCaption(text),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _addManualCaption(_captionController.text),
                  ),
                ),
              ],
            ),
          ),

          // Stop session button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryActionButton(
              label: 'Stop Session',
              icon: Icons.stop,
              onPressed: () async {
                context.read<SpeechProvider>().stopListening();
                await context.read<ProfessionalProvider>().stopSession(widget.sessionId);
                if (mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addManualCaption(String text) {
    if (text.trim().isEmpty) return;
    context.read<ProfessionalProvider>().addCaptionToSession(
      widget.sessionId,
      Caption(text: text.trim(), speaker: 'Speaker 1', language: 'English'),
    );
    _captionController.clear();
    _scrollToBottom();
  }
}
