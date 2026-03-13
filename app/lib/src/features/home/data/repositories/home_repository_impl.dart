import 'package:app/src/features/home/data/models/economy_balance_dto.dart';
import 'package:app/src/features/home/data/models/economy_limits_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/entities/claim_daily_accrual_result_entity.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:app/src/features/home/domain/entities/seal_list_entity.dart';
import 'package:app/src/features/home/domain/entities/send_post_seal_result_entity.dart';
import 'package:app/src/features/home/domain/entities/store_summary_entity.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/sources/remote/home_remote_impl.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
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
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';

@named
@LazySingleton(as: IHomeRepository)
class HomeRepositoryImpl implements IHomeRepository {
  HomeRepositoryImpl(@Named.from(HomeRemoteImpl) this._remote);

  final IHomeRemote _remote;

  @override
  Future<Either<DomainException, FeedEntity>> getFeed(
    FeedRequest request,
  ) async {
    final result = await _remote.getFeed(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, PostResponseEntity>> createFeedPost(
    CreatePostRequest request,
    List<LocalMediaPayload> localMediaPayloads,
  ) async {
    final result = await _remote.createFeedPost(
      request,
      localMediaPayloads: localMediaPayloads,
    );
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, ThreadedCommentsEntity>> getPostComments(
    GetPostCommentsRequest request,
  ) async {
    final result = await _remote.getPostComments(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, CommentResponseEntity>> createPostComment(
    PostIdRequest requestId,
    CreateCommentRequest request,
  ) async {
    final result = await _remote.createPostComment(requestId, request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, MediaAttachmentRequest>> uploadFeedMedia(
    UploadFeedMediaRequest request,
  ) async {
    return _remote.uploadFeedMedia(request);
  }

  @override
  Future<Either<DomainException, InteractionListEntity>> getPostLikes(
    GetPostLikesRequest request,
  ) async {
    final result = await _remote.getPostLikes(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, SealListEntity>> getPostSeals(
    GetPostSealsRequest request,
  ) async {
    final result = await _remote.getPostSeals(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, PostResponseEntity>> togglePostLike(
    PostIdRequest request,
  ) async {
    final result = await _remote.togglePostLike(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, SendPostSealResultEntity>> sendPostSeal(
    PostIdRequest requestId,
    SendPostSealRequest request,
  ) async {
    final result = await _remote.sendPostSeal(requestId, request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, CommentResponseEntity>> toggleCommentLike(
    CommentIdRequest request,
  ) async {
    final result = await _remote.toggleCommentLike(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, List<NotificationEntity>>>
      getNotifications() async {
    final result = await _remote.getNotifications();
    return result.fold(
      (error) => Left(error),
      (dtoList) {
        final entities = dtoList.map((dto) => dto.toEntity()).toList();
        return Right(entities);
      },
    );
  }

  @override
  Future<Either<DomainException, FeedStateEntity>> getFeedState() async {
    final result = await _remote.getFeedState();
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, FeedStateEntity>> syncFeedState(
    FeedStateSyncRequest request,
  ) async {
    final result = await _remote.syncFeedState(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, StoreSummaryEntity>> getStoreSummary() async {
    final balanceResult = await _remote.getEconomyBalance();
    DomainException? balanceError;
    EconomyBalanceDto? balanceDto;
    balanceResult.fold(
      (error) => balanceError = error,
      (dto) => balanceDto = dto,
    );
    if (balanceError != null) {
      return Left(balanceError!);
    }

    final limitsResult = await _remote.getEconomyLimits();
    DomainException? limitsError;
    EconomyLimitsDto? limitsDto;
    limitsResult.fold(
      (error) => limitsError = error,
      (dto) => limitsDto = dto,
    );
    if (limitsError != null) {
      return Left(limitsError!);
    }

    return Right(
      StoreSummaryEntity(
        balance: balanceDto!.toEntity(),
        limits: limitsDto!.toEntity(),
      ),
    );
  }

  @override
  Future<Either<DomainException, ClaimDailyAccrualResultEntity>>
      claimStoreDailyAccrual(
    ClaimDailyAccrualRequest request,
  ) async {
    final result = await _remote.claimDailyAccrual(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }
}
