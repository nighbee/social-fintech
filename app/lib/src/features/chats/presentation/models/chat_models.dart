import 'package:flutter/foundation.dart';

enum ChatMessageDirection {
  incoming,
  outgoing,
}

/// Галочки для исходящих: «доставлено» и «прочитано».
enum ChatOutgoingReceipt {
  none,
  delivered,
  read,
}

@immutable
class ChatThreadPreview {
  const ChatThreadPreview({
    required this.id,
    required this.displayName,
    required this.rankLine,
    required this.lastSeenLabel,
    required this.timeLabel,
    required this.avatarUrl,
    this.previewText = '',
    this.unreadCount = 0,
    this.isRequest = false,
    this.otherUserId,
    this.pinnedMessagePreview,
    this.pinnedMessageId,
  });

  final String id;
  final String displayName;
  final String rankLine;
  final String lastSeenLabel;
  final String timeLabel;
  final String avatarUrl;
  final String previewText;
  final int unreadCount;
  final bool isRequest;

  /// Собеседник (`GET /profiles/{id}`).
  final String? otherUserId;

  /// Текст закреплённого сообщения для баннера под шапкой.
  final String? pinnedMessagePreview;
  final String? pinnedMessageId;

  ChatThreadPreview copyWith({
    String? id,
    String? displayName,
    String? rankLine,
    String? lastSeenLabel,
    String? timeLabel,
    String? avatarUrl,
    String? previewText,
    int? unreadCount,
    bool? isRequest,
    String? otherUserId,
    String? pinnedMessagePreview,
    String? pinnedMessageId,
  }) {
    return ChatThreadPreview(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      rankLine: rankLine ?? this.rankLine,
      lastSeenLabel: lastSeenLabel ?? this.lastSeenLabel,
      timeLabel: timeLabel ?? this.timeLabel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      previewText: previewText ?? this.previewText,
      unreadCount: unreadCount ?? this.unreadCount,
      isRequest: isRequest ?? this.isRequest,
      otherUserId: otherUserId ?? this.otherUserId,
      pinnedMessagePreview:
          pinnedMessagePreview ?? this.pinnedMessagePreview,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
    );
  }
}

@immutable
class ChatForwardedSnippet {
  const ChatForwardedSnippet({
    required this.senderName,
    required this.senderAvatarUrl,
  });

  final String senderName;
  final String senderAvatarUrl;
}

@immutable
class ChatMessageMediaItem {
  const ChatMessageMediaItem({
    required this.type,
    required this.url,
    this.thumbnailUrl,
  });

  final String type;
  final String url;
  final String? thumbnailUrl;

  bool get isImage {
    final t = type.trim().toLowerCase();
    return t == 'image' || t.startsWith('image/');
  }

  bool get isVideo {
    final t = type.trim().toLowerCase();
    return t == 'video' || t.startsWith('video/');
  }

  bool get isAudio {
    final t = type.trim().toLowerCase();
    return t == 'audio' || t.startsWith('audio/');
  }
}

@immutable
class ChatMessageUiModel {
  const ChatMessageUiModel({
    required this.id,
    required this.direction,
    required this.text,
    required this.timeLabel,
    required this.createdAt,
    this.messageType = 'user',
    this.media = const <ChatMessageMediaItem>[],
    this.forwardedSnippet,
    this.outgoingReceipt = ChatOutgoingReceipt.none,
  });

  final String id;
  final ChatMessageDirection direction;
  final String text;
  final String timeLabel;
  final DateTime createdAt;
  final String messageType;
  final List<ChatMessageMediaItem> media;
  final ChatForwardedSnippet? forwardedSnippet;
  final ChatOutgoingReceipt outgoingReceipt;
}
