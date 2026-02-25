import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/sources/remote/home_remote_impl.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
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
}
