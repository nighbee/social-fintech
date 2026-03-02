import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_champion_entity.freezed.dart';

@freezed
class MapChampionEntity extends BaseEntity with _$MapChampionEntity {
  const factory MapChampionEntity({
    required String h3Index,
    required int resolution,
    required int score,
    required String userId,
  }) = _MapChampionEntity;

  const factory MapChampionEntity.empty({
    @Default('') String h3Index,
    @Default(0) int resolution,
    @Default(0) int score,
    @Default('') String userId,
  }) = _MapChampionEntityEmpty;
}
