import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for real-time caption synchronization.
class WebSocketClient {
  final String baseUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<WSMessage> _messageController =
      StreamController<WSMessage>.broadcast();
  final StreamController<WSConnectionState> _stateController =
      StreamController<WSConnectionState>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _heartbeatInterval = Duration(seconds: 30);

  String? _currentSessionId;
  String? _currentToken;
  WSConnectionState _state = WSConnectionState.disconnected;

  WebSocketClient({required this.baseUrl});

  Stream<WSMessage> get onMessage => _messageController.stream;
  Stream<WSConnectionState> get onConnectionState => _stateController.stream;
  Stream<WSCaption> get onCaption => onMessage.where((m) => m is WSCaption).cast<WSCaption>();
  Stream<WSUserEvent> get onUserEvent => onMessage.where((m) => m is WSUserEvent).cast<WSUserEvent>();
  Stream<WSTypingIndicator> get onTyping => onMessage.where((m) => m is WSTypingIndicator).cast<WSTypingIndicator>();
  WSConnectionState get state => _state;
  bool get isConnected => _state == WSConnectionState.connected;

  Future<void> connect({required String sessionId, required String token}) async {
    _currentSessionId = sessionId;
    _currentToken = token;
    _reconnectAttempts = 0;
    await _connect();
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    await _channel?.sink.close();
    _channel = null;
    _updateState(WSConnectionState.disconnected);
  }

  void sendCaption(String text, {String speaker = 'Speaker 1', String language = 'English', bool isPartial = false}) {
    _send({"type": "caption", "text": text, "speaker": speaker, "language": language, "is_partial": isPartial});
  }

  void sendTypingIndicator(bool isTyping) {
    _send({"type": "typing", "is_typing": isTyping});
  }

  void endSession() {
    _send({"type": "end_session"});
  }

  void ping() {
    _send({"type": "ping"});
  }

  Future<void> _connect() async {
    if (_currentSessionId == null || _currentToken == null) return;
    _updateState(WSConnectionState.connecting);
    try {
      final uri = Uri.parse('$baseUrl/ws/session/$_currentSessionId?token=$_currentToken');
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        (data) { _reconnectAttempts = 0; _handleMessage(data); },
        onError: (error) { _updateState(WSConnectionState.error); _scheduleReconnect(); },
        onDone: () { _updateState(WSConnectionState.disconnected); _scheduleReconnect(); },
      );
      _updateState(WSConnectionState.connected);
      _startHeartbeat();
    } catch (e) {
      _updateState(WSConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final type = json['type'] as String?;
      switch (type) {
        case 'caption_broadcast': _messageController.add(WSCaption.fromJson(json)); break;
        case 'user_joined': case 'user_left': _messageController.add(WSUserEvent.fromJson(json)); break;
        case 'typing_indicator': _messageController.add(WSTypingIndicator.fromJson(json)); break;
        case 'session_ended': _messageController.add(WSSessionEnded.fromJson(json)); break;
        case 'pong': _messageController.add(WSPong.fromJson(json)); break;
        case 'error': _messageController.add(WSError.fromJson(json)); break;
      }
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
    }
  }

  void _send(Map<String, dynamic> message) {
    if (_channel == null || _state != WSConnectionState.connected) return;
    try { _channel!.sink.add(jsonEncode(message)); } catch (e) { debugPrint('Send failed: $e'); }
  }

  void _updateState(WSConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) { _updateState(WSConnectionState.failed); return; }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 * (_reconnectAttempts + 1)).clamp(2, 30));
    _reconnectTimer = Timer(delay, () { _reconnectAttempts++; _connect(); });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => ping());
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _stateController.close();
  }
}

enum WSConnectionState { disconnected, connecting, connected, error, failed }

abstract class WSMessage {
  final String type;
  final String timestamp;
  const WSMessage({required this.type, required this.timestamp});
}

class WSCaption extends WSMessage {
  final String id, text, speaker, language, userId, username;
  final bool isPartial;
  const WSCaption({required this.id, required this.text, required this.speaker, required this.language,
      required this.isPartial, required this.userId, required this.username, required String timestamp})
      : super(type: 'caption_broadcast', timestamp: timestamp);
  factory WSCaption.fromJson(Map<String, dynamic> json) => WSCaption(
    id: json['id'] ?? '', text: json['text'] ?? '', speaker: json['speaker'] ?? 'Speaker',
    language: json['language'] ?? 'English', isPartial: json['is_partial'] ?? false,
    userId: json['user_id'] ?? '', username: json['username'] ?? '', timestamp: json['timestamp'] ?? '');
}

class WSUserEvent extends WSMessage {
  final String userId, username;
  final int participants;
  const WSUserEvent._({required String type, required this.userId, required this.username,
      required this.participants, required String timestamp})
      : super(type: type, timestamp: timestamp);
  factory WSUserEvent.fromJson(Map<String, dynamic> json) => WSUserEvent._(
    type: json['type'] ?? 'user_joined', userId: json['user_id'] ?? '',
    username: json['username'] ?? '', participants: json['participants'] ?? 0, timestamp: json['timestamp'] ?? '');
  bool get isJoined => type == 'user_joined';
  bool get isLeft => type == 'user_left';
}

class WSTypingIndicator extends WSMessage {
  final String userId, username;
  final bool isTyping;
  const WSTypingIndicator({required this.userId, required this.username, required this.isTyping, required String timestamp})
      : super(type: 'typing_indicator', timestamp: timestamp);
  factory WSTypingIndicator.fromJson(Map<String, dynamic> json) => WSTypingIndicator(
    userId: json['user_id'] ?? '', username: json['username'] ?? '',
    isTyping: json['is_typing'] ?? false, timestamp: json['timestamp'] ?? '');
}

class WSSessionEnded extends WSMessage {
  final String sessionId;
  const WSSessionEnded({required this.sessionId, required String timestamp})
      : super(type: 'session_ended', timestamp: timestamp);
  factory WSSessionEnded.fromJson(Map<String, dynamic> json) =>
      WSSessionEnded(sessionId: json['session_id'] ?? '', timestamp: json['timestamp'] ?? '');
}

class WSPong extends WSMessage {
  const WSPong({required String timestamp}) : super(type: 'pong', timestamp: timestamp);
  factory WSPong.fromJson(Map<String, dynamic> json) => WSPong(timestamp: json['timestamp'] ?? '');
}

class WSError extends WSMessage {
  final String message;
  const WSError({required this.message, required String timestamp})
      : super(type: 'error', timestamp: timestamp);
  factory WSError.fromJson(Map<String, dynamic> json) =>
      WSError(message: json['message'] ?? 'Unknown error', timestamp: json['timestamp'] ?? '');
}
