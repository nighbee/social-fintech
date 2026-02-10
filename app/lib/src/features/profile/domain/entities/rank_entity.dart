import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/core/base/base_models/base_entity.dart';

part 'rank_entity.freezed.dart';
part 'rank_entity.g.dart';

@freezed
class RankEntity extends BaseEntity with _$RankEntity {
  const factory RankEntity({
    required int level,
    required String name,
    required String tier,
    required String description,
    required int requiredExp,
    required String imagePath,
    @Default(['C', 'B', 'A', 'S']) List<String> tierBadges,
  }) = _RankEntity;

  factory RankEntity.fromJson(Map<String, dynamic> json) =>
      _$RankEntityFromJson(json);
}
