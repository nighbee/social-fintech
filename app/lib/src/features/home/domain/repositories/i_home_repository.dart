import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/status_response_entity.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';

abstract class IHomeRepository {
  Future<Either<DomainException, List<PostEntity>>> getPosts();
  Future<Either<DomainException, FeedEntity>> getFeed(FeedRequest request);
  Future<Either<DomainException, StatusResponseEntity>> createFeedPost(
    CreatePostRequest request,
  );
  Future<Either<DomainException, ThreadedCommentsEntity>> getPostComments(
    GetPostCommentsRequest request,
  );
  Future<Either<DomainException, StatusResponseEntity>> createPostComment(
    String postId,
    CreateCommentRequest request,
  );
  Future<Either<DomainException, InteractionListEntity>> getPostLikes(
    GetPostLikesRequest request,
  );
  Future<Either<DomainException, StatusResponseEntity>> togglePostLike(
    String postId,
  );
  Future<Either<DomainException, PostEntity>> createPost(
    String content,
    List<String> imageFileNames,
  );
  Future<Either<DomainException, PostEntity>> likePost(String postId);
  Future<Either<DomainException, PostEntity>> unlikePost(String postId);
  Future<Either<DomainException, List<CommentEntity>>> getComments(
    String postId,
  );
  Future<Either<DomainException, CommentEntity>> addComment(
    String postId,
    String content,
    String? parentCommentId,
    List<String> imageFileNames,
  );
  Future<Either<DomainException, CommentEntity>> likeComment(String commentId);
  Future<Either<DomainException, CommentEntity>> unlikeComment(
      String commentId);

  Future<Either<DomainException, List<NotificationEntity>>> getNotifications();
  Future<Either<DomainException, FeedStateEntity>> getFeedState();
  Future<Either<DomainException, FeedStateEntity>> syncFeedState(
    FeedStateSyncRequest request,
  );
}
