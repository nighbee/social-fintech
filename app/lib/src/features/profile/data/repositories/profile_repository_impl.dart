import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/data/sources/remote/profile_remote_impl.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';

import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/public_profile_entity.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';

@named
@LazySingleton(as: IProfileRepository)
class ProfileRepositoryImpl implements IProfileRepository {
  ProfileRepositoryImpl(@Named.from(ProfileRemoteImpl) this._profileRemote);

  final IProfileRemote _profileRemote;

  @override
  Future<Either<DomainException, ProfileEntity>> getCurrentUser() async {
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

  @override
  Future<Either<DomainException, ProfileEntity>> updateProfile(
    UpdateProfileRequest request,
  ) async {
    try {
      final result = await _profileRemote.updateProfile(request);

      return result.fold(
        (error) => Left(error),
        (profileDto) => Right(profileDto.toEntity()),
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, PublicProfileEntity>> getPublicProfile(
    UserIdRequest request,
  ) async {
    try {
      final result = await _profileRemote.getPublicProfile(request);

      return result.fold(
        (error) => Left(error),
        (publicProfileDto) => Right(publicProfileDto.toEntity()),
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> becomeAlly(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.becomeAlly(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> removeAlly(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.removeAlly(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<AllyProfileEntity>>> getAllies(
    UserIdRequest request,
  ) async {
    try {
      final result = await _profileRemote.getAllies(request);

      return result.fold((error) => Left(error), (alliesDtoList) {
        final List<AllyProfileEntity> entities = alliesDtoList
            .map((dto) => dto.toEntity())
            .toList();
        return Right(entities);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> blockUser(UserIdRequest request) async {
    try {
      return await _profileRemote.blockUser(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> restrictUser(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.restrictUser(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> reportUser(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.reportUser(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> unblockUser(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.unblockUser(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, void>> unrestrictUser(
    UserIdRequest request,
  ) async {
    try {
      return await _profileRemote.unrestrictUser(request);
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, RelationshipStatusEntity>> getRelationship(
    UserIdRequest request,
  ) async {
    try {
      final result = await _profileRemote.getRelationship(request);

      return result.fold(
        (error) => Left(error),
        (relationshipDto) => Right(relationshipDto.toEntity()),
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }
}
