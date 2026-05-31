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

class ReplyToMessageDto {
  const ReplyToMessageDto({
    required this.id,
    required this.body,
    this.senderId,
    this.senderName,
  });

  final String id;
  final String body;
  final String? senderId;
  final String? senderName;

  factory ReplyToMessageDto.fromJson(Map<String, dynamic> json) {
    return ReplyToMessageDto(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderId: _trimmedOrNull(json['sender_id']),
      senderName: _trimmedOrNull(json['sender_name']),
    );
  }
}

class ForwardedFromUserDto {
  const ForwardedFromUserDto({
    required this.id,
    this.username,
    this.displayName,
  });

  final String id;
  final String? username;
  final String? displayName;

  factory ForwardedFromUserDto.fromJson(Map<String, dynamic> json) {
    return ForwardedFromUserDto(
      id: json['id'] as String? ?? '',
      username: _trimmedOrNull(json['username']),
      displayName: _trimmedOrNull(json['display_name']),
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
    this.replyToMessage,
    this.forwardedFromUserId,
    this.forwardedFromUser,
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
  final ReplyToMessageDto? replyToMessage;
  final String? forwardedFromUserId;
  final ForwardedFromUserDto? forwardedFromUser;
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

    final senderTrimmed = _trimmedOrNull(json['sender_id'] ?? json['senderId']);
    final replyTrimmed = _trimmedOrNull(json['reply_to_message_id']);
    final fwdTrimmed = _trimmedOrNull(json['forwarded_from_user_id']);
    final delByTrimmed = _trimmedOrNull(json['deleted_by_user_id']);
    final replyPayload = json['reply_to_message'];
    final forwardedPayload = json['forwarded_from_user'];

    return MessageDto(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: senderTrimmed,
      messageType: json['message_type'] as String? ?? '',
      body: json['body'] as String? ?? '',
      media: mediaList,
      replyToMessageId: replyTrimmed,
      replyToMessage: replyPayload is Map<String, dynamic>
          ? ReplyToMessageDto.fromJson(replyPayload)
          : null,
      forwardedFromUserId: fwdTrimmed,
      forwardedFromUser: forwardedPayload is Map<String, dynamic>
          ? ForwardedFromUserDto.fromJson(forwardedPayload)
          : null,
      deletedAt: _parseDate(json['deleted_at']),
      deletedByUserId: delByTrimmed,
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

String? _trimmedOrNull(Object? value) {
  final text = (value is String ? value : value?.toString())?.trim() ?? '';
  return text.isEmpty ? null : text;
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
