import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_apply_to_task_response_dto.freezed.dart';
part 'map_apply_to_task_response_dto.g.dart';

@freezed
class MapApplyToTaskResponseDto extends BaseDto
    with _$MapApplyToTaskResponseDto {
  const MapApplyToTaskResponseDto._();

  const factory MapApplyToTaskResponseDto({
    @JsonKey(name: 'application_id', defaultValue: '')
    required String applicationId,
    @JsonKey(name: 'status', defaultValue: '') required String status,
    @JsonKey(name: 'task_id', defaultValue: '') required String taskId,
  }) = _MapApplyToTaskResponseDto;

  factory MapApplyToTaskResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapApplyToTaskResponseDtoFromJson(json);

  MapApplyToTaskEntity toEntity() {
    return MapApplyToTaskEntity(
      applicationId: applicationId,
      status: status,
      taskId: taskId,
    );
  }
}
