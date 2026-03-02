import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_nearby_tasks_request.freezed.dart';
part 'map_nearby_tasks_request.g.dart';

@freezed
class MapNearbyTasksRequest extends BaseRequest with _$MapNearbyTasksRequest {
  const factory MapNearbyTasksRequest({
    required double lat,
    required double lon,
    @JsonKey(name: 'radius_m') @Default(2000) double radiusM,
    @Default(50) int limit,
  }) = _MapNearbyTasksRequest;

  factory MapNearbyTasksRequest.fromJson(Map<String, dynamic> json) =>
      _$MapNearbyTasksRequestFromJson(json);
}
