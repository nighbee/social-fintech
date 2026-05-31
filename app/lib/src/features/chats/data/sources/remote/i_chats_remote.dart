import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/chats/data/models/conversation_dto.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

abstract class IChatsRemote {
  Future<Either<DomainException, ListConversationsResponseDto>>
      listConversations({
    String? cursor,
    int limit,
  });

  /// POST `/chats/conversations/direct` — открыть или получить direct с собеседником.
  Future<Either<DomainException, ConversationDto>> openDirectConversation({
    required String recipientId,
    bool asRequest = true,
  });

  Future<Either<DomainException, void>> acceptConversationRequest({
    required String conversationId,
  });

  Future<Either<DomainException, void>> declineConversationRequest({
    required String conversationId,
  });

  Future<Either<DomainException, ListMessagesResponseDto>> listMessages({
    required String conversationId,
    String? cursor,
    int limit,
  });

  Future<Either<DomainException, MessageDto>> sendMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
    List<Map<String, dynamic>> media = const [],
    String? replyToMessageId,
    String? forwardedFromUserId,
  });

  /// POST `/chats/conversations/{id}/read` — отметить прочитанным (тело опционально).
  Future<Either<DomainException, void>> markConversationRead({
    required String conversationId,
    String? lastReadMessageId,
  });

  Future<Either<DomainException, void>> setConversationMuted({
    required String conversationId,
    required bool muted,
  });

  Future<Either<DomainException, void>> setConversationPinned({
    required String conversationId,
    required bool pinned,
  });

  Future<Either<DomainException, MessageMediaDto>> uploadChatMedia({
    required Uint8List bytes,
    required String fileName,
  });

  Future<Either<DomainException, ListPinnedMessagesResponseDto>>
      listPinnedMessages({
    required String conversationId,
  });

  Future<Either<DomainException, void>> pinMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Either<DomainException, void>> unpinMessage({
    required String conversationId,
    required String messageId,
  });

  Future<Either<DomainException, void>> deleteMessage({
    required String conversationId,
    required String messageId,
    bool forBoth = false,
  });
}
