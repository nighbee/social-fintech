import 'package:flutter/foundation.dart';

enum ChatMessageDirection {
  incoming,
  outgoing,
}

/// Галочки для исходящих: «доставлено» (серые двойные) и «прочитано» (синие двойные).
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

  /// Собеседник (для подгрузки ранга через `GET /profiles/{id}`).
  final String? otherUserId;

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

  /// `user` | `system` (как в API).
  final String messageType;
  final List<ChatMessageMediaItem> media;
  final ChatForwardedSnippet? forwardedSnippet;
  final ChatOutgoingReceipt outgoingReceipt;
}

class ChatMockStore {
  static const String requestThreadId = 'ayaulym-request';
  static const String primaryThreadId = 'merey-thread';
  static const String secondaryThreadId = 'aida-thread';

  static final List<ChatThreadPreview> requestThreads = <ChatThreadPreview>[
    ChatThreadPreview(
      id: requestThreadId,
      displayName: 'Ayaulym Yesmoldayeva',
      rankLine: 'Moonstone · Intention · A',
      lastSeenLabel: 'last seen 12 minutes ago',
      timeLabel: '22:11',
      unreadCount: 1,
      isRequest: true,
      avatarUrl: 'https://i.pravatar.cc/96?img=12',
    ),
  ];

  static final List<ChatThreadPreview> recentThreads = <ChatThreadPreview>[
    ChatThreadPreview(
      id: primaryThreadId,
      displayName: 'Merey Zhumagul',
      rankLine: 'Moonstone · Intention · A',
      lastSeenLabel: 'last seen 7 minutes ago',
      timeLabel: '11:22',
      previewText: 'Hello! How r u',
      unreadCount: 1,
      avatarUrl: 'https://i.pravatar.cc/96?img=21',
    ),
    ChatThreadPreview(
      id: secondaryThreadId,
      displayName: 'Aida Nurkhan',
      rankLine: 'Moonstone · Intention · A',
      lastSeenLabel: 'last seen 2 hours ago',
      timeLabel: 'Yesterday',
      previewText: 'See you tomorrow',
      avatarUrl: 'https://i.pravatar.cc/96?img=25',
    ),
  ];

  static List<ChatThreadPreview> get allThreads => <ChatThreadPreview>[
        ...requestThreads,
        ...recentThreads,
      ];

  static ChatThreadPreview threadById(String id) {
    return allThreads.firstWhere(
      (thread) => thread.id == id,
      orElse: () => recentThreads.first,
    );
  }

  static List<ChatMessageUiModel> baseMessages(String threadId) {
    final thread = threadById(threadId);
    final created = DateTime(2024, 4, 29, 11, 22);
    return <ChatMessageUiModel>[
      ChatMessageUiModel(
        id: '${thread.id}-incoming-1',
        direction: ChatMessageDirection.incoming,
        text: 'Hello! How r u',
        timeLabel: '11:22',
        createdAt: created,
        outgoingReceipt: ChatOutgoingReceipt.none,
      ),
    ];
  }

  static List<ChatMessageUiModel> forwardedMessages(String threadId) {
    final thread = threadById(threadId);
    final t1 = DateTime(2024, 4, 29, 11, 25);
    final t2 = DateTime(2024, 4, 29, 11, 26);
    return <ChatMessageUiModel>[
      ...baseMessages(threadId),
      ChatMessageUiModel(
        id: '${thread.id}-forwarded-1',
        direction: ChatMessageDirection.outgoing,
        text: 'Hello! How r u',
        timeLabel: '11:26',
        createdAt: t2,
        outgoingReceipt: ChatOutgoingReceipt.read,
        forwardedSnippet: ChatForwardedSnippet(
          senderName: thread.displayName,
          senderAvatarUrl: thread.avatarUrl,
        ),
      ),
      ChatMessageUiModel(
        id: '${thread.id}-outgoing-1',
        direction: ChatMessageDirection.outgoing,
        text: 'Fine!',
        timeLabel: '11:25',
        createdAt: t1,
        outgoingReceipt: ChatOutgoingReceipt.read,
      ),
    ];
  }

  static String newMessageId(String threadId, int index) {
    return '$threadId-local-$index';
  }
}
