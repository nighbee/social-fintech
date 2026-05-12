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
    this.lastReadAt,
    this.otherParticipantReadAt,
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
  final DateTime? lastReadAt;
  final DateTime? otherParticipantReadAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
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
      lastReadAt: _parseDate(json['last_read_at']),
      otherParticipantReadAt: _parseDate(json['other_participant_read_at']),
      createdAt: _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _parseDate(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
