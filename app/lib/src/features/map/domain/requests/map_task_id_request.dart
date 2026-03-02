import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_id_request.freezed.dart';
part 'map_task_id_request.g.dart';

@freezed
class MapTaskIdRequest with _$MapTaskIdRequest implements BaseRequest {
  const factory MapTaskIdRequest({
    required String taskId,
  }) = _MapTaskIdRequest;

  factory MapTaskIdRequest.fromJson(Map<String, dynamic> json) =>
      _$MapTaskIdRequestFromJson(json);
}
