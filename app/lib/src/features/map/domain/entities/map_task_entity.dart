import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_entity.freezed.dart';

@freezed
class MapTaskEntity extends BaseEntity with _$MapTaskEntity {
  const factory MapTaskEntity({
    required String id,
    required String title,
    @Default('') String description,
    required double reward,
    required int workersNeeded,
    required int workersFilled,
    required String status,
    @Default('') String autoShutdownAt,
    required double latitude,
    required double longitude,
    required String createdAt,
  }) = _MapTaskEntity;

  const factory MapTaskEntity.empty({
    @Default('') String id,
    @Default('') String title,
    @Default('') String description,
    @Default(0.0) double reward,
    @Default(0) int workersNeeded,
    @Default(0) int workersFilled,
    @Default('') String status,
    @Default('') String autoShutdownAt,
    @Default(0.0) double latitude,
    @Default(0.0) double longitude,
    @Default('') String createdAt,
  }) = _MapTaskEntityEmpty;
}
