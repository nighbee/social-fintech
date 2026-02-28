import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_region_assignment_dto.freezed.dart';
part 'map_region_assignment_dto.g.dart';

@freezed
class MapRegionAssignmentDto extends BaseDto with _$MapRegionAssignmentDto {
  const MapRegionAssignmentDto._();
  const factory MapRegionAssignmentDto({
    @JsonKey(name: 'h3_res2', defaultValue: '') required String h3Res2,
    @JsonKey(name: 'h3_res4', defaultValue: '') required String h3Res4,
    @JsonKey(name: 'h3_res5', defaultValue: '') required String h3Res5,
    @JsonKey(name: 'location_opt_in', defaultValue: false)
    required bool locationOptIn,
    @JsonKey(name: 'participate_district', defaultValue: false)
    required bool participateDistrict,
    @JsonKey(name: 'updated_at', defaultValue: '') required String updatedAt,
  }) = _MapRegionAssignmentDto;

  factory MapRegionAssignmentDto.fromJson(Map<String, dynamic> json) =>
      _$MapRegionAssignmentDtoFromJson(json);

  MapRegionAssignmentEntity toEntity() {
    return MapRegionAssignmentEntity(
      h3Res2: h3Res2,
      h3Res4: h3Res4,
      h3Res5: h3Res5,
      locationOptIn: locationOptIn,
      participateDistrict: participateDistrict,
      updatedAt: updatedAt,
    );
  }
}
