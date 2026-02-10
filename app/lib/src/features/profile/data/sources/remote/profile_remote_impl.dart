import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/ally_profile_dto.dart';
import 'package:app/src/features/profile/data/models/profile_dto.dart';
import 'package:app/src/features/profile/data/models/public_profile_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

@named
@LazySingleton(as: IProfileRemote)
class ProfileRemoteImpl implements IProfileRemote {
  ProfileRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, ProfileDto>> getCurrentUser() async {
    // TODO: Uncomment when API is ready
    try {
      final response = await _restClient.get(EndPoints.profile);

      return response.fold((error) => Left(error), (result) {
        final dto = ProfileDto.fromJson(result.data as Map<String, dynamic>);
        return Right(dto);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }

    // Mock data for development
    // await Future.delayed(const Duration(milliseconds: 500));
    // final mockUser = UserDto(
    //   id: 'mock-user-123',
    //   email: 'john.doe@example.com',
    //   username: 'johndoe',
    //   avatarUrl: 'https://i.pravatar.cc/150?img=12',
    //   createdAt: DateTime.now()
    //       .subtract(const Duration(days: 30))
    //       .toIso8601String(),
    // );
    // return Right(mockUser);
  }

  @override
  Future<Either<DomainException, PublicProfileDto>> getPublicProfile(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.profileById(request.userId),
      );

      return response.fold((error) => Left(error), (result) {
        final dto = PublicProfileDto.fromJson(
          result.data as Map<String, dynamic>,
        );
        return Right(dto);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> becomeAlly(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.profileAddAlly(request.userId),
        data: {},
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> removeAlly(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.delete(
        EndPoints.profileRemoveAlly(request.userId),
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<AllyProfileDto>>> getAllies(
    UserIdRequest request,
  ) async {
    try {
      final endpoint = request.userId == 'me'
          ? EndPoints.profileGetAllies('me')
          : EndPoints.profileGetAllies(request.userId);

      final response = await _restClient.get(endpoint);

      return response.fold((error) => Left(error), (result) {
        final List<dynamic> dataList = result.data as List<dynamic>;
        final List<AllyProfileDto> allies = dataList
            .map((json) => AllyProfileDto.fromJson(json as Map<String, dynamic>))
            .toList();

        return Right(allies);
      });
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> blockUser(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.profileBlock(request.userId),
        data: {},
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> restrictUser(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.profileRestrict(request.userId),
        data: {},
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> reportUser(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.profileReport(request.userId),
        data: {},
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> unblockUser(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.delete(
        EndPoints.profileUnblock(request.userId),
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> unrestrictUser(
    UserIdRequest request,
  ) async {
    try {
      final response = await _restClient.delete(
        EndPoints.profileUnrestrict(request.userId),
      );

      return response.fold(
        (error) => Left(error),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }
}
