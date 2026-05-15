/// Mirrors [backend/internal/modules/chat/entity.go] `Message` / `MessageMedia` JSON.
class MessageMediaDto {
  const MessageMediaDto({
    required this.type,
    required this.url,
    this.thumbnailUrl,
  });

  final String type;
  final String url;
  final String? thumbnailUrl;

  factory MessageMediaDto.fromJson(Map<String, dynamic> json) {
    return MessageMediaDto(
      type: json['type'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class MessageDto {
  const MessageDto({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.messageType,
    required this.body,
    required this.media,
    this.replyToMessageId,
    this.forwardedFromUserId,
    this.deletedAt,
    this.deletedByUserId,
    required this.createdAt,
    required this.viewerMessageRead,
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String messageType;
  final String body;
  final List<MessageMediaDto> media;
  final String? replyToMessageId;
  final String? forwardedFromUserId;
  final DateTime? deletedAt;
  final String? deletedByUserId;
  final DateTime createdAt;
  final bool viewerMessageRead;

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    final mediaList = rawMedia is List<dynamic>
        ? rawMedia
            .map((e) => MessageMediaDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <MessageMediaDto>[];

    final senderRaw = json['sender_id'] ?? json['senderId'];
    final senderTrimmed =
        (senderRaw is String ? senderRaw : senderRaw?.toString())?.trim() ?? '';

    final replyRaw = json['reply_to_message_id'];
    final replyTrimmed =
        (replyRaw is String ? replyRaw : replyRaw?.toString())?.trim() ?? '';
    final fwdRaw = json['forwarded_from_user_id'];
    final fwdTrimmed =
        (fwdRaw is String ? fwdRaw : fwdRaw?.toString())?.trim() ?? '';
    final delByRaw = json['deleted_by_user_id'];
    final delByTrimmed =
        (delByRaw is String ? delByRaw : delByRaw?.toString())?.trim() ?? '';

    return MessageDto(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: senderTrimmed.isEmpty ? null : senderTrimmed,
      messageType: json['message_type'] as String? ?? '',
      body: json['body'] as String? ?? '',
      media: mediaList,
      replyToMessageId: replyTrimmed.isEmpty ? null : replyTrimmed,
      forwardedFromUserId: fwdTrimmed.isEmpty ? null : fwdTrimmed,
      deletedAt: _parseDate(json['deleted_at']),
      deletedByUserId: delByTrimmed.isEmpty ? null : delByTrimmed,
      createdAt: _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      viewerMessageRead: json['viewer_message_read'] as bool? ?? false,
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

class ListMessagesResponseDto {
  const ListMessagesResponseDto({
    required this.items,
    this.nextCursor = '',
  });

  final List<MessageDto> items;
  final String nextCursor;

  factory ListMessagesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List<dynamic>
        ? raw
            .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <MessageDto>[];
    return ListMessagesResponseDto(
      items: list,
      nextCursor: json['next_cursor'] as String? ?? '',
    );
  }
}
