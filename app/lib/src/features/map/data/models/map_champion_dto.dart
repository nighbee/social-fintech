import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_champion_dto.freezed.dart';
part 'map_champion_dto.g.dart';

@freezed
class MapChampionDto extends BaseDto with _$MapChampionDto {
  const MapChampionDto._();
  const factory MapChampionDto({
    @JsonKey(name: 'h3_index', defaultValue: '') required String h3Index,
    @JsonKey(name: 'resolution', defaultValue: 0) required int resolution,
    @JsonKey(name: 'score', defaultValue: 0) required int score,
    @JsonKey(name: 'user_id', defaultValue: '') required String userId,
  }) = _MapChampionDto;

  factory MapChampionDto.fromJson(Map<String, dynamic> json) =>
      _$MapChampionDtoFromJson(json);

  MapChampionEntity toEntity() {
    return MapChampionEntity(
      h3Index: h3Index,
      resolution: resolution,
      score: score,
      userId: userId,
    );
  }
}
