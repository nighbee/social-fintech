import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_region_assignment_request.freezed.dart';
part 'map_region_assignment_request.g.dart';

@freezed
class MapRegionAssignmentRequest with _$MapRegionAssignmentRequest {
  const factory MapRegionAssignmentRequest({
    required double latitude,
    required double longitude,
    @Default(true) @JsonKey(name: 'location_opt_in') bool locationOptIn,
    @Default(true)
    @JsonKey(name: 'participate_district')
    bool participateDistrict,
  }) = _MapRegionAssignmentRequest;

  factory MapRegionAssignmentRequest.fromJson(Map<String, dynamic> json) =>
      _$MapRegionAssignmentRequestFromJson(json);
}
