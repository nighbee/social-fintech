import 'package:image_picker/image_picker.dart';
import '../models/profile_dto.dart';
import '../models/relationship_dto.dart';
import '../models/report_dto.dart';

/// Profile remote datasource interface
abstract class IProfileRemote {
  /// Get profile by username
  Future<ProfileDto> getProfile(String username);

  /// Get current user's profile
  Future<ProfileDto> getMyProfile();

  /// Update profile
  Future<ProfileDto> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    String? location,
    bool? isLocationPublic,
    bool? isProfilePublic,
  });

  /// Upload avatar
  Future<String> uploadAvatar(XFile file);

  /// Search profiles
  Future<List<ProfileDto>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  /// Get nearby profiles
  Future<List<ProfileDto>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int limit = 20,
  });

  /// Create relationship
  Future<void> createRelationship({
    required String targetUserId,
    required String type,
  });

  /// Remove relationship
  Future<void> removeRelationship({
    required String targetUserId,
    required String type,
  });

  /// Get allies
  Future<List<RelationshipDto>> getAllies({
    int limit = 20,
    int offset = 0,
  });

  /// Get favorites
  Future<List<RelationshipDto>> getFavorites({
    int limit = 20,
    int offset = 0,
  });

  /// Report user
  Future<String> reportUser({
    required String reportedUserId,
    required String reason,
    String? description,
  });

  /// Get my reports
  Future<List<ReportDto>> getMyReports({
    int limit = 10,
    int offset = 0,
  });
}
