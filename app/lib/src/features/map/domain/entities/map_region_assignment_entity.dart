import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_region_assignment_entity.freezed.dart';

@freezed
class MapRegionAssignmentEntity extends BaseEntity
    with _$MapRegionAssignmentEntity {
  const factory MapRegionAssignmentEntity({
    required String h3Res2,
    required String h3Res4,
    required String h3Res5,
    required bool locationOptIn,
    required bool participateDistrict,
    required String updatedAt,
  }) = _MapRegionAssignmentEntity;

  const factory MapRegionAssignmentEntity.empty({
    @Default('') String h3Res2,
    @Default('') String h3Res4,
    @Default('') String h3Res5,
    @Default(false) bool locationOptIn,
    @Default(false) bool participateDistrict,
    @Default('') String updatedAt,
  }) = _MapRegionAssignmentEntityEmpty;
}
