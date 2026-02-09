import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
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
      final response = await _restClient.get('/profiles/${request.userId}');

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
}
