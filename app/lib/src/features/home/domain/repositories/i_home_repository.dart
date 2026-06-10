import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/entities/report_post_result_entity.dart';
import 'package:app/src/features/home/domain/entities/claim_daily_accrual_result_entity.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:app/src/features/home/domain/entities/seal_list_entity.dart';
import 'package:app/src/features/home/domain/entities/send_post_seal_result_entity.dart';
import 'package:app/src/features/home/domain/entities/status_response_entity.dart';
import 'package:app/src/features/home/domain/entities/store_summary_entity.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
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

abstract class IHomeRepository {
  Future<Either<DomainException, FeedEntity>> getFeed(FeedRequest request);
  Future<Either<DomainException, PostResponseEntity>> createFeedPost(
    CreatePostRequest request,
    List<LocalMediaPayload> localMediaPayloads,
  );
  Future<Either<DomainException, FeedEntity>> getProfilePostsGrid(
    GetProfilePostsRequest request,
  );
  Future<Either<DomainException, FeedEntity>> getMyProfilePostsList(
    GetMyProfilePostsRequest request,
  );
  Future<Either<DomainException, FeedEntity>> getProfilePostsList(
    GetProfilePostsRequest request,
  );
  Future<Either<DomainException, ThreadedCommentsEntity>> getPostComments(
    GetPostCommentsRequest request,
  );
  Future<Either<DomainException, CommentResponseEntity>> createPostComment(
    PostIdRequest requestId,
    CreateCommentRequest request,
  );
  Future<Either<DomainException, MediaAttachmentRequest>> uploadFeedMedia(
    UploadFeedMediaRequest request,
  );
  Future<Either<DomainException, InteractionListEntity>> getPostLikes(
    GetPostLikesRequest request,
  );
  Future<Either<DomainException, SealListEntity>> getPostSeals(
    GetPostSealsRequest request,
  );
  Future<Either<DomainException, PostResponseEntity>> togglePostLike(
    PostIdRequest request,
  );
  Future<Either<DomainException, StatusResponseEntity>> updatePost(
    PostIdRequest requestId,
    UpdatePostRequest request,
  );
  Future<Either<DomainException, StatusResponseEntity>> deletePost(
    PostIdRequest requestId,
  );
  Future<Either<DomainException, ReportPostResultEntity>> reportPost(
    PostIdRequest requestId,
    ReportPostRequest request,
  );
  Future<Either<DomainException, SendPostSealResultEntity>> sendPostSeal(
    PostIdRequest requestId,
    SendPostSealRequest request,
  );
  Future<Either<DomainException, CommentResponseEntity>> toggleCommentLike(
    CommentIdRequest request,
  );

  Future<Either<DomainException, List<NotificationEntity>>> getNotifications({
    String? tab,
  });
  Future<Either<DomainException, void>> markNotificationRead(
    String notificationId,
  );
  Future<Either<DomainException, void>> markAllNotificationsRead();
  Future<Either<DomainException, FeedStateEntity>> getFeedState();
  Future<Either<DomainException, FeedStateEntity>> syncFeedState(
    FeedStateSyncRequest request,
  );
  Future<Either<DomainException, StoreSummaryEntity>> getStoreSummary();
  Future<Either<DomainException, ClaimDailyAccrualResultEntity>>
      claimStoreDailyAccrual(
    ClaimDailyAccrualRequest request,
  );
}
