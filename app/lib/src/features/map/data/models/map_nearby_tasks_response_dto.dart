import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/data/models/map_task_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_nearby_tasks_response_dto.freezed.dart';
part 'map_nearby_tasks_response_dto.g.dart';

@freezed
class MapNearbyTasksResponseDto extends BaseDto
    with _$MapNearbyTasksResponseDto {
  const MapNearbyTasksResponseDto._();

  const factory MapNearbyTasksResponseDto({
    @JsonKey(name: 'tasks', defaultValue: <MapTaskDto>[])
    required List<MapTaskDto> tasks,
  }) = _MapNearbyTasksResponseDto;

  factory MapNearbyTasksResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapNearbyTasksResponseDtoFromJson(json);
}
