import 'package:app/src/features/chats/data/models/conversation_dto.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Maps API [ConversationDto] to UI [ChatThreadPreview] (Figma list row).
class ChatThreadPreviewMapper {
  const ChatThreadPreviewMapper._();

  static ChatThreadPreview fromConversation(ConversationDto dto) {
    final display = (dto.otherDisplayName ?? '').trim();
    final username = (dto.otherUsername ?? '').trim();
    final title = display.isNotEmpty
        ? display
        : (username.isNotEmpty ? username : 'User');

    final rankLine = _rankLine(dto, title, username);
    final preview = (dto.lastMessagePreview ?? '').trim();
    final at = dto.lastMessageAt ?? dto.updatedAt;
    final otherId = (dto.otherUserId ?? '').trim();
    final readAt = dto.otherParticipantReadAt;

    String? pinPreview;
    String? pinId;
    final pins = dto.pinnedMessages;
    if (pins.isNotEmpty) {
      final head = pins.first;
      final pb = head.messageBody.trim();
      if (pb.isNotEmpty) {
        pinPreview = pb.length > 160 ? '${pb.substring(0, 157)}…' : pb;
        pinId = head.messageId.trim().isEmpty ? null : head.messageId.trim();
      }
    }

    return ChatThreadPreview(
      id: dto.id,
      displayName: title,
      rankLine: rankLine,
      lastSeenLabel: _lastSeenLine(readAt),
      timeLabel: _timeLabel(at),
      avatarUrl: (dto.otherAvatarUrl ?? '').trim(),
      previewText: preview,
      unreadCount: dto.unreadCount,
      isRequest: false,
      otherUserId: otherId.isNotEmpty ? otherId : null,
      pinnedMessagePreview: pinPreview,
      pinnedMessageId: pinId,
    );
  }

  /// В API пока нет «last seen онлайн»; показываем время последнего просмотра переписки собеседником.
  static String _lastSeenLine(DateTime? otherReadAt) {
    if (otherReadAt == null) {
      return '';
    }
    final ago = timeago.format(otherReadAt.toLocal());
    return 'Last read · $ago';
  }

  /// Ранг приходит с бэка (`other_rank_tier`, из wallets + спека рангов) — без отдельного GET /me/rank.
  static String _normalizeRankTier(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'\s*\|\s*'), ' · ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _rankLine(ConversationDto dto, String title, String username) {
    final tier = (dto.otherRankTier ?? '').trim();
    if (tier.isNotEmpty) {
      return _normalizeRankTier(tier);
    }
    if (dto.kind == 'task') {
      return 'Task chat';
    }
    if (username.isNotEmpty &&
        title.trim().toLowerCase() != username.toLowerCase()) {
      return '@$username';
    }
    return username.isNotEmpty ? '@$username' : 'Direct message';
  }

  static String _timeLabel(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) {
      return 'Yesterday';
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
}
