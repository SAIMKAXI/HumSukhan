import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/websocket_client.dart';

class WebSocketProvider extends ChangeNotifier {
  late WebSocketClient _client;
  String? _currentSessionId;
  WSConnectionState _connectionState = WSConnectionState.disconnected;
  List<WSUserEvent> _userEvents = [];
  int _participantCount = 0;
  List<WSCaption> _liveCaptions = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;

  Function(WSCaption)? onCaptionReceived;
  Function(String)? onSessionEnded;

  WebSocketProvider({String baseUrl = 'ws://localhost:8000'}) {
    _client = WebSocketClient(baseUrl: baseUrl);
    _setupListeners();
  }

  WebSocketClient get client => _client;
  WSConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == WSConnectionState.connected;
  bool get isConnecting => _connectionState == WSConnectionState.connecting;
  String? get currentSessionId => _currentSessionId;
  int get participantCount => _participantCount;
  List<WSUserEvent> get userEvents => List.unmodifiable(_userEvents);
  List<WSCaption> get liveCaptions => List.unmodifiable(_liveCaptions);

  void _setupListeners() {
    _stateSubscription = _client.onConnectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _messageSubscription = _client.onMessage.listen((message) {
      if (message is WSCaption) {
        _liveCaptions.add(message);
        if (_liveCaptions.length > 100) _liveCaptions = _liveCaptions.sublist(_liveCaptions.length - 100);
        onCaptionReceived?.call(message);
        notifyListeners();
      } else if (message is WSUserEvent) {
        _userEvents.add(message);
        _participantCount = message.participants;
        notifyListeners();
      } else if (message is WSSessionEnded) {
        onSessionEnded?.call(message.sessionId);
        notifyListeners();
      }
    });
  }

  Future<void> connectToSession({required String sessionId, required String token}) async {
    _currentSessionId = sessionId;
    _liveCaptions.clear();
    _userEvents.clear();
    _participantCount = 0;
    await _client.connect(sessionId: sessionId, token: token);
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _currentSessionId = null;
    _liveCaptions.clear();
    _userEvents.clear();
    _participantCount = 0;
    notifyListeners();
  }

  void sendCaption(String text, {String speaker = 'Speaker 1', String language = 'English', bool isPartial = false}) {
    _client.sendCaption(text, speaker: speaker, language: language, isPartial: isPartial);
  }

  void sendTypingIndicator(bool isTyping) {
    _client.sendTypingIndicator(isTyping);
  }

  void endSession() {
    _client.endSession();
  }

  void clearLiveCaptions() {
    _liveCaptions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _client.dispose();
    super.dispose();
  }
}
