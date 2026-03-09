import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/comment_dto.dart';
import 'package:app/src/features/home/data/models/feed_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/data/models/interaction_list_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';
import 'package:app/src/features/home/data/models/status_response_dto.dart';
import 'package:app/src/features/home/data/models/threaded_comments_dto.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';

abstract class IHomeRemote {
  Future<Either<DomainException, List<PostDto>>> getPosts();
  Future<Either<DomainException, FeedDto>> getFeed(FeedRequest request);
  Future<Either<DomainException, StatusResponseDto>> createFeedPost(
    CreatePostRequest request,
  );
  Future<Either<DomainException, ThreadedCommentsDto>> getPostComments(
    GetPostCommentsRequest request,
  );
  Future<Either<DomainException, StatusResponseDto>> createPostComment(
    String postId,
    CreateCommentRequest request,
  );
  Future<Either<DomainException, InteractionListDto>> getPostLikes(
    GetPostLikesRequest request,
  );
  Future<Either<DomainException, StatusResponseDto>> togglePostLike(
    String postId,
  );
  Future<Either<DomainException, PostDto>> createPost(
    String content,
    List<String> imageFileNames,
  );
  Future<Either<DomainException, PostDto>> likePost(String postId);
  Future<Either<DomainException, PostDto>> unlikePost(String postId);
  Future<Either<DomainException, List<CommentDto>>> getComments(String postId);
  Future<Either<DomainException, CommentDto>> addComment(
    String postId,
    String content,
    String? parentCommentId,
    List<String> imageFileNames,
  );
  Future<Either<DomainException, CommentDto>> likeComment(String commentId);
  Future<Either<DomainException, CommentDto>> unlikeComment(String commentId);

  // Notifications
  Future<Either<DomainException, List<NotificationDto>>> getNotifications();

  // Feed state
  Future<Either<DomainException, FeedStateDto>> getFeedState();
  Future<Either<DomainException, FeedStateDto>> syncFeedState(
    FeedStateSyncRequest request,
  );
}
