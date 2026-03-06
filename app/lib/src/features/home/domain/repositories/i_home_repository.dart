import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';

abstract class IHomeRepository {
  Future<Either<DomainException, List<PostEntity>>> getPosts();
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
