import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_application_dto.freezed.dart';
part 'map_task_application_dto.g.dart';

@freezed
class MapTaskApplicationDto extends BaseDto with _$MapTaskApplicationDto {
  const MapTaskApplicationDto._();

  const factory MapTaskApplicationDto({
    @JsonKey(name: 'id', defaultValue: '') required String id,
    @JsonKey(name: 'task_id', defaultValue: '') required String taskId,
    @JsonKey(name: 'applicant_id', defaultValue: '') required String applicantId,
    @JsonKey(name: 'status', defaultValue: '') required String status,
    @JsonKey(name: 'created_at', defaultValue: '') required String createdAt,
  }) = _MapTaskApplicationDto;

  factory MapTaskApplicationDto.fromJson(Map<String, dynamic> json) =>
      _$MapTaskApplicationDtoFromJson(json);

  MapTaskApplicationEntity toEntity() {
    return MapTaskApplicationEntity(
      id: id,
      taskId: taskId,
      applicantId: applicantId,
      status: status,
      createdAt: createdAt,
    );
  }
}
