import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile.dart';
import 'profile_stats_dto.dart';

part 'profile_dto.freezed.dart';
part 'profile_dto.g.dart';

@freezed
class UserDto with _$UserDto {
  const factory UserDto({
    required String username,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
}

@freezed
class ProfileDto with _$ProfileDto {
  const factory ProfileDto({
    @JsonKey(name: 'user_id') required String userId,
    required UserDto user, // Nested user object
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    String? bio,
    String? location, // Single string from backend
    @JsonKey(name: 'is_location_public') @Default(false) bool isLocationPublic,
    @JsonKey(name: 'is_profile_public') @Default(true) bool isProfilePublic,
    ProfileStatsDto? stats,
    @JsonKey(name: 'current_rank_tier') required String currentRankTier,
    @JsonKey(name: 'reputation_score') @Default(0) int reputationScore,
    @JsonKey(name: 'silver_seals') @Default(0) int silverSeals,
    @JsonKey(name: 'gold_seals') @Default(0) int goldSeals,
    @JsonKey(name: 'is_active_donor') @Default(false) bool isActiveDonor,
    @JsonKey(name: 'is_ally') @Default(false) bool isAlly,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'is_blocked') @Default(false) bool isBlocked,
    @JsonKey(name: 'is_own') @Default(false) bool isOwn,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ProfileDto;

  const ProfileDto._();

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Profile toDomain() {
    return Profile(
      userId: userId,
      username: user.username,
      displayName: displayName,
      firstName: user.firstName ?? '',
      lastName: user.lastName ?? '',
      avatarUrl: avatarUrl ?? '',
      bio: bio,
      location: location,
      locationCity: null, // Deprecated/Not sent by backend
      locationCountry: null, // Deprecated/Not sent by backend
      isLocationPublic: isLocationPublic,
      isProfilePublic: isProfilePublic,
      stats: stats?.toDomain(),
      currentRankTier: currentRankTier,
      reputationScore: reputationScore,
      silverSeals: silverSeals,
      goldSeals: goldSeals,
      isActiveDonor: isActiveDonor,
      isAlly: isAlly,
      isFavorite: isFavorite,
      isBlocked: isBlocked,
      isOwn: isOwn,
      createdAt: createdAt,
    );
  }
}
