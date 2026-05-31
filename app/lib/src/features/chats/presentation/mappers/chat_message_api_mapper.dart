import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';

/// Backend: `message_type` `user` | `system` ([backend/internal/modules/chat/entity.go]).
class ChatMessageApiMapper {
  const ChatMessageApiMapper._();

  static List<ChatMessageUiModel> toUiModels(
    List<MessageDto> dtos, {
    required String? currentUserId,
    Set<String> forceOutgoingMessageIds = const <String>{},
  }) {
    final byId = <String, MessageDto>{
      for (final dto in dtos)
        if (dto.id.trim().isNotEmpty) dto.id.trim(): dto,
    };
    return dtos
        .map(
          (dto) => toUiModel(
            dto,
            currentUserId: currentUserId,
            replyLookup: byId,
            forceOutgoing: forceOutgoingMessageIds.contains(dto.id.trim()),
          ),
        )
        .toList(growable: false);
  }

  static ChatMessageUiModel toUiModel(
    MessageDto dto, {
    required String? currentUserId,
    Map<String, MessageDto>? replyLookup,
    bool forceOutgoing = false,
  }) {
    final direction = forceOutgoing
        ? ChatMessageDirection.outgoing
        : _direction(dto, currentUserId);
    final timeLabel = _timeLabel(dto.createdAt);
    final outgoing = direction == ChatMessageDirection.outgoing;
    final receipt = outgoing
        ? (dto.viewerMessageRead
            ? ChatOutgoingReceipt.read
            : ChatOutgoingReceipt.delivered)
        : ChatOutgoingReceipt.none;

    final media = dto.media
        .map(
          (m) => ChatMessageMediaItem(
            type: m.type,
            url: m.url,
            thumbnailUrl: m.thumbnailUrl,
          ),
        )
        .toList(growable: false);

    final fwd = dto.forwardedFromUserId?.trim() ?? '';
    final fwdUser = dto.forwardedFromUser;
    final fwdDisplay = (fwdUser?.displayName ?? '').trim();
    final fwdUsername = (fwdUser?.username ?? '').trim();
    final ChatForwardedSnippet? forwarded = fwd.isEmpty && fwdUser == null
        ? null
        : ChatForwardedSnippet(
            senderName: fwdDisplay.isNotEmpty
                ? fwdDisplay
                : (fwdUsername.isNotEmpty ? '@$fwdUsername' : 'Forwarded'),
            senderAvatarUrl: '',
            senderId: fwdUser?.id,
            username: fwdUsername.isEmpty ? null : fwdUsername,
          );

    return ChatMessageUiModel(
      id: dto.id,
      direction: direction,
      text: _displayText(dto),
      timeLabel: timeLabel,
      createdAt: dto.createdAt.toLocal(),
      messageType: dto.messageType,
      media: media,
      replyPreview: _replyPreview(dto, replyLookup, currentUserId),
      forwardedSnippet: forwarded,
      outgoingReceipt: receipt,
    );
  }

  static ChatReplyPreview? _replyPreview(
    MessageDto dto,
    Map<String, MessageDto>? replyLookup,
    String? currentUserId,
  ) {
    final replyId = dto.replyToMessageId?.trim() ?? '';
    final enriched = dto.replyToMessage;
    if (enriched != null) {
      final explicitName = (enriched.senderName ?? '').trim();
      final author = _sameSender(enriched.senderId, currentUserId)
          ? 'You'
          : (explicitName.isNotEmpty ? explicitName : 'Original message');
      final body = enriched.body.trim();
      return ChatReplyPreview(
        authorLabel: author,
        excerpt: body.isEmpty ? 'Message' : body,
      );
    }
    if (replyId.isEmpty || replyLookup == null) {
      return null;
    }
    final original = replyLookup[replyId];
    if (original == null) {
      return null;
    }
    final author = _sameSender(original.senderId, currentUserId)
        ? 'You'
        : 'Original message';
    return ChatReplyPreview(
      authorLabel: author,
      excerpt: _excerpt(original),
    );
  }

  static String _excerpt(MessageDto dto) {
    if (dto.deletedAt != null) {
      return 'Deleted message';
    }
    final body = dto.body.trim();
    if (body.isNotEmpty) {
      return body.length > 80 ? '${body.substring(0, 77)}...' : body;
    }
    if (dto.media.any((m) {
      final t = m.type.trim().toLowerCase();
      return t == 'image' || t.startsWith('image/');
    })) {
      return 'Photo';
    }
    if (dto.media.any((m) {
      final t = m.type.trim().toLowerCase();
      return t == 'video' || t.startsWith('video/');
    })) {
      return 'Video';
    }
    return 'Message';
  }

  static ChatMessageDirection _direction(
    MessageDto dto,
    String? currentUserId,
  ) {
    if (dto.messageType == 'system') {
      return ChatMessageDirection.incoming;
    }
    if (_sameSender(dto.senderId, currentUserId)) {
      return ChatMessageDirection.outgoing;
    }
    return ChatMessageDirection.incoming;
  }

  /// Сопоставление с учётом регистра и опциональных дефисов в UUID.
  static bool _sameSender(String? senderId, String? currentUserId) {
    final s = senderId?.trim() ?? '';
    final u = currentUserId?.trim() ?? '';
    if (s.isEmpty || u.isEmpty) {
      return false;
    }
    if (s == u) {
      return true;
    }
    final ls = s.toLowerCase();
    final lu = u.toLowerCase();
    if (ls == lu) {
      return true;
    }
    final ns = ls.replaceAll('-', '');
    final nu = lu.replaceAll('-', '');
    if (ns.isNotEmpty && ns == nu) {
      return true;
    }
    return false;
  }

  static String _displayText(MessageDto dto) {
    if (dto.deletedAt != null) {
      return 'Сообщение удалено';
    }
    final body = dto.body.trim();
    if (body.isNotEmpty) {
      return dto.body;
    }
    if (dto.media.isEmpty) {
      return '';
    }
    final types = dto.media.map((m) => m.type.trim().toLowerCase()).toSet();
    if (types.any((t) => t == 'image' || t.startsWith('image/'))) {
      return '';
    }
    if (types.any((t) => t == 'video' || t.startsWith('video/'))) {
      return '';
    }
    if (types.any((t) => t == 'audio' || t.startsWith('audio/'))) {
      return 'Voice message';
    }
    return dto.media.map((m) => m.url).where((u) => u.isNotEmpty).join('\n');
  }

  static String _timeLabel(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

bool chatConversationIdLooksLikeUuid(String id) {
  final t = id.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(t);
}
