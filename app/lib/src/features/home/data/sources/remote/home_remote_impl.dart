import 'dart:io';

import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/claim_daily_accrual_result_dto.dart';
import 'package:app/src/features/home/data/models/comment_response_dto.dart';
import 'package:app/src/features/home/data/models/economy_balance_dto.dart';
import 'package:app/src/features/home/data/models/economy_limits_dto.dart';
import 'package:app/src/features/home/data/models/feed_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/data/models/interaction_list_dto.dart';
import 'package:app/src/features/home/data/models/media_attachment_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/post_response_dto.dart';
import 'package:app/src/features/home/data/models/report_post_result_dto.dart';
import 'package:app/src/features/home/data/models/seal_list_dto.dart';
import 'package:app/src/features/home/data/models/send_post_seal_result_dto.dart';
import 'package:app/src/features/home/data/models/status_response_dto.dart';
import 'package:app/src/features/home/data/models/threaded_comments_dto.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:app/src/features/home/domain/requests/claim_daily_accrual_request.dart';
import 'package:app/src/features/home/domain/requests/comment_id_request.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_my_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/domain/requests/update_post_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http_parser/http_parser.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IHomeRemote)
class HomeRemoteImpl implements IHomeRemote {
  HomeRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;
  static const int _defaultVideoDurationSeconds = 120;

  @override
  Future<Either<DomainException, FeedDto>> getFeed(FeedRequest request) async {
    try {
      final response = await _restClient.get(
        EndPoints.feed,
        queryParameters: request.toQuery(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(FeedDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, PostResponseDto>> createFeedPost(
    CreatePostRequest request, {
    FormData? formData,
    List<LocalMediaPayload> localMediaPayloads = const <LocalMediaPayload>[],
  }) async {
    try {
      final uploadedAttachments = <MediaAttachmentRequest>[];
      final uploadedVideoUrls = <String>{};
      for (final payload in localMediaPayloads) {
        final isVideo = _isVideoFileName(payload.localUrl);
        final uploaded = await uploadFeedMedia(
          UploadFeedMediaRequest(
            bytes: payload.bytes,
            fileName: payload.localUrl,
          ),
        );
        if (uploaded.isLeft()) {
          return uploaded.fold(
              Left.new, (_) => throw StateError('unreachable'));
        }
        uploaded.fold((_) {}, (attachment) {
          uploadedAttachments.add(attachment);
          if (isVideo) {
            uploadedVideoUrls.add(attachment.url);
          }
        });
      }

      final mergedRequest = request.copyWith(
        mediaAttachments: <MediaAttachmentRequest>[
          ...request.mediaAttachments,
          ...uploadedAttachments,
        ],
      );

      final requestPayload = mergedRequest.toJson();
      final mediaRaw = requestPayload['media_attachments'];
      if (mediaRaw is List) {
        final normalizedMedia = <Map<String, dynamic>>[];
        for (final item in mediaRaw) {
          if (item is Map) {
            final map = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            final type = (map['type'] ?? '').toString().toLowerCase();
            final mediaUrl =
                (map['video_1080p_url'] ?? map['url'] ?? '').toString();
            if (type == 'video') {
              final hasDuration = map['duration_seconds'] != null;
              if (!hasDuration || uploadedVideoUrls.contains(mediaUrl)) {
                map['duration_seconds'] = _defaultVideoDurationSeconds;
              }
            }
            normalizedMedia.add(map);
          }
        }
        requestPayload['media_attachments'] = normalizedMedia;
      }

      final response = await _restClient.post(
        EndPoints.posts,
        data: formData ?? requestPayload,
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(PostResponseDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedDto>> getProfilePostsGrid(
    GetProfilePostsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.profilePostsById(request.userId),
        queryParameters: request.toQuery(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(FeedDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedDto>> getMyProfilePostsList(
    GetMyProfilePostsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.profileMePostsList,
        queryParameters: request.toQuery(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(FeedDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedDto>> getProfilePostsList(
    GetProfilePostsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.profilePostsListById(request.userId),
        queryParameters: request.toQuery(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(FeedDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(ThreadedCommentsDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(CommentResponseDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, MediaAttachmentRequest>> uploadFeedMedia(
    UploadFeedMediaRequest request,
  ) async {
    try {
      final isVideo = _isVideoFileName(request.fileName);
      final localFile = File(request.fileName);
      final canStreamFromPath = request.bytes.isEmpty && localFile.existsSync();
      final uploadName = request.fileName.split(RegExp(r'[/\\]')).last;
      final contentType = _multipartContentType(uploadName, isVideo: isVideo);
      final multipartFile = canStreamFromPath
          ? await MultipartFile.fromFile(
              request.fileName,
              filename: uploadName,
              contentType: contentType,
            )
          : MultipartFile.fromBytes(
              request.bytes,
              filename: uploadName,
              contentType: contentType,
            );

      final formFields = <String, dynamic>{
        'file': multipartFile,
      };
      if (isVideo) {
        formFields['duration_seconds'] =
            _defaultVideoDurationSeconds.toString();
      }

      final formData = FormData.fromMap(formFields);
      final response = await _restClient.post(
        EndPoints.feedMediaUpload,
        data: formData,
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        final dto = MediaAttachmentDto.fromJson(payload);
        return Right(
          MediaAttachmentRequest(
            type: dto.type,
            url: dto.url,
            thumbnailUrl: dto.thumbnailUrl,
          ),
        );
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(InteractionListDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(SealListDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, EconomyBalanceDto>> getEconomyBalance() async {
    try {
      final response = await _restClient.get(EndPoints.economyBalance);
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(EconomyBalanceDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, EconomyLimitsDto>> getEconomyLimits() async {
    try {
      final response = await _restClient.get(EndPoints.economyLimits);
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(EconomyLimitsDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, PostResponseDto>> togglePostLike(
    PostIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postLikes(request.postId),
        data: <String, dynamic>{},
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(PostResponseDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, StatusResponseDto>> updatePost(
    PostIdRequest requestId,
    UpdatePostRequest request,
  ) async {
    try {
      final response = await _restClient.patch(
        EndPoints.postById(requestId.postId),
        data: request.toPayload(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        // PATCH /posts/:id may return full PostResponse without `status`.
        final status = (payload['status'] as String?)?.trim();
        final error = payload['error'] as String?;
        final message = payload['message'] as String?;
        return Right(
          StatusResponseDto(
            status: (status == null || status.isEmpty) ? 'success' : status,
            error: error,
            message: message,
          ),
        );
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, StatusResponseDto>> deletePost(
    PostIdRequest requestId,
  ) async {
    try {
      final response =
          await _restClient.delete(EndPoints.postById(requestId.postId));
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(StatusResponseDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(ReportPostResultDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
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
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(SendPostSealResultDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, ClaimDailyAccrualResultDto>> claimDailyAccrual(
    ClaimDailyAccrualRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.economyAccrualClaim,
        data: request.toPayload(),
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(ClaimDailyAccrualResultDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, CommentResponseDto>> toggleCommentLike(
    CommentIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.commentLikes(request.commentId),
        data: <String, dynamic>{},
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(CommentResponseDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<NotificationDto>>> getNotifications({
    String? tab,
  }) async {
    try {
      final response = await _restClient.get(
        EndPoints.notifications,
        queryParameters: <String, dynamic>{
          if (tab != null && tab.isNotEmpty) 'tab': tab,
        },
      );
      return response.fold((error) => Left(error), (result) {
        final payload = _extractListPayload(result.data);
        final items = payload
            .map((item) => NotificationDto.fromJson(item))
            .toList(growable: false);
        return Right(items);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedStateDto>> getFeedState() async {
    try {
      final response = await _restClient.get(EndPoints.feedState);
      return response.fold((error) => Left(error), (result) {
        final payload = _extractMapPayload(result.data);
        return Right(FeedStateDto.fromJson(payload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, FeedStateDto>> syncFeedState(
    FeedStateSyncRequest request,
  ) async {
    try {
      final payload = request.toJson();
      final response = await _restClient.post(
        EndPoints.feedStateSync,
        data: payload,
      );
      return response.fold((error) => Left(error), (result) {
        final responsePayload = _extractMapPayload(result.data);
        return Right(FeedStateDto.fromJson(responsePayload));
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  Map<String, dynamic> _extractMapPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    if (raw is Map) {
      final mapped = raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final data = mapped['data'];
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
      return mapped;
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractListPayload(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    final map = _extractMapPayload(raw);
    final items = map['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  bool _isVideoFileName(String fileName) {
    final name = fileName.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.webm');
  }

  MediaType? _multipartContentType(String fileName, {required bool isVideo}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (lower.endsWith('.mov') || lower.endsWith('.m4v')) {
      return MediaType('video', 'quicktime');
    }
    if (lower.endsWith('.webm')) return MediaType('video', 'webm');
    if (isVideo) return MediaType('video', 'mp4');
    return MediaType('image', 'jpeg');
  }
}
