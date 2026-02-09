import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/profile_dto.dart';
import 'package:app/src/features/profile/data/models/public_profile_dto.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

abstract interface class IProfileRemote {
  Future<Either<DomainException, ProfileDto>> getCurrentUser();
  Future<Either<DomainException, PublicProfileDto>> getPublicProfile(
    UserIdRequest request,
  );
}
