import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_create_task_request_dto.freezed.dart';
part 'map_create_task_request_dto.g.dart';

@freezed
class MapCreateTaskRequestDto with _$MapCreateTaskRequestDto implements BaseRequest {
  const factory MapCreateTaskRequestDto({
    required String title,
    required String description,
    required int heroesCount,
    required int reward,
    @JsonKey(name: 'auto_shutdown') required bool autoShutdown,
  }) = _MapCreateTaskRequestDto;

  factory MapCreateTaskRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MapCreateTaskRequestDtoFromJson(json);
}
