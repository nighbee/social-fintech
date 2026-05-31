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
    this.isMuted = false,
    this.isPinned = false,
    this.requestStatus = '',
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
  final bool isMuted;
  final bool isPinned;
  final String requestStatus;

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
    bool? isMuted,
    bool? isPinned,
    String? requestStatus,
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
      pinnedMessagePreview: pinnedMessagePreview ?? this.pinnedMessagePreview,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }
}

@immutable
class ChatForwardedSnippet {
  const ChatForwardedSnippet({
    required this.senderName,
    required this.senderAvatarUrl,
    this.senderId,
    this.username,
  });

  final String senderName;
  final String senderAvatarUrl;
  final String? senderId;
  final String? username;
}

@immutable
class ChatReplyPreview {
  const ChatReplyPreview({
    required this.authorLabel,
    required this.excerpt,
  });

  final String authorLabel;
  final String excerpt;
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
    this.replyPreview,
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
  final ChatReplyPreview? replyPreview;
  final ChatForwardedSnippet? forwardedSnippet;
  final ChatOutgoingReceipt outgoingReceipt;

  ChatMessageUiModel copyWith({
    String? id,
    ChatMessageDirection? direction,
    String? text,
    String? timeLabel,
    DateTime? createdAt,
    String? messageType,
    List<ChatMessageMediaItem>? media,
    ChatReplyPreview? replyPreview,
    ChatForwardedSnippet? forwardedSnippet,
    ChatOutgoingReceipt? outgoingReceipt,
  }) {
    return ChatMessageUiModel(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      text: text ?? this.text,
      timeLabel: timeLabel ?? this.timeLabel,
      createdAt: createdAt ?? this.createdAt,
      messageType: messageType ?? this.messageType,
      media: media ?? this.media,
      replyPreview: replyPreview ?? this.replyPreview,
      forwardedSnippet: forwardedSnippet ?? this.forwardedSnippet,
      outgoingReceipt: outgoingReceipt ?? this.outgoingReceipt,
    );
  }
}
