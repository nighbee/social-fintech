import 'dart:typed_data';

import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/feed_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/data/models/interaction_list_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/post_response_dto.dart';
import 'package:app/src/features/home/data/models/report_post_result_dto.dart';
import 'package:app/src/features/home/data/models/comment_response_dto.dart';
import 'package:app/src/features/home/data/models/claim_daily_accrual_result_dto.dart';
import 'package:app/src/features/home/data/models/economy_balance_dto.dart';
import 'package:app/src/features/home/data/models/economy_limits_dto.dart';
import 'package:app/src/features/home/data/models/seal_list_dto.dart';
import 'package:app/src/features/home/data/models/send_post_seal_result_dto.dart';
import 'package:app/src/features/home/data/models/threaded_comments_dto.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/comment_id_request.dart';
import 'package:app/src/features/home/domain/requests/claim_daily_accrual_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IHomeRemote)
class HomeRemoteImpl implements IHomeRemote {
  HomeRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, FeedDto>> getFeed(FeedRequest request) async {
    try {
      final response = await _restClient.get(
        EndPoints.feed,
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(UnknownException(message: 'Invalid feed response'));
          }
          final dto = FeedDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, PostResponseDto>> createFeedPost(
    CreatePostRequest request, {
    FormData? formData,
    List<LocalMediaPayload> localMediaPayloads = const [],
  }) async {
    try {
      final dynamic payload;
      if (formData != null) {
        payload = formData;
      } else {
        final preparedRequest = await _prepareCreatePostRequest(
          request,
          localMediaPayloads,
        );
        payload = preparedRequest.toJson();
      }
      final response = await _restClient.post(EndPoints.posts, data: payload);
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid create feed post response'),
            );
          }
          final dto = PostResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  Future<CreatePostRequest> _prepareCreatePostRequest(
    CreatePostRequest request,
    List<LocalMediaPayload> localMediaPayloads,
  ) async {
    if (request.mediaAttachments.isEmpty || localMediaPayloads.isEmpty) {
      return request;
    }

    final localMediaBytesByUrl = <String, Uint8List>{
      for (final payload in localMediaPayloads) payload.localUrl: payload.bytes,
    };

    final List<MediaAttachmentRequest> uploadedAttachments = [];
    for (final attachment in request.mediaAttachments) {
      if (!attachment.url.startsWith('local-media://')) {
        uploadedAttachments.add(attachment);
        continue;
      }

      final bytes = _resolveLocalBytes(localMediaBytesByUrl, attachment.url);
      if (bytes == null) {
        uploadedAttachments.add(attachment);
        continue;
      }

      final uploaded = await _uploadFeedMedia(
        bytes: bytes,
        localUrl: attachment.url,
        fallbackType: attachment.type,
      );
      uploadedAttachments.add(uploaded);
    }

    return request.copyWith(mediaAttachments: uploadedAttachments);
  }

  Uint8List? _resolveLocalBytes(
    Map<String, Uint8List> localMediaBytesByUrl,
    String localUrl,
  ) {
    final direct = localMediaBytesByUrl[localUrl];
    if (direct != null) return direct;

    final suffix = localUrl.substring('local-media://'.length);
    final decoded = Uri.decodeComponent(suffix);
    final encoded = Uri.encodeComponent(decoded);
    return localMediaBytesByUrl['local-media://$decoded'] ??
        localMediaBytesByUrl['local-media://$encoded'] ??
        localMediaBytesByUrl[decoded] ??
        localMediaBytesByUrl[encoded];
  }

  Future<MediaAttachmentRequest> _uploadFeedMedia({
    required Uint8List bytes,
    required String localUrl,
    required String fallbackType,
  }) async {
    final fileName = _fileNameFromLocalUrl(localUrl);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final response = await _restClient.post(
      EndPoints.feedMediaUpload,
      data: formData,
    );

    return response.fold(
      (error) => throw UnknownException(
        message: 'Feed media upload failed: ${error.message}',
      ),
      (result) {
        final raw = result.data;
        if (raw is! Map) {
          throw UnknownException(
            message: 'Invalid feed media upload response format',
          );
        }
        final map = Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
        final url = (map['url'] as String?)?.trim();
        if (url == null || url.isEmpty) {
          throw UnknownException(
            message: 'Feed media upload response missing URL',
          );
        }
        final type = (map['type'] as String?) ?? fallbackType;
        return MediaAttachmentRequest(type: type, url: url);
      },
    );
  }

  String _fileNameFromLocalUrl(String localUrl) {
    final suffix = localUrl.substring('local-media://'.length);
    return Uri.decodeComponent(suffix);
  }

  @override
  Future<Either<DomainException, ThreadedCommentsDto>> getPostComments(
    GetPostCommentsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.postComments(request.postId),
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid get post comments response'),
            );
          }
          final dto = ThreadedCommentsDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, CommentResponseDto>> createPostComment(
    PostIdRequest requestId,
    CreateCommentRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postComments(requestId.postId),
        data: request.toJson(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid create post comment response'),
            );
          }
          final dto = CommentResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MediaAttachmentRequest>> uploadFeedMedia(
    UploadFeedMediaRequest request,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          request.bytes,
          filename: request.fileName,
        ),
      });
      final response = await _restClient.post(
        EndPoints.feedMediaUpload,
        data: formData,
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(
                message: 'Invalid feed media upload response format',
              ),
            );
          }
          final map = Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
          final url = (map['url'] as String?)?.trim();
          if (url == null || url.isEmpty) {
            return Left(
              UnknownException(
                message: 'Feed media upload response missing URL',
              ),
            );
          }
          final type = (map['type'] as String?) ?? request.fallbackType;
          return Right(MediaAttachmentRequest(type: type, url: url));
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, InteractionListDto>> getPostLikes(
    GetPostLikesRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.postLikes(request.postId),
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid get post likes response'),
            );
          }
          final dto = InteractionListDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, SealListDto>> getPostSeals(
    GetPostSealsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.postSeals(request.postId),
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid get post seals response'),
            );
          }
          final dto = SealListDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, EconomyBalanceDto>> getEconomyBalance() async {
    try {
      final response = await _restClient.get(EndPoints.economyBalance);
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid economy balance response'),
            );
          }
          final dto = EconomyBalanceDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, EconomyLimitsDto>> getEconomyLimits() async {
    try {
      final response = await _restClient.get(EndPoints.economyLimits);
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid economy limits response'),
            );
          }
          final dto = EconomyLimitsDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, PostResponseDto>> togglePostLike(
    PostIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postLikes(request.postId),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid toggle post like response'),
            );
          }
          final dto = PostResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, ReportPostResultDto>> reportPost(
    PostIdRequest requestId,
    ReportPostRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postReport(requestId.postId),
        data: request.toPayload(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid report post response'),
            );
          }
          final dto = ReportPostResultDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, SendPostSealResultDto>> sendPostSeal(
    PostIdRequest requestId,
    SendPostSealRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postSeals(requestId.postId),
        data: request.toPayload(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid send post seal response'),
            );
          }
          final dto = SendPostSealResultDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, ClaimDailyAccrualResultDto>>
      claimDailyAccrual(
    ClaimDailyAccrualRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.economyAccrualClaim,
        data: request.toPayload(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid claim daily accrual response'),
            );
          }
          final dto = ClaimDailyAccrualResultDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, CommentResponseDto>> toggleCommentLike(
    CommentIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.commentLikes(request.commentId),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid toggle comment like response'),
            );
          }
          final dto = CommentResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  // Notifications mock data and methods
  final List<NotificationDto> _mockNotifications = [
    NotificationDto(
      id: '1',
      type: 'like',
      notificationType: 'like',
      userId: 'user1',
      userName: 'Isabbekov',
      userAvatarUrl: '',
      userMeta: 'Moonstone - Intention - A',
      message: 'Did you like your video',
      accentText: '',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-1',
      postId: 'post123',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isRead: false,
    ),
    NotificationDto(
      id: '2',
      type: 'follow',
      notificationType: 'subscriptions',
      userId: 'user2',
      userName: 'Zhajd',
      userAvatarUrl: '',
      userMeta: 'Moonstone - Intention - A',
      message: 'Subscribed to you',
      accentText: '',
      ctaLabel: 'View',
      ctaValue: '',
      rightImageUrl: '',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      isRead: false,
    ),
    NotificationDto(
      id: '3',
      type: 'comment',
      notificationType: 'comment',
      userId: 'user3',
      userName: 'Esimova',
      userAvatarUrl: '',
      userMeta: 'Lapiz Lazuli - Influence - A',
      message: 'Left a comment',
      accentText: '"Cool bro"',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-2',
      postId: 'post456',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    NotificationDto(
      id: '4',
      type: 'rejected',
      notificationType: 'post',
      userId: 'user4',
      userName: 'You',
      userAvatarUrl: '',
      userMeta: '',
      message: 'Your post was not verified',
      accentText: 'reason',
      ctaLabel: 'Clear',
      ctaValue: 'Does not comply with social norms',
      rightImageUrl: 'post-thumb-3',
      postId: 'post789',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    NotificationDto(
      id: '5',
      type: 'pending',
      notificationType: 'help',
      userId: 'user5',
      userName: 'Ahanov',
      userAvatarUrl: '',
      userMeta: 'Ammolite - Fortitude - S',
      message: 'Request "Son\'s birthday"',
      accentText: '',
      ctaLabel: 'View',
      ctaValue: '',
      rightImageUrl: '',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    NotificationDto(
      id: '6',
      type: 'published',
      notificationType: 'post',
      userId: 'me',
      userName: 'You',
      userAvatarUrl: '',
      userMeta: '',
      message: 'Your post has been successfully published',
      accentText: '',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-4',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  @override
  Future<Either<DomainException, List<NotificationDto>>>
      getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Right(List<NotificationDto>.from(_mockNotifications));
  }

  @override
  Future<Either<DomainException, FeedStateDto>> getFeedState() async {
    try {
      final response = await _restClient.get(EndPoints.feedState);
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(UnknownException(message: 'Invalid feed state response'));
          }
          final dto = FeedStateDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, FeedStateDto>> syncFeedState(
    FeedStateSyncRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.feedStateSync,
        data: request.toJson(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid feed state sync response'),
            );
          }
          final dto = FeedStateDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }
}
