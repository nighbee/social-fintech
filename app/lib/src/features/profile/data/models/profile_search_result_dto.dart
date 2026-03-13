import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/profile_search_result_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_search_result_dto.freezed.dart';
part 'profile_search_result_dto.g.dart';

@freezed
class ProfileSearchResultDto extends BaseDto with _$ProfileSearchResultDto {
  const ProfileSearchResultDto._();

  const factory ProfileSearchResultDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    @JsonKey(name: 'reputation_score') required int reputationScore,
    @JsonKey(name: 'rank_tier') required String rankTier,
  }) = _ProfileSearchResultDto;

  factory ProfileSearchResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileSearchResultDtoFromJson(json);

  ProfileSearchResultEntity toEntity() => ProfileSearchResultEntity(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    reputationScore: reputationScore,
    rankTier: rankTier,
  );
}
