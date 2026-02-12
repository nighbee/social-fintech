import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ally_profile_dto.freezed.dart';
part 'ally_profile_dto.g.dart';

@freezed
class AllyProfileDto extends BaseDto with _$AllyProfileDto {
  const AllyProfileDto._();
  const factory AllyProfileDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    @JsonKey(name: 'rank_tier') required String rankTier,
    @JsonKey(name: 'reputation_score') required int reputationScore,
  }) = _AllyProfileDto;

  factory AllyProfileDto.fromJson(Map<String, dynamic> json) =>
      _$AllyProfileDtoFromJson(json);

  AllyProfileEntity toEntity() => AllyProfileEntity(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        rankTier: rankTier,
        reputationScore: reputationScore,
      );
}
