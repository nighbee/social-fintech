import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/datasources/i_profile_remote.dart';
import 'package:app/src/features/profile/data/datasources/profile_remote_impl.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:app/src/features/profile/domain/repos/i_profile_repo.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IProfileRepo)
class ProfileRepositoryImpl implements IProfileRepo {
  ProfileRepositoryImpl(@Named.from(ProfileRemoteImpl) this._profileRemote);

  final IProfileRemote _profileRemote;

  @override
  Future<Either<DomainException, User>> getProfile() async {
    try {
      final result = await _profileRemote.getProfile();

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
