import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/status_response_entity.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/sources/remote/home_remote_impl.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';

@named
@LazySingleton(as: IHomeRepository)
class HomeRepositoryImpl implements IHomeRepository {
  HomeRepositoryImpl(@Named.from(HomeRemoteImpl) this._remote);

  final IHomeRemote _remote;

  @override
  Future<Either<DomainException, List<PostEntity>>> getPosts() async {
    final result = await _remote.getPosts();
    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

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
  Future<Either<DomainException, StatusResponseEntity>> createFeedPost(
    CreatePostRequest request,
  ) async {
    final result = await _remote.createFeedPost(request);
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
  Future<Either<DomainException, StatusResponseEntity>> createPostComment(
    String postId,
    CreateCommentRequest request,
  ) async {
    final result = await _remote.createPostComment(postId, request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
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
  Future<Either<DomainException, StatusResponseEntity>> togglePostLike(
    String postId,
  ) async {
    final result = await _remote.togglePostLike(postId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, PostEntity>> createPost(
    String content,
    List<String> imageFileNames,
  ) async {
    final result = await _remote.createPost(content, imageFileNames);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, PostEntity>> likePost(String postId) async {
    final result = await _remote.likePost(postId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, PostEntity>> unlikePost(String postId) async {
    final result = await _remote.unlikePost(postId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, List<CommentEntity>>> getComments(
    String postId,
  ) async {
    final result = await _remote.getComments(postId);
    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, CommentEntity>> addComment(
    String postId,
    String content,
    String? parentCommentId,
    List<String> imageFileNames,
  ) async {
    final result = await _remote.addComment(
      postId,
      content,
      parentCommentId,
      imageFileNames,
    );
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, CommentEntity>> likeComment(
    String commentId,
  ) async {
    final result = await _remote.likeComment(commentId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, CommentEntity>> unlikeComment(
    String commentId,
  ) async {
    final result = await _remote.unlikeComment(commentId);
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
}
