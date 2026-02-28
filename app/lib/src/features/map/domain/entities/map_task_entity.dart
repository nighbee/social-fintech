import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_entity.freezed.dart';

@freezed
class MapTaskEntity extends BaseEntity with _$MapTaskEntity {
  const factory MapTaskEntity({
    required String id,
    required String title,
    String? description,
    required double reward,
    required int workersNeeded,
    required int workersFilled,
    required String status,
    String? autoShutdownAt,
    required double latitude,
    required double longitude,
    required String createdAt,
  }) = _MapTaskEntity;
}
