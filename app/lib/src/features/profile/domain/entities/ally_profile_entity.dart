import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/core/base/base_models/base_entity.dart';

part 'ally_profile_entity.freezed.dart';
part 'ally_profile_entity.g.dart';

@freezed
class AllyProfileEntity extends BaseEntity with _$AllyProfileEntity {
  const factory AllyProfileEntity({
    required String userId,
    required String displayName,
    required String avatarUrl,
    required String rankTier,
    required int reputationScore,
  }) = _AllyProfileEntity;

  const factory AllyProfileEntity.empty({
    @Default('') String userId,
    @Default('') String displayName,
    @Default('') String avatarUrl,
    @Default('') String rankTier,
    @Default(0) int reputationScore,
  }) = _AllyProfileEntityEmpty;

  factory AllyProfileEntity.fromJson(Map<String, dynamic> json) =>
      _$AllyProfileEntityFromJson(json);
}
