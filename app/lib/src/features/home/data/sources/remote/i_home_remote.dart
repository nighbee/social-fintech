import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/comment_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';

abstract class IHomeRemote {
  Future<Either<DomainException, List<PostDto>>> getPosts();
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
}
