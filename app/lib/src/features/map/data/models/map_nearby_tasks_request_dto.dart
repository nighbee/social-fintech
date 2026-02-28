import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_nearby_tasks_request_dto.freezed.dart';
part 'map_nearby_tasks_request_dto.g.dart';

@freezed
class MapNearbyTasksRequestDto extends BaseRequest
    with _$MapNearbyTasksRequestDto {
  const factory MapNearbyTasksRequestDto({
    required double lat,
    required double lon,
    @JsonKey(name: 'radius_m') @Default(2000) double radiusM,
    @Default(50) int limit,
  }) = _MapNearbyTasksRequestDto;

  factory MapNearbyTasksRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MapNearbyTasksRequestDtoFromJson(json);
}
