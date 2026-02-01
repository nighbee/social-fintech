import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/api/client/dio/rest_client.dart';
import '../../../../core/api/client/endpoints.dart';
import '../../../../core/utils/loggers/log.dart';
import '../models/profile_dto.dart';
import '../models/relationship_dto.dart';
import '../models/report_dto.dart';
import 'i_profile_remote.dart';

@named
@LazySingleton(as: IProfileRemote)
class ProfileRemoteImpl implements IProfileRemote {
  ProfileRemoteImpl(@Named('DioClient') this._client);

  final RestClient _client;

  @override
  Future<ProfileDto> getProfile(String username) async {
    final result = await _client.get(EndPoints.profileByUsername(username));
    return result.fold(
      (error) => throw error,
      (response) => ProfileDto.fromJson(response.data as Map<String, dynamic>),
    );
  }

  @override
  Future<ProfileDto> getMyProfile() async {
    final result = await _client.get(EndPoints.profileMe);
    return result.fold(
      (error) => throw error,
      (response) => ProfileDto.fromJson(response.data as Map<String, dynamic>),
    );
  }

  @override
  Future<ProfileDto> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    String? location,
    bool? isLocationPublic,
    bool? isProfilePublic,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (bio != null) data['bio'] = bio;
    if (location != null) {
      // Split location into city and country if comma-separated
      final parts = location.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        data['location_city'] = parts[0];
        data['location_country'] = parts.sublist(1).join(', ');
      } else {
        data['location_city'] = location;
      }
    }
    if (isLocationPublic != null) data['is_location_public'] = isLocationPublic;
    if (isProfilePublic != null) data['is_profile_public'] = isProfilePublic;

    final result = await _client.put(EndPoints.profileMe, data: data);
    return result.fold(
      (error) => throw error,
      (response) => ProfileDto.fromJson(response.data as Map<String, dynamic>),
    );
  }

  @override
  Future<String> uploadAvatar(XFile file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final result = await _client.post(
        EndPoints.profileMeAvatar,
        data: formData,
      );

      return result.fold(
        (error) => throw error,
        (response) {
          final data = response.data as Map<String, dynamic>;
          return data['avatar_url'] as String;
        },
      );
    } catch (e) {
      Log.error('ProfileRemoteImpl', 'Error uploading avatar: $e');
      rethrow;
    }
  }

  @override
  Future<List<ProfileDto>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await _client.get(
      EndPoints.profileSearch,
      queryParameters: {
        'q': query,
        'limit': limit,
        'offset': offset,
      },
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ProfileDto.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  @override
  Future<List<ProfileDto>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int limit = 20,
  }) async {
    final result = await _client.get(
      EndPoints.profileNearby,
      queryParameters: {
        'lat': latitude,
        'lon': longitude,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ProfileDto.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  @override
  Future<void> createRelationship({
    required String targetUserId,
    required String type,
  }) async {
    final result = await _client.post(
      EndPoints.profileRelationships,
      data: {
        'target_user_id': targetUserId,
        'type': type,
      },
    );

    result.fold(
      (error) => throw error,
      (response) => null,
    );
  }

  @override
  Future<void> removeRelationship({
    required String targetUserId,
    required String type,
  }) async {
    final result = await _client.delete(
      EndPoints.profileRelationships,
      queryParameters: {
        'target_user_id': targetUserId,
        'type': type,
      },
    );

    result.fold(
      (error) => throw error,
      (response) => null,
    );
  }

  @override
  Future<List<RelationshipDto>> getAllies({
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await _client.get(
      EndPoints.profileAllies,
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                RelationshipDto.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  @override
  Future<List<RelationshipDto>> getFavorites({
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await _client.get(
      EndPoints.profileFavorites,
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                RelationshipDto.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  @override
  Future<String> reportUser({
    required String reportedUserId,
    required String reason,
    String? description,
  }) async {
    final data = <String, dynamic>{
      'reported_user_id': reportedUserId,
      'reason': reason,
    };
    if (description != null) data['description'] = description;

    final result = await _client.post(
      EndPoints.profileReports,
      data: data,
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final responseData = response.data as Map<String, dynamic>;
        return responseData['id'] as String;
      },
    );
  }

  @override
  Future<List<ReportDto>> getMyReports({
    int limit = 10,
    int offset = 0,
  }) async {
    final result = await _client.get(
      EndPoints.profileReportsMe,
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    return result.fold(
      (error) => throw error,
      (response) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => ReportDto.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }
}
