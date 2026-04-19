import 'package:flutter/foundation.dart';

enum ChatMessageDirection {
  incoming,
  outgoing,
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
class ChatMessageUiModel {
  const ChatMessageUiModel({
    required this.id,
    required this.direction,
    required this.text,
    required this.timeLabel,
    this.forwardedSnippet,
    this.showSeenMark = false,
  });

  final String id;
  final ChatMessageDirection direction;
  final String text;
  final String timeLabel;
  final ChatForwardedSnippet? forwardedSnippet;
  final bool showSeenMark;
}

class ChatMockStore {
  static const String requestThreadId = 'ayaulym-request';
  static const String primaryThreadId = 'merey-thread';
  static const String secondaryThreadId = 'aida-thread';

  static const List<ChatThreadPreview> requestThreads = <ChatThreadPreview>[
    ChatThreadPreview(
      id: requestThreadId,
      displayName: 'Ayaulym Yesmoldayeva',
      rankLine: 'Moonstone - Intention - A',
      lastSeenLabel: 'last seen 12 minutes ago',
      timeLabel: '22:11',
      unreadCount: 1,
      isRequest: true,
      avatarUrl: 'https://i.pravatar.cc/96?img=12',
    ),
  ];

  static const List<ChatThreadPreview> recentThreads = <ChatThreadPreview>[
    ChatThreadPreview(
      id: primaryThreadId,
      displayName: 'Merey Zhumagul',
      rankLine: 'Moonstone - Intention - A',
      lastSeenLabel: 'last seen 7 minutes ago',
      timeLabel: '11:22',
      previewText: 'Hello! How r u',
      unreadCount: 1,
      avatarUrl: 'https://i.pravatar.cc/96?img=21',
    ),
    ChatThreadPreview(
      id: secondaryThreadId,
      displayName: 'Aida Nurkhan',
      rankLine: 'Moonstone - Intention - A',
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
    return <ChatMessageUiModel>[
      ChatMessageUiModel(
        id: '${thread.id}-incoming-1',
        direction: ChatMessageDirection.incoming,
        text: 'Hello! How r u',
        timeLabel: '11:22',
      ),
    ];
  }

  static List<ChatMessageUiModel> forwardedMessages(String threadId) {
    final thread = threadById(threadId);
    return <ChatMessageUiModel>[
      ...baseMessages(threadId),
      ChatMessageUiModel(
        id: '${thread.id}-forwarded-1',
        direction: ChatMessageDirection.outgoing,
        text: 'Hello! How r u',
        timeLabel: '11:26',
        showSeenMark: true,
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
        showSeenMark: true,
      ),
    ];
  }

  static String newMessageId(String threadId, int index) {
    return '$threadId-local-$index';
  }
}
