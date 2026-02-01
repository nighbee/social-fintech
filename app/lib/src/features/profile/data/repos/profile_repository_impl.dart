import 'package:fpdart/fpdart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/exceptions/domain_exception.dart';
import '../../../../core/utils/loggers/log.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repos/i_profile_repository.dart';
import '../sources/i_profile_remote.dart';

@LazySingleton(as: IProfileRepository)
class ProfileRepositoryImpl implements IProfileRepository {
  ProfileRepositoryImpl(@Named('ProfileRemoteImpl') this._remote);

  final IProfileRemote _remote;

  @override
  Future<Either<DomainException, Profile>> getProfile(
      String username) async {
    try {
      final dto = await _remote.getProfile(username);
      return Right(dto.toDomain());
    } catch (e) {
      Log.error('ProfileRepository', 'getProfile error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, Profile>> getMyProfile() async {
    try {
      final dto = await _remote.getMyProfile();
      return Right(dto.toDomain());
    } catch (e) {
      Log.error('ProfileRepository', 'getMyProfile error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, Profile>> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    String? location,
    bool? isLocationPublic,
    bool? isProfilePublic,
  }) async {
    try {
      final dto = await _remote.updateProfile(
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        bio: bio,
        location: location,
        isLocationPublic: isLocationPublic,
        isProfilePublic: isProfilePublic,
      );
      return Right(dto.toDomain());
    } catch (e) {
      Log.error('ProfileRepository', 'updateProfile error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, String>> uploadAvatar(XFile file) async {
    try {
      final avatarUrl = await _remote.uploadAvatar(file);
      return Right(avatarUrl);
    } catch (e) {
      Log.error('ProfileRepository', 'uploadAvatar error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<Profile>>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final dtos = await _remote.searchProfiles(
        query: query,
        limit: limit,
        offset: offset,
      );
      final profiles = dtos.map((dto) => dto.toDomain()).toList();
      return Right(profiles);
    } catch (e) {
      Log.error('ProfileRepository', 'searchProfiles error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<Profile>>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      final dtos = await _remote.getNearbyProfiles(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        limit: limit,
      );
      final profiles = dtos.map((dto) => dto.toDomain()).toList();
      return Right(profiles);
    } catch (e) {
      Log.error('ProfileRepository', 'getNearbyProfiles error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> createRelationship({
    required String targetUserId,
    required RelationshipType type,
  }) async {
    try {
      await _remote.createRelationship(
        targetUserId: targetUserId,
        type: _relationshipTypeToString(type),
      );
      return right(null);
    } catch (e) {
      Log.error('ProfileRepository', 'createRelationship error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, void>> removeRelationship({
    required String targetUserId,
    required RelationshipType type,
  }) async {
    try {
      await _remote.removeRelationship(
        targetUserId: targetUserId,
        type: _relationshipTypeToString(type),
      );
      return right(null);
    } catch (e) {
      Log.error('ProfileRepository', 'removeRelationship error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<RelationshipResponse>>> getAllies({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final dtos = await _remote.getAllies(limit: limit, offset: offset);
      final relationships = dtos.map((dto) => dto.toDomain()).toList();
      return Right(relationships);
    } catch (e) {
      Log.error('ProfileRepository', 'getAllies error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<RelationshipResponse>>> getFavorites({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final dtos = await _remote.getFavorites(limit: limit, offset: offset);
      final relationships = dtos.map((dto) => dto.toDomain()).toList();
      return Right(relationships);
    } catch (e) {
      Log.error('ProfileRepository', 'getFavorites error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, String>> reportUser({
    required String reportedUserId,
    required ReportReason reason,
    String? description,
  }) async {
    try {
      final reportId = await _remote.reportUser(
        reportedUserId: reportedUserId,
        reason: _reportReasonToString(reason),
        description: description,
      );
      return Right(reportId);
    } catch (e) {
      Log.error('ProfileRepository', 'reportUser error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, List<UserReport>>> getMyReports({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final dtos = await _remote.getMyReports(limit: limit, offset: offset);
      final reports = dtos.map((dto) => dto.toDomain()).toList();
      return Right(reports);
    } catch (e) {
      Log.error('ProfileRepository', 'getMyReports error: $e');
      return Left(e is DomainException ? e : NetworkException(message: e.toString()));
    }
  }

  // Helper methods
  String _relationshipTypeToString(RelationshipType type) {
    switch (type) {
      case RelationshipType.ally:
        return 'ally';
      case RelationshipType.favorite:
        return 'favorite';
      case RelationshipType.block:
        return 'block';
      case RelationshipType.restrict:
        return 'restrict';
    }
  }

  String _reportReasonToString(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.inappropriate:
        return 'inappropriate';
      case ReportReason.fakeAccount:
        return 'fake_account';
      case ReportReason.other:
        return 'other';
    }
  }
}
