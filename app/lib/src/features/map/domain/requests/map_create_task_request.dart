import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_create_task_request.freezed.dart';
part 'map_create_task_request.g.dart';

@freezed
class MapCreateTaskRequest with _$MapCreateTaskRequest implements BaseRequest {
  const factory MapCreateTaskRequest({
    required String title,
    required String description,
    required int heroesCount,
    required int reward,
    @JsonKey(name: 'auto_shutdown') required bool autoShutdown,
  }) = _MapCreateTaskRequest;

  factory MapCreateTaskRequest.fromJson(Map<String, dynamic> json) =>
      _$MapCreateTaskRequestFromJson(json);
}
