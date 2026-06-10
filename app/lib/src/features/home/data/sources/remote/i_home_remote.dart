import 'package:fpdart/fpdart.dart';
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
import 'package:app/src/features/home/data/models/status_response_dto.dart';
import 'package:app/src/features/home/data/models/threaded_comments_dto.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/comment_id_request.dart';
import 'package:app/src/features/home/domain/requests/claim_daily_accrual_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
import 'package:app/src/features/home/domain/requests/get_my_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/domain/requests/update_post_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:dio/dio.dart';

abstract class IHomeRemote {
  Future<Either<DomainException, FeedDto>> getFeed(FeedRequest request);
  Future<Either<DomainException, PostResponseDto>> createFeedPost(
    CreatePostRequest request, {
    FormData? formData,
    List<LocalMediaPayload> localMediaPayloads,
  });
  Future<Either<DomainException, FeedDto>> getProfilePostsGrid(
    GetProfilePostsRequest request,
  );
  Future<Either<DomainException, FeedDto>> getMyProfilePostsList(
    GetMyProfilePostsRequest request,
  );
  Future<Either<DomainException, FeedDto>> getProfilePostsList(
    GetProfilePostsRequest request,
  );
  Future<Either<DomainException, ThreadedCommentsDto>> getPostComments(
    GetPostCommentsRequest request,
  );
  Future<Either<DomainException, CommentResponseDto>> createPostComment(
    PostIdRequest requestId,
    CreateCommentRequest request,
  );
  Future<Either<DomainException, MediaAttachmentRequest>> uploadFeedMedia(
    UploadFeedMediaRequest request,
  );
  Future<Either<DomainException, InteractionListDto>> getPostLikes(
    GetPostLikesRequest request,
  );
  Future<Either<DomainException, SealListDto>> getPostSeals(
    GetPostSealsRequest request,
  );
  Future<Either<DomainException, EconomyBalanceDto>> getEconomyBalance();
  Future<Either<DomainException, EconomyLimitsDto>> getEconomyLimits();
  Future<Either<DomainException, PostResponseDto>> togglePostLike(
    PostIdRequest request,
  );
  Future<Either<DomainException, StatusResponseDto>> updatePost(
    PostIdRequest requestId,
    UpdatePostRequest request,
  );
  Future<Either<DomainException, StatusResponseDto>> deletePost(
    PostIdRequest requestId,
  );
  Future<Either<DomainException, ReportPostResultDto>> reportPost(
    PostIdRequest requestId,
    ReportPostRequest request,
  );
  Future<Either<DomainException, SendPostSealResultDto>> sendPostSeal(
    PostIdRequest requestId,
    SendPostSealRequest request,
  );
  Future<Either<DomainException, ClaimDailyAccrualResultDto>> claimDailyAccrual(
    ClaimDailyAccrualRequest request,
  );
  Future<Either<DomainException, CommentResponseDto>> toggleCommentLike(
    CommentIdRequest request,
  );

  // Notifications
  Future<Either<DomainException, List<NotificationDto>>> getNotifications({
    String? tab,
  });
  Future<Either<DomainException, void>> markNotificationRead(
    String notificationId,
  );
  Future<Either<DomainException, void>> markAllNotificationsRead();

  // Feed state
  Future<Either<DomainException, FeedStateDto>> getFeedState();
  Future<Either<DomainException, FeedStateDto>> syncFeedState(
    FeedStateSyncRequest request,
  );
}
