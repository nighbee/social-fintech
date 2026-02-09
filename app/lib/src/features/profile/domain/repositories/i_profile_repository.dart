import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

abstract interface class IProfileRepository {
  /// Get current user profile data
  Future<Either<DomainException, ProfileEntity>> getCurrentUser();

  /// Get public profile of another user by userId
  Future<Either<DomainException, ProfileEntity>> getPublicProfile(
    UserIdRequest request,
  );
}
