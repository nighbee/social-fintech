import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:app/src/features/profile/domain/entities/profile_search_result_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_search_recent_item_entity.freezed.dart';
part 'profile_search_recent_item_entity.g.dart';

@freezed
class ProfileSearchRecentItemEntity extends BaseEntity
    with _$ProfileSearchRecentItemEntity {
  const ProfileSearchRecentItemEntity._();

  const factory ProfileSearchRecentItemEntity({
    required ProfileSearchResultEntity profile,
    required DateTime searchedAt,
  }) = _ProfileSearchRecentItemEntity;

  factory ProfileSearchRecentItemEntity.empty() => ProfileSearchRecentItemEntity(
        profile: const ProfileSearchResultEntity.empty(),
        searchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory ProfileSearchRecentItemEntity.fromJson(Map<String, dynamic> json) =>
      _$ProfileSearchRecentItemEntityFromJson(json);
}
