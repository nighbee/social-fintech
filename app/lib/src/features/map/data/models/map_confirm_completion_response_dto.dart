import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_confirm_completion_response_dto.freezed.dart';
part 'map_confirm_completion_response_dto.g.dart';

@freezed
class MapConfirmCompletionResponseDto extends BaseDto
    with _$MapConfirmCompletionResponseDto {
  const MapConfirmCompletionResponseDto._();

  const factory MapConfirmCompletionResponseDto({
    @JsonKey(name: 'task_id', defaultValue: '') required String taskId,
    @JsonKey(name: 'application_id', defaultValue: '')
    required String applicationId,
    @JsonKey(name: 'reward', defaultValue: 0) required double reward,
    @JsonKey(name: 'task_status', defaultValue: '') required String taskStatus,
  }) = _MapConfirmCompletionResponseDto;

  factory MapConfirmCompletionResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapConfirmCompletionResponseDtoFromJson(json);

  MapConfirmCompletionEntity toEntity() {
    return MapConfirmCompletionEntity(
      taskId: taskId,
      applicationId: applicationId,
      reward: reward,
      taskStatus: taskStatus,
    );
  }
}
