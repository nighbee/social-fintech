import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_camera_entity.freezed.dart';

@freezed
class MapCameraEntity with _$MapCameraEntity {
  const factory MapCameraEntity({
    required double centerLatitude,
    required double centerLongitude,
    required double zoom,
  }) = _MapCameraEntity;

  const factory MapCameraEntity.empty({
    @Default(0.0) double centerLatitude,
    @Default(0.0) double centerLongitude,
    @Default(0.0) double zoom,
  }) = _MapCameraEntityEmpty;
}
