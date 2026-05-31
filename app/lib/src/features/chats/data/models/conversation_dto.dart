/// Mirrors [backend/internal/modules/chat/entity.go] `PinnedMessage` JSON.
class PinnedMessageDto {
  const PinnedMessageDto({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.pinnedBy,
    required this.pinnedAt,
    required this.messageBody,
    this.senderId,
  });

  final String id;
  final String conversationId;
  final String messageId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final String messageBody;
  final String? senderId;

  factory PinnedMessageDto.fromJson(Map<String, dynamic> json) {
    return PinnedMessageDto(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      pinnedBy: json['pinned_by'] as String? ?? '',
      pinnedAt: _parseDate(json['pinned_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messageBody: json['message_body'] as String? ?? '',
      senderId: json['sender_id'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

/// Mirrors [backend/internal/modules/chat/entity.go] `Conversation` JSON.
class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.kind,
    this.taskId,
    this.lastMessageId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageSenderId,
    required this.unreadCount,
    this.otherUserId,
    this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.otherReputationScore,
    this.otherRankTier,
    this.lastReadAt,
    this.otherParticipantReadAt,
    this.pinnedCount = 0,
    this.pinnedMessages = const <PinnedMessageDto>[],
    this.isMuted = false,
    this.isPinned = false,
    this.isRequest = false,
    this.requestStatus = '',
    this.clearedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String kind;
  final String? taskId;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final int unreadCount;
  final String? otherUserId;
  final String? otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;
  final int? otherReputationScore;
  final String? otherRankTier;
  final DateTime? lastReadAt;
  final DateTime? otherParticipantReadAt;
  final int pinnedCount;
  final List<PinnedMessageDto> pinnedMessages;
  final bool isMuted;
  final bool isPinned;
  final bool isRequest;
  final String requestStatus;
  final DateTime? clearedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    final rawPins = json['pinned_messages'];
    final pins = rawPins is List<dynamic>
        ? rawPins
            .map((e) => PinnedMessageDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <PinnedMessageDto>[];

    return ConversationDto(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      taskId: json['task_id'] as String?,
      lastMessageId: json['last_message_id'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageType: json['last_message_type'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      otherUserId: json['other_user_id'] as String?,
      otherUsername: json['other_username'] as String?,
      otherDisplayName: json['other_display_name'] as String?,
      otherAvatarUrl: json['other_avatar_url'] as String?,
      otherReputationScore: (json['other_reputation_score'] as num?)?.toInt(),
      otherRankTier: json['other_rank_tier'] as String?,
      lastReadAt: _parseDate(json['last_read_at']),
      otherParticipantReadAt: _parseDate(json['other_participant_read_at']),
      pinnedCount: (json['pinned_count'] as num?)?.toInt() ?? 0,
      pinnedMessages: pins,
      isMuted: json['is_muted'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isRequest: _parseRequestFlag(json),
      requestStatus:
          (json['request_status'] ?? json['conversation_status'] ?? '')
              .toString(),
      clearedAt: _parseDate(json['cleared_at']),
      createdAt: _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _parseDate(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static bool _parseRequestFlag(Map<String, dynamic> json) {
    final explicit = json['is_request'] ?? json['is_chat_request'];
    if (explicit is bool) return explicit;

    final status = (json['request_status'] ?? json['conversation_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return status == 'pending' || status == 'requested' || status == 'request';
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

class ListConversationsResponseDto {
  const ListConversationsResponseDto({
    required this.items,
    this.nextCursor = '',
  });

  final List<ConversationDto> items;
  final String nextCursor;

  factory ListConversationsResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List<dynamic>
        ? raw
            .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <ConversationDto>[];
    return ListConversationsResponseDto(
      items: list,
      nextCursor: json['next_cursor'] as String? ?? '',
    );
  }
}

/// Ответ `GET /chats/conversations/{id}/pinned-messages`.
class ListPinnedMessagesResponseDto {
  const ListPinnedMessagesResponseDto({required this.items});

  final List<PinnedMessageDto> items;

  factory ListPinnedMessagesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List<dynamic>
        ? raw
            .map((e) => PinnedMessageDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <PinnedMessageDto>[];
    return ListPinnedMessagesResponseDto(items: list);
  }
}
