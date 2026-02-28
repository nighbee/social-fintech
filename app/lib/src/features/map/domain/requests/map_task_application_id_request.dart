import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_application_id_request.freezed.dart';
part 'map_task_application_id_request.g.dart';

@freezed
class MapTaskApplicationIdRequest
    with _$MapTaskApplicationIdRequest
    implements BaseRequest {
  const factory MapTaskApplicationIdRequest({
    required String taskId,
    required String applicationId,
  }) = _MapTaskApplicationIdRequest;

  factory MapTaskApplicationIdRequest.fromJson(Map<String, dynamic> json) =>
      _$MapTaskApplicationIdRequestFromJson(json);
}
