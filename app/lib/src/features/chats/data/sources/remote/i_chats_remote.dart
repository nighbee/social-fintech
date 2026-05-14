import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/chats/data/models/conversation_dto.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
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
  });

  /// POST `/chats/conversations/{id}/read` — отметить прочитанным (тело опционально).
  Future<Either<DomainException, void>> markConversationRead({
    required String conversationId,
    String? lastReadMessageId,
  });
}
