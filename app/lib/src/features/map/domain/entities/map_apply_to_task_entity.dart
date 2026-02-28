import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_apply_to_task_entity.freezed.dart';

@freezed
class MapApplyToTaskEntity extends BaseEntity with _$MapApplyToTaskEntity {
  const factory MapApplyToTaskEntity({
    required String applicationId,
    required String status,
    required String taskId,
  }) = _MapApplyToTaskEntity;
}
