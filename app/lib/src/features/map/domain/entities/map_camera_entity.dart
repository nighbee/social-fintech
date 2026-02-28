import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_camera_entity.freezed.dart';

@freezed
class MapCameraEntity with _$MapCameraEntity {
  const factory MapCameraEntity({
    required double centerLatitude,
    required double centerLongitude,
    required double zoom,
  }) = _MapCameraEntity;
}
