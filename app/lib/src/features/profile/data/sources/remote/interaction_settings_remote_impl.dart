import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';

@LazySingleton(as: IInteractionSettingsRemote)
class InteractionSettingsRemoteImpl implements IInteractionSettingsRemote {
  InteractionSettingsRemoteImpl(@Named('DioClient') this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _restClient.patch(
        EndPoints.settingsSecurityPassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, SecurityOverviewDto>>
      getSecurityOverview() async {
    try {
      final response = await _restClient.get(EndPoints.settingsSecurity);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(SecurityOverviewDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<SessionItemDto>>>
      listSessions() async {
    try {
      final response = await _restClient.get(EndPoints.settingsSecuritySessions);
      return response.fold((e) => Left(e), (result) {
        final raw = result.data;
        if (raw is! List) {
          return Left(
            UnknownException(message: 'Invalid sessions response'),
          );
        }
        final list = raw
            .map(
              (e) => SessionItemDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        return Right(list);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedSettingsDto>> getFeedSettings() async {
    try {
      final response = await _restClient.get(EndPoints.settingsFeed);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(FeedSettingsDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> patchFeedSettings(
    int newLimitMins,
  ) async {
    try {
      final response = await _restClient.patch(
        EndPoints.settingsFeed,
        data: {'new_limit_mins': newLimitMins},
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  Map<String, dynamic> _messagesPatchBody({
    String? whoCanMessage,
    bool? readStatus,
    bool? safeMode,
  }) {
    final map = <String, dynamic>{};
    if (whoCanMessage != null) {
      map['who_can_message'] = whoCanMessage;
    }
    if (readStatus != null) {
      map['read_status'] = readStatus;
    }
    if (safeMode != null) {
      map['safe_mode'] = safeMode;
    }
    return map;
  }

  @override
  Future<Either<DomainException, InteractionsSettingsDto>> getInteractions() async {
    try {
      final response = await _restClient.get(EndPoints.settingsInteractions);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(InteractionsSettingsDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, MessagesSettingsDto>> getMessagesSettings() async {
    try {
      final response =
          await _restClient.get(EndPoints.settingsInteractionsMessages);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(MessagesSettingsDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> patchMessagesSettings({
    String? whoCanMessage,
    bool? readStatus,
    bool? safeMode,
  }) async {
    try {
      final body = _messagesPatchBody(
        whoCanMessage: whoCanMessage,
        readStatus: readStatus,
        safeMode: safeMode,
      );
      final response = await _restClient.patch(
        EndPoints.settingsInteractionsMessages,
        data: body,
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, CommentsSettingsDto>> getCommentsSettings() async {
    try {
      final response =
          await _restClient.get(EndPoints.settingsInteractionsComments);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(CommentsSettingsDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> patchCommentsSettings({
    String? whoCanComment,
    bool? filterUnwanted,
  }) async {
    try {
      final map = <String, dynamic>{};
      if (whoCanComment != null) {
        map['who_can_comment'] = whoCanComment;
      }
      if (filterUnwanted != null) {
        map['filter_unwanted'] = filterUnwanted;
      }
      final response = await _restClient.patch(
        EndPoints.settingsInteractionsComments,
        data: map,
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, MentionsSettingsDto>> getMentionsSettings() async {
    try {
      final response =
          await _restClient.get(EndPoints.settingsInteractionsMentions);
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(MentionsSettingsDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> patchMentionsSettings({
    required String whoCanMention,
  }) async {
    try {
      final response = await _restClient.patch(
        EndPoints.settingsInteractionsMentions,
        data: {'who_can_mention': whoCanMention},
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, BlockedUsersResponseDto>> getBlockedUsers({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _restClient.get(
        EndPoints.settingsInteractionsBlocked,
        queryParameters: {
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
      );
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        return Right(BlockedUsersResponseDto.fromJson(data));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> unblockUser(String userId) async {
    try {
      final response = await _restClient.delete(
        EndPoints.settingsInteractionsBlockedUser(userId),
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, String>> addMessageKeyword(String keyword) async {
    try {
      final response = await _restClient.post(
        EndPoints.settingsInteractionsMessageKeywords,
        data: {'keyword': keyword},
      );
      return response.fold((e) => Left(e), (result) {
        final data = result.data as Map<String, dynamic>;
        final id = data['id'] as String? ?? '';
        return Right(id);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> deleteMessageKeyword(String id) async {
    try {
      final response = await _restClient.delete(
        EndPoints.settingsInteractionsMessageKeyword(id),
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> reportBug({
    required String description,
    String? screenshotFilePath,
    required String appVersion,
    required String deviceOS,
  }) async {
    try {
      final fields = <String, dynamic>{
        'description': description,
        'app_version': appVersion,
        'device_os': deviceOS,
      };
      final path = screenshotFilePath;
      if (path != null && path.isNotEmpty) {
        fields['screenshot'] = await MultipartFile.fromFile(path);
      }
      final formData = FormData.fromMap(fields);
      final response = await _restClient.post(
        EndPoints.settingsSupportBugs,
        data: formData,
      );
      return response.fold((e) => Left(e), (_) => const Right(null));
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }
}
