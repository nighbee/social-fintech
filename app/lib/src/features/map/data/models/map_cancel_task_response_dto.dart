import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_cancel_task_response_dto.freezed.dart';
part 'map_cancel_task_response_dto.g.dart';

@freezed
class MapCancelTaskResponseDto extends BaseDto with _$MapCancelTaskResponseDto {
  const factory MapCancelTaskResponseDto({
    @JsonKey(name: 'task_id', defaultValue: '') required String taskId,
    @JsonKey(name: 'status', defaultValue: '') required String status,
  }) = _MapCancelTaskResponseDto;

  factory MapCancelTaskResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapCancelTaskResponseDtoFromJson(json);
}
