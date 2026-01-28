import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/base/base_models/item_response.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/user_dto.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import 'i_profile_remote.dart';

@named
@LazySingleton(as: IProfileRemote)
class ProfileRemoteImpl implements IProfileRemote {
  ProfileRemoteImpl(@Named.from(DioClient) this._dioClient);

  final RestClient _dioClient;

  @override
  Future<Either<DomainException, UserDto>> getProfile() async {
    try {
      final response = await _dioClient.get(
        EndPoints.profile,
        // queryParameters: request.toQueryParameters(),
      );

      return response.fold((error) => Right(_mockUser()), (result) {
        final dto = ItemResponse<UserDto>.fromJson(
          result.data,
          (json) => UserDto.fromJson(json as Map<String, dynamic>),
        );
        return Right(dto.data);
      });
    } catch (e) {
      return Right(_mockUser());
    }
  }

  UserDto _mockUser() {
    return const UserDto(
      id: 1,
      email: 'demo@brightbund.app',
      phone: '+7 777 000 00 00',
      firstName: 'Ayaulym',
      lastName: 'Yesmoldayeva',
    );
  }
}
