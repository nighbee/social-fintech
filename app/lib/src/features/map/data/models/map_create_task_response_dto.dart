import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_create_task_response_dto.freezed.dart';
part 'map_create_task_response_dto.g.dart';

@freezed
class MapCreateTaskResponseDto extends BaseDto with _$MapCreateTaskResponseDto {
  const factory MapCreateTaskResponseDto({
    @JsonKey(name: 'id', defaultValue: '') required String id,
    @JsonKey(name: 'title', defaultValue: '') required String title,
    @JsonKey(name: 'description') String? description,
    @JsonKey(name: 'reward', defaultValue: 0) required double reward,
    @JsonKey(name: 'workers_needed', defaultValue: 0) required int workersNeeded,
    @JsonKey(name: 'workers_filled', defaultValue: 0) required int workersFilled,
    @JsonKey(name: 'status', defaultValue: '') required String status,
    @JsonKey(name: 'auto_shutdown_at') String? autoShutdownAt,
    @JsonKey(name: 'latitude', defaultValue: 0) required double latitude,
    @JsonKey(name: 'longitude', defaultValue: 0) required double longitude,
    @JsonKey(name: 'created_at', defaultValue: '') required String createdAt,
    @JsonKey(name: 'verification_code', defaultValue: '')
    required String verificationCode,
  }) = _MapCreateTaskResponseDto;

  factory MapCreateTaskResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapCreateTaskResponseDtoFromJson(json);
}
