import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_dto.freezed.dart';
part 'public_profile_dto.g.dart';

@freezed
class PublicProfileDto extends BaseDto with _$PublicProfileDto {
  const PublicProfileDto._();
  const factory PublicProfileDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'bio') required String bio,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    @JsonKey(name: 'country') required String country,
    @JsonKey(name: 'city') required String city,
    @JsonKey(name: 'region') required String region,
    @JsonKey(name: 'reputation_score') required int reputationScore,
    @JsonKey(name: 'rank_tier') required String rankTier,
  }) = _PublicProfileDto;

  factory PublicProfileDto.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileDtoFromJson(json);

  ProfileEntity toEntity() => ProfileEntity(
    userId: userId,
    displayName: displayName,
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: '', // Not available in public profile
    bio: bio,
    avatarUrl: avatarUrl,
    country: country,
    city: city,
    isPublic: true, // Public profile is always public
    reputationScore: reputationScore,
    rankTier: rankTier,
  );
}
