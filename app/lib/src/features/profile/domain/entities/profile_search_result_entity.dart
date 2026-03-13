import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_search_result_entity.freezed.dart';
part 'profile_search_result_entity.g.dart';

@freezed
class ProfileSearchResultEntity extends BaseEntity
    with _$ProfileSearchResultEntity {
  const factory ProfileSearchResultEntity({
    required String userId,
    required String displayName,
    required String avatarUrl,
    required int reputationScore,
    required String rankTier,
  }) = _ProfileSearchResultEntity;

  const factory ProfileSearchResultEntity.empty({
    @Default('') String userId,
    @Default('') String displayName,
    @Default('') String avatarUrl,
    @Default(0) int reputationScore,
    @Default('') String rankTier,
  }) = _ProfileSearchResultEntityEmpty;

  factory ProfileSearchResultEntity.fromJson(Map<String, dynamic> json) =>
      _$ProfileSearchResultEntityFromJson(json);
}
