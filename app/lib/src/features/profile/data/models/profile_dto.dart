import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_dto.freezed.dart';
part 'profile_dto.g.dart';

@freezed
class ProfileDto extends BaseDto with _$ProfileDto {
  const ProfileDto._();
  const factory ProfileDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'date_of_birth') required String dateOfBirth,
    @JsonKey(name: 'bio') required String bio,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    @JsonKey(name: 'country') required String country,
    @JsonKey(name: 'city') required String city,
    @JsonKey(name: 'is_public') required bool isPublic,
    @JsonKey(name: 'reputation_score') required int reputationScore,
    @JsonKey(name: 'rank_tier') required String rankTier,
    // @JsonKey(name: 'created_at') required String createdAt,
    // @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _ProfileDto;

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  ProfileEntity toEntity() => ProfileEntity(
    userId: userId,
    displayName: displayName,
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: dateOfBirth,
    bio: bio,
    avatarUrl: avatarUrl,
    country: country,
    city: city,
    isPublic: isPublic,
    reputationScore: reputationScore,
    rankTier: rankTier,
    // createdAt: DateTime.parse(createdAt),
    // updatedAt: DateTime.parse(updatedAt),
  );
}
