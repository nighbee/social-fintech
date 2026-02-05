import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/data/sources/remote/profile_remote_impl.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';

@named
@LazySingleton(as: IProfileRepository)
class ProfileRepositoryImpl implements IProfileRepository {
  ProfileRepositoryImpl(@Named.from(ProfileRemoteImpl) this._profileRemote);

  final IProfileRemote _profileRemote;

  @override
  Future<Either<DomainException, User>> getCurrentUser() async {
    try {
      final result = await _profileRemote.getCurrentUser();

      return result.fold(
        (error) => Left(error),
        (userDto) => Right(userDto.toEntity()),
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }
}
