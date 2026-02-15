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
}
