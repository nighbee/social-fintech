import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';

/// Backend: `message_type` `user` | `system` ([backend/internal/modules/chat/entity.go]).
class ChatMessageApiMapper {
  const ChatMessageApiMapper._();

  static List<ChatMessageUiModel> toUiModels(
    List<MessageDto> dtos, {
    required String? currentUserId,
  }) {
    return dtos
        .map((dto) => toUiModel(dto, currentUserId: currentUserId))
        .toList(growable: false);
  }

  static ChatMessageUiModel toUiModel(
    MessageDto dto, {
    required String? currentUserId,
  }) {
    final direction = _direction(dto, currentUserId);
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

    return ChatMessageUiModel(
      id: dto.id,
      direction: direction,
      text: _displayText(dto),
      timeLabel: timeLabel,
      createdAt: dto.createdAt.toLocal(),
      messageType: dto.messageType,
      media: media,
      outgoingReceipt: receipt,
    );
  }

  static ChatMessageDirection _direction(
    MessageDto dto,
    String? currentUserId,
  ) {
    if (dto.messageType == 'system') {
      return ChatMessageDirection.incoming;
    }
    final sid = dto.senderId?.trim();
    final me = currentUserId?.trim();
    if (me != null && me.isNotEmpty && sid == me) {
      return ChatMessageDirection.outgoing;
    }
    return ChatMessageDirection.incoming;
  }

  static String _displayText(MessageDto dto) {
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
