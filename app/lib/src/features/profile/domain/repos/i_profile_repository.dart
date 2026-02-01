import 'package:fpdart/fpdart.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/domain_exception.dart';
import '../entities/profile.dart';

/// Profile repository interface
abstract class IProfileRepository {
  /// Get profile by username
  Future<Either<DomainException, Profile>> getProfile(String username);

  /// Get current user's profile
  Future<Either<DomainException, Profile>> getMyProfile();

  /// Update current user's profile
  Future<Either<DomainException, Profile>> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    String? location,
    bool? isLocationPublic,
    bool? isProfilePublic,
  });

  /// Upload avatar
  Future<Either<DomainException, String>> uploadAvatar(XFile file);

  /// Search profiles
  Future<Either<DomainException, List<Profile>>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  /// Get nearby profiles
  Future<Either<DomainException, List<Profile>>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int limit = 20,
  });

  /// Create relationship (ally, favorite, block, restrict)
  Future<Either<DomainException, void>> createRelationship({
    required String targetUserId,
    required RelationshipType type,
  });

  /// Remove relationship
  Future<Either<DomainException, void>> removeRelationship({
    required String targetUserId,
    required RelationshipType type,
  });

  /// Get allies list
  Future<Either<DomainException, List<RelationshipResponse>>> getAllies({
    int limit = 20,
    int offset = 0,
  });

  /// Get favorites list
  Future<Either<DomainException, List<RelationshipResponse>>> getFavorites({
    int limit = 20,
    int offset = 0,
  });

  /// Report user
  Future<Either<DomainException, String>> reportUser({
    required String reportedUserId,
    required ReportReason reason,
    String? description,
  });

  /// Get my reports
  Future<Either<DomainException, List<UserReport>>> getMyReports({
    int limit = 10,
    int offset = 0,
  });
}
