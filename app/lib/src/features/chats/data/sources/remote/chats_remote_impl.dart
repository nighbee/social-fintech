import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/chats/data/models/conversation_dto.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http_parser/http_parser.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IChatsRemote)
class ChatsRemoteImpl implements IChatsRemote {
  ChatsRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, ConversationDto>> openDirectConversation({
    required String recipientId,
    bool asRequest = true,
  }) async {
    try {
      final response = await _restClient.post(
        EndPoints.chatsConversationsDirect,
        data: <String, dynamic>{
          'recipient_id': recipientId.trim(),
          'as_request': asRequest,
        },
      );
      return response.fold((error) => Left(error), (result) {
        final data = result.data;
        if (data is! Map<String, dynamic>) {
          return Left(
            UnknownException(
                message: 'Invalid open direct conversation response'),
          );
        }
        return Right(ConversationDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> acceptConversationRequest({
    required String conversationId,
  }) async {
    try {
      final response = await _restClient.post(
        EndPoints.chatsConversationAccept(conversationId),
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> declineConversationRequest({
    required String conversationId,
  }) async {
    try {
      final response = await _restClient.post(
        EndPoints.chatsConversationDecline(conversationId),
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, ListConversationsResponseDto>>
      listConversations({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      };
      final response = await _restClient.get(
        EndPoints.chatsConversations,
        queryParameters: query,
      );
      return response.fold((error) => Left(error), (result) {
        final data = result.data;
        if (data is! Map<String, dynamic>) {
          return Left(
              UnknownException(message: 'Invalid conversations response'));
        }
        return Right(ListConversationsResponseDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, ListMessagesResponseDto>> listMessages({
    required String conversationId,
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      };
      final response = await _restClient.get(
        EndPoints.chatsConversationMessages(conversationId),
        queryParameters: query,
      );
      return response.fold((error) => Left(error), (result) {
        final data = result.data;
        if (data is! Map<String, dynamic>) {
          return Left(
            UnknownException(message: 'Invalid messages response'),
          );
        }
        return Right(ListMessagesResponseDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, MessageDto>> sendMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
    List<Map<String, dynamic>> media = const [],
    String? replyToMessageId,
    String? forwardedFromUserId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'body': body,
        'media': media,
        'idempotency_key': idempotencyKey,
        if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty)
          'reply_to_message_id': replyToMessageId.trim(),
        if (forwardedFromUserId != null &&
            forwardedFromUserId.trim().isNotEmpty)
          'forwarded_from_user_id': forwardedFromUserId.trim(),
      };
      final response = await _restClient.post(
        EndPoints.chatsConversationMessages(conversationId),
        data: payload,
      );
      return response.fold((error) => Left(error), (result) {
        final data = result.data;
        if (data is! Map<String, dynamic>) {
          return Left(
              UnknownException(message: 'Invalid send message response'));
        }
        return Right(MessageDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> markConversationRead({
    required String conversationId,
    String? lastReadMessageId,
  }) async {
    try {
      final body = <String, dynamic>{
        if (lastReadMessageId != null && lastReadMessageId.trim().isNotEmpty)
          'last_read_message_id': lastReadMessageId.trim(),
      };
      final response = await _restClient.post(
        EndPoints.chatsConversationRead(conversationId),
        data: body.isEmpty ? <String, dynamic>{} : body,
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> setConversationMuted({
    required String conversationId,
    required bool muted,
  }) async {
    try {
      final response = await _restClient.put(
        EndPoints.chatsConversationMute(conversationId),
        data: <String, dynamic>{'muted': muted},
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> setConversationPinned({
    required String conversationId,
    required bool pinned,
  }) async {
    try {
      final response = await _restClient.put(
        EndPoints.chatsConversationPin(conversationId),
        data: <String, dynamic>{'pinned': pinned},
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, MessageMediaDto>> uploadChatMedia({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final isVideo = _isVideoFileName(fileName);
      final localFile = File(fileName);
      final canStreamFromPath = bytes.isEmpty && localFile.existsSync();
      final uploadName = fileName.split(RegExp(r'[/\\]')).last;
      final multipartFile = canStreamFromPath
          ? await MultipartFile.fromFile(
              fileName,
              filename: uploadName,
              contentType: _multipartContentType(uploadName, isVideo: isVideo),
            )
          : MultipartFile.fromBytes(
              bytes,
              filename: uploadName,
              contentType: _multipartContentType(uploadName, isVideo: isVideo),
            );
      final response = await _restClient.post(
        EndPoints.chatsMediaUpload,
        data: FormData.fromMap(<String, dynamic>{'file': multipartFile}),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(MessageMediaDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, ListPinnedMessagesResponseDto>>
      listPinnedMessages({
    required String conversationId,
  }) async {
    try {
      final response = await _restClient.get(
        EndPoints.chatsConversationPinnedMessages(conversationId),
      );
      return response.fold((error) => Left(error), (result) {
        final data = result.data;
        if (data is! Map<String, dynamic>) {
          return Left(
            UnknownException(message: 'Invalid pinned messages response'),
          );
        }
        return Right(ListPinnedMessagesResponseDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> pinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final response = await _restClient.post(
        EndPoints.chatsConversationPinMessage(conversationId),
        data: <String, dynamic>{'message_id': messageId.trim()},
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> unpinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final response = await _restClient.delete(
        EndPoints.chatsConversationPinMessage(conversationId),
        data: <String, dynamic>{'message_id': messageId.trim()},
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> deleteMessage({
    required String conversationId,
    required String messageId,
    bool forBoth = false,
  }) async {
    try {
      final response = await _restClient.delete(
        EndPoints.chatsConversationMessage(conversationId, messageId),
        data: forBoth ? <String, dynamic>{'for_both': true} : null,
      );
      return response.fold((error) => Left(error), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  static Map<String, dynamic> _extractMapPayload(Object? data) {
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['item'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return data;
    }
    return <String, dynamic>{};
  }

  static bool _isVideoFileName(String fileName) {
    final n = fileName.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.m4v') ||
        n.endsWith('.webm');
  }

  static MediaType _multipartContentType(String fileName,
      {required bool isVideo}) {
    final lower = fileName.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return MediaType('video', 'quicktime');
      if (lower.endsWith('.webm')) return MediaType('video', 'webm');
      return MediaType('video', 'mp4');
    }
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }
}
