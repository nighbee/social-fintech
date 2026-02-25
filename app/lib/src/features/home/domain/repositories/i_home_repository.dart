import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';

abstract class IHomeRepository {
  Future<Either<DomainException, List<PostEntity>>> getPosts();
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
  Future<Either<DomainException, CommentEntity>> unlikeComment(String commentId);
}
