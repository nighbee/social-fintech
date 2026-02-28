import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_application_entity.freezed.dart';

@freezed
class MapTaskApplicationEntity extends BaseEntity
    with _$MapTaskApplicationEntity {
  const factory MapTaskApplicationEntity({
    required String id,
    required String taskId,
    required String applicantId,
    required String status,
    required String createdAt,
  }) = _MapTaskApplicationEntity;
}
