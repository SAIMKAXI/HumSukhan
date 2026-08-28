import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api/websocket_client.dart';
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
  StreamSubscription? _wsCaptionSubscription;
  StreamSubscription? _wsStateSubscription;
  Timer? _durationTimer;
  late DateTime _startTime;
  bool _useWebSocket = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  void _initSession() {
    context.read<ProfessionalProvider>().startSessionRecording(widget.sessionId);
    final speech = context.read<SpeechProvider>();
    speech.initialize();
    _speechSubscription = speech.onResult.listen((result) {
      if (!mounted) return;
      if (result.isFinal) {
        context.read<ProfessionalProvider>().addCaptionToSession(
          widget.sessionId,
          Caption(text: result.text, speaker: 'Speaker 1', language: result.language),
        );
        if (_useWebSocket) {
          context.read<WebSocketProvider>().sendCaption(result.text, speaker: 'Speaker 1', language: result.language);
        }
        _scrollToBottom();
      }
    });
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    final wsProvider = context.read<WebSocketProvider>();
    _wsCaptionSubscription = wsProvider.client.onCaption.listen((caption) {
      if (!mounted || caption.userId.isEmpty) return;
      context.read<ProfessionalProvider>().addCaptionToSession(
        widget.sessionId,
        Caption(text: caption.text, speaker: caption.speaker, language: caption.language),
      );
      _scrollToBottom();
    });
    _wsStateSubscription = wsProvider.client.onConnectionState.listen((state) {
      if (mounted) setState(() => _useWebSocket = state == WSConnectionState.connected);
    });
    try {
      await wsProvider.connectToSession(sessionId: widget.sessionId, token: 'demo-token');
    } catch (e) { debugPrint('WebSocket failed (local mode): $e'); }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
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
    _wsCaptionSubscription?.cancel();
    _wsStateSubscription?.cancel();
    _durationTimer?.cancel();
    _captionController.dispose();
    _scrollController.dispose();
    context.read<WebSocketProvider>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();
    final ws = context.watch<WebSocketProvider>();
    final session = pro.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => ProfessionalSession(title: 'Session', status: SessionStatus.inProgress),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _connColor(ws.connectionState).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_connIcon(ws.connectionState), size: 12, color: _connColor(ws.connectionState)),
                  const SizedBox(width: 4),
                  Text(_connLabel(ws.connectionState), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: _connColor(ws.connectionState),
                  )),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: AppTheme.successLight),
                  const SizedBox(width: 6),
                  Text(_duration, style: TextStyle(color: AppTheme.successLight, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.successLight.withValues(alpha: 0.1),
          child: Row(children: [
            Icon(Icons.mic, color: AppTheme.successLight, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Live Session · ${session.captionLanguage} · ${session.type.name}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.successLight))),
            if (ws.isConnected && ws.participantCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people, size: 12, color: AppTheme.primaryLight),
                  const SizedBox(width: 4),
                  Text('${ws.participantCount}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
                ]),
              ),
          ]),
        ),
        if (ws.userEvents.isNotEmpty)
          Container(
            height: 32, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(scrollDirection: Axis.horizontal,
              children: ws.userEvents.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(child: Text(e.isJoined ? '${e.username} joined' : '${e.username} left',
                    style: TextStyle(fontSize: 11, color: e.isJoined ? AppTheme.successLight : Colors.grey, fontStyle: FontStyle.italic))),
              )).toList()),
          ),
        Expanded(
          child: session.captions.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 16),
                  Text('Listening...\nCaptions will appear here.', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                ]))
              : ListView.builder(
                  controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: session.captions.length,
                  itemBuilder: (context, index) {
                    final c = session.captions[index];
                    return Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.speaker} · ${c.timestamp.hour.toString().padLeft(2, '0')}:${c.timestamp.minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(c.text, style: Theme.of(context).textTheme.bodyLarge),
                      ]));
                  }),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
          child: Row(children: [
            Expanded(child: TextField(controller: _captionController,
                decoration: InputDecoration(hintText: 'Add a caption manually...', hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull), borderSide: BorderSide.none),
                    filled: true, fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onSubmitted: _addManualCaption)),
            const SizedBox(width: 8),
            Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => _addManualCaption(_captionController.text))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryActionButton(label: 'Stop Session', icon: Icons.stop, onPressed: () async {
            context.read<SpeechProvider>().stopListening();
            if (_useWebSocket) context.read<WebSocketProvider>().endSession();
            await context.read<ProfessionalProvider>().stopSession(widget.sessionId);
            if (mounted) Navigator.pop(context);
          }),
        ),
      ]),
    );
  }

  void _addManualCaption(String text) {
    if (text.trim().isEmpty) return;
    context.read<ProfessionalProvider>().addCaptionToSession(widget.sessionId,
        Caption(text: text.trim(), speaker: 'Speaker 1', language: 'English'));
    if (_useWebSocket) context.read<WebSocketProvider>().sendCaption(text.trim());
    _captionController.clear();
    _scrollToBottom();
  }

  Color _connColor(WSConnectionState s) => switch (s) {
    WSConnectionState.connected => AppTheme.successLight,
    WSConnectionState.connecting => AppTheme.warningLight,
    _ => Colors.grey,
  };

  IconData _connIcon(WSConnectionState s) => switch (s) {
    WSConnectionState.connected => Icons.wifi,
    WSConnectionState.connecting => Icons.sync,
    _ => Icons.wifi_off,
  };

  String _connLabel(WSConnectionState s) => switch (s) {
    WSConnectionState.connected => 'SYNCED',
    WSConnectionState.connecting => 'CONNECTING',
    WSConnectionState.error => 'ERROR',
    WSConnectionState.failed => 'FAILED',
    WSConnectionState.disconnected => 'LOCAL',
  };
}
