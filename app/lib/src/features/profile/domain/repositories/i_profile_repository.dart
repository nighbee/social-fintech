import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/public_profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

abstract interface class IProfileRepository {
  /// Get current user profile data
  Future<Either<DomainException, ProfileEntity>> getCurrentUser();

  /// Update current user profile data
  Future<Either<DomainException, ProfileEntity>> updateProfile(
    UpdateProfileRequest request,
  );

  /// Get public profile of another user by userId
  Future<Either<DomainException, PublicProfileEntity>> getPublicProfile(
    UserIdRequest request,
  );

  Future<Either<DomainException, void>> becomeAlly(UserIdRequest request);

  Future<Either<DomainException, void>> removeAlly(UserIdRequest request);

  Future<Either<DomainException, List<AllyProfileEntity>>> getAllies(
    UserIdRequest request,
  );

  Future<Either<DomainException, void>> blockUser(UserIdRequest request);

  Future<Either<DomainException, void>> unblockUser(UserIdRequest request);

  Future<Either<DomainException, void>> restrictUser(UserIdRequest request);

  Future<Either<DomainException, void>> unrestrictUser(UserIdRequest request);

  Future<Either<DomainException, void>> reportUser(UserIdRequest request);

  Future<Either<DomainException, RelationshipStatusEntity>> getRelationship(
    UserIdRequest request,
  );
}
