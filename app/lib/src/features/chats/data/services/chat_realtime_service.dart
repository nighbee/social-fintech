import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/config/environment_manager.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/secure_storage/secure_storage_service_impl.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';

class ChatRealtimeEvent {
  const ChatRealtimeEvent({
    required this.type,
    this.conversationId,
    this.message,
    this.messageId,
    this.readByUserId,
    this.readAt,
    this.requestStatus,
  });

  factory ChatRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final messageJson = json['message'];
    return ChatRealtimeEvent(
      type: (json['type'] as String? ?? '').trim(),
      conversationId: (json['conversation_id'] as String?)?.trim(),
      message: messageJson is Map<String, dynamic>
          ? MessageDto.fromJson(messageJson)
          : null,
      messageId: (json['message_id'] as String?)?.trim(),
      readByUserId: (json['read_by_user_id'] as String?)?.trim(),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      requestStatus: (json['request_status'] as String?)?.trim(),
    );
  }

  final String type;
  final String? conversationId;
  final MessageDto? message;
  final String? messageId;
  final String? readByUserId;
  final DateTime? readAt;
  final String? requestStatus;
}

class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  final _events = StreamController<ChatRealtimeEvent>.broadcast(
    onListen: () => instance._onListen(),
    onCancel: () => instance._onCancel(),
  );
  final _storage = SecureStorageServiceImpl();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _closedByClient = false;
  int _listenerCount = 0;
  int _reconnectAttempt = 0;

  Stream<ChatRealtimeEvent> get events => _events.stream;

  Future<void> connect() async {
    if (_connecting || _socket != null) {
      return;
    }
    _closedByClient = false;
    _connecting = true;
    _reconnectTimer?.cancel();

    try {
      final token = (await _storage.getAccessToken())?.trim();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      final socket = await WebSocket.connect(
        _webSocketUri(token).toString(),
        headers: <String, dynamic>{'Authorization': 'Bearer $token'},
      );
      _socket = socket;
      _reconnectAttempt = 0;
      _socketSubscription = socket.listen(
        _handleFrame,
        onError: (_) => _handleClosed(),
        onDone: _handleClosed,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    _closedByClient = true;
    _reconnectTimer?.cancel();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
  }

  void markRead({
    required String conversationId,
    String? lastReadMessageId,
  }) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    socket.add(
      jsonEncode(<String, dynamic>{
        'type': 'mark_read',
        'conversation_id': conversationId,
        if ((lastReadMessageId ?? '').trim().isNotEmpty)
          'last_read_message_id': lastReadMessageId!.trim(),
      }),
    );
  }

  void _onListen() {
    _listenerCount += 1;
    unawaited(connect());
  }

  void _onCancel() {
    _listenerCount = _listenerCount > 0 ? _listenerCount - 1 : 0;
    if (_listenerCount == 0) {
      unawaited(disconnect());
    }
  }

  void _handleFrame(dynamic frame) {
    if (frame is! String || frame.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(frame);
      if (decoded is Map<String, dynamic>) {
        _events.add(ChatRealtimeEvent.fromJson(decoded));
      }
    } catch (_) {
      // Ignore malformed frames; the socket itself remains usable.
    }
  }

  void _handleClosed() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByClient || _listenerCount == 0) {
      return;
    }
    _reconnectTimer?.cancel();
    final seconds = switch (_reconnectAttempt) {
      0 => 1,
      1 => 2,
      2 => 4,
      _ => 8,
    };
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_closedByClient && _listenerCount > 0) {
        unawaited(connect());
      }
    });
  }

  Uri _webSocketUri(String token) {
    final base = Uri.parse(getIt<EnvironmentManager>().baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final path = _joinPaths(base.path, EndPoints.chatsWs);
    return base.replace(
      scheme: scheme,
      path: path,
      queryParameters: <String, String>{'token': token},
    );
  }

  String _joinPaths(String left, String right) {
    final normalizedLeft =
        left.endsWith('/') ? left.substring(0, left.length - 1) : left;
    final normalizedRight = right.startsWith('/') ? right : '/$right';
    return '$normalizedLeft$normalizedRight';
  }
}
