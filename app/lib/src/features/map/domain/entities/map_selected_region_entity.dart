import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_selected_region_entity.freezed.dart';

@freezed
class MapSelectedRegionEntity extends BaseEntity with _$MapSelectedRegionEntity {
  const factory MapSelectedRegionEntity({
    required double latitude,
    required double longitude,
    required double zoom,
  }) = _MapSelectedRegionEntity;
}
